/// 历史记录控制器：订阅领域事件自动留痕，并支持「恢复」到目标聚合。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/app_events.dart';
import '../../../core/list_state.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../../features/calendar/application/calendar_controller.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/history_entry.dart';
import '../infrastructure/local_history_repository.dart';

/// 历史记录的持久化键。
const String historyStoreKey = 'planstar.history.v1';

/// 历史记录键的重载分组注册。
void registerHistoryReloadTargets(ReloadTargetRegistry registry) =>
    registry.registerKey(historyStoreKey, 'history');

final historyRepositoryProvider = Provider<HistoryRepository>(
  (Ref ref) => LocalHistoryRepository(
    store: JsonEntityStore<HistoryEntry>(
      store: ref.watch(keyValueStoreProvider),
      key: historyStoreKey,
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
}) {
  if (removed) {
    return title.isEmpty ? '删除便签' : '删除便签：$title';
  }
  if (title.isEmpty) return summary;
  if (summary.isEmpty || summary == title) return title;
  return '$title：$summary';
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
    Future.microtask(load);
    final bus = ref.read(domainEventBusProvider);
    bus.on<DayCellChanged>(_onCellChanged);
    bus.on<NoteChanged>(_onNoteChanged);
    bus.on<NoteRemoved>(_onNoteChanged);
    return AsyncListState<HistoryEntry>();
  }

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

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
      content = noteHistoryContent(title: event.title, summary: event.summary);
    } else if (event is NoteRemoved) {
      content = noteHistoryContent(
        title: event.title,
        summary: '',
        removed: true,
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
      author: '本机',
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
        state = state.copyWith(loading: false, error: failure.message);
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
        state = state.copyWith(loading: false, error: failure.message);
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
        state = state.copyWith(error: failure.message);
    }
  }

  Future<void> clear() async {
    final result = await _repository.clear();
    switch (result) {
      case Success<void>():
        state = state.copyWith(items: const <HistoryEntry>[], clearError: true);
      case Fail<void>(:final failure):
        state = state.copyWith(error: failure.message);
    }
  }

  /// 当前单元格是否比这条快照更新（用于恢复前警告，避免覆盖较新内容）。
  bool hasNewerContent(HistoryEntry entry) {
    if (entry.kind != HistoryKind.cell) return false;
    final date = DateKey.parse(entry.targetId);
    final cell = ref.read(calendarControllerProvider).cells[date];
    return cell != null && cell.updatedAt.isAfter(entry.occurredAt);
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
