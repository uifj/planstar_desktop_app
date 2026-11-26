/// 历史记录控制器：订阅领域事件自动留痕，并支持「恢复」到目标聚合。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/app_events.dart';
import '../../../core/list_state.dart';
import '../../../core/value_objects.dart';
import '../../../features/calendar/application/calendar_controllers.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../../../l10n/l10n.dart';
import '../domain/history_entry.dart';
import '../infrastructure/local_history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (Ref ref) => LocalHistoryRepository(
    store: JsonEntityStore<HistoryEntry>(
      store: ref.watch(keyValueStoreProvider),
      key: 'planstar.history.v1',
      bus: ref.watch(domainEventBusProvider),
      clock: ref.watch(clockProvider),
      fromJson: HistoryEntry.fromJson,
      toJson: (HistoryEntry e) => e.toJson(),
      idOf: (HistoryEntry e) => e.id,
    ),
  ),
);

final historyControllerProvider =
    NotifierProvider<HistoryController, AsyncListState<HistoryEntry>>(
      HistoryController.new,
    );

/// 便签留痕的可读文案：用真实标题/摘要，而不是 `NoteChanged` 技术名。
String noteHistoryContent({
  required String title,
  required String summary,
  bool removed = false,
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? lookupAppLocalizations(const Locale('zh'));
  if (removed) {
    return title.isEmpty
        ? strings.historyNoteRemoved
        : strings.historyNoteRemovedWithTitle(title);
  }
  if (title.isEmpty) return summary;
  if (summary.isEmpty || summary == title) return title;
  return strings.historyNoteWithSummary(title, summary);
}

/// 恢复历史快照的结果，供 UI 给出准确反馈。
enum RevertOutcome {
  success,

  /// 当前单元格比这条历史更新，直接恢复会丢失较新内容。
  newerContent,
  invalidEntry,
  failed,
}

final class HistoryController extends Notifier<AsyncListState<HistoryEntry>> {
  @override
  AsyncListState<HistoryEntry> build() {
    // 仅由应用根 ref.read，需保活以持续记录领域事件留痕。
    ref.keepAlive();
    final scope = ref.read(appLocalizationScopeProvider);
    scope.addListener(_onLocaleChanged);
    ref.onDispose(() => scope.removeListener(_onLocaleChanged));
    Future.microtask(load);
    final bus = ref.read(domainEventBusProvider);
    bus.on<DayCellChanged>(_onCellChanged);
    bus.on<NoteChanged>(_onNoteChanged);
    bus.on<NoteRemoved>(_onNoteChanged);
    return AsyncListState<HistoryEntry>();
  }

  void _onLocaleChanged() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  AppLocalizations get _l10n =>
      ref.read(appLocalizationScopeProvider).localizations;

  Future<void> _onCellChanged(DomainEvent event) async {
    if (event is! DayCellChanged) return;
    await _append(
      targetId: event.aggregateId,
      kind: HistoryKind.cell,
      content: event.snapshot,
      occurredAt: event.occurredAt,
    );
  }

  Future<void> _onNoteChanged(DomainEvent event) async {
    if (event is! AppDomainEvent) return;
    // 便签事件携带真实标题/摘要，不再把 "NoteChanged" 这类技术名写进历史。
    final String content;
    if (event is NoteChanged) {
      content = noteHistoryContent(
        title: event.title,
        summary: event.summary,
        l10n: _l10n,
      );
    } else if (event is NoteRemoved) {
      content = noteHistoryContent(
        title: event.title,
        summary: '',
        removed: true,
        l10n: _l10n,
      );
    } else {
      content = event.eventName;
    }
    await _append(
      targetId: event.aggregateId,
      kind: HistoryKind.note,
      content: content,
      occurredAt: event.occurredAt,
    );
  }

  Future<void> _append({
    required String targetId,
    required HistoryKind kind,
    required String content,
    required DateTime occurredAt,
  }) async {
    final entry = HistoryEntry(
      id: ref.read(idGeneratorProvider).next(),
      targetId: targetId,
      kind: kind,
      content: content,
      author: _l10n.historyAuthorLocal,
      occurredAt: occurredAt,
    );
    final result = await _repository.append(entry);
    switch (result) {
      case Success<void>():
        // 就地有序插入，避免每条留痕都全量重读磁盘 + 重排整个列表。
        final next = <HistoryEntry>[entry, ...state.items]
          ..sort(
            (HistoryEntry a, HistoryEntry b) =>
                b.occurredAt.compareTo(a.occurredAt),
          );
        state = state.copyWith(items: next, loading: false, clearError: true);
      case Fail<void>(:final failure):
        state = state.copyWith(
          loading: false,
          error: failureLabel(failure, _l10n),
        );
    }
  }

  Future<void> load() async {
    final result = await _repository.all();
    switch (result) {
      case Success<List<HistoryEntry>>(:final List<HistoryEntry> data):
        final sorted = List<HistoryEntry>.of(data)
          ..sort(
            (HistoryEntry a, HistoryEntry b) =>
                b.occurredAt.compareTo(a.occurredAt),
          );
        state = state.copyWith(items: sorted, loading: false, clearError: true);
      case Fail<List<HistoryEntry>>(:final failure):
        state = state.copyWith(
          loading: false,
          error: failureLabel(failure, _l10n),
        );
    }
  }

  Future<void> remove(String id) async {
    final result = await _repository.delete(id);
    switch (result) {
      case Success<void>():
        state = state.copyWith(
          items: state.items.where((HistoryEntry e) => e.id != id).toList(),
          clearError: true,
        );
      case Fail<void>(:final failure):
        state = state.copyWith(error: failureLabel(failure, _l10n));
    }
  }

  Future<void> clear() async {
    final result = await _repository.clear();
    switch (result) {
      case Success<void>():
        state = state.copyWith(items: const <HistoryEntry>[], clearError: true);
      case Fail<void>(:final failure):
        state = state.copyWith(error: failureLabel(failure, _l10n));
    }
  }

  /// 当前单元格是否比这条快照更新（用于恢复前警告，避免覆盖较新内容）。
  bool hasNewerContent(HistoryEntry entry) {
    if (entry.kind != HistoryKind.cell) return false;
    final date = DateKey.parse(entry.targetId);
    for (final cell in ref.read(calendarControllerProvider).cells) {
      if (cell.date == date) return cell.updatedAt.isAfter(entry.occurredAt);
    }
    return false;
  }

  /// 把历史快照「恢复」回单元格（旧版 `IDS_DESKTOPCAL_HISTORY_BUTTON_REVERT`）。
  /// 带冲突校验：若当前内容更新则拒绝覆盖，UI 需先确认再决定是否强制恢复。
  Future<RevertOutcome> revertCell(
    HistoryEntry entry, {
    bool overwriteNewer = false,
  }) async {
    if (entry.kind != HistoryKind.cell) return RevertOutcome.invalidEntry;
    final date = DateKey.parse(entry.targetId);
    if (!overwriteNewer && hasNewerContent(entry)) {
      return RevertOutcome.newerContent;
    }
    try {
      await ref
          .read(calendarControllerProvider.notifier)
          .restoreCellFromText(date, entry.content);
      return RevertOutcome.success;
    } on Object {
      return RevertOutcome.failed;
    }
  }
}
