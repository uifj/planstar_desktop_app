/// 历史记录控制器：订阅领域事件自动留痕，并支持「恢复」到目标聚合。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/app_events.dart';
import '../../../core/list_state.dart';
import '../../../core/value_objects.dart';
import '../../../features/calendar/application/calendar_controllers.dart';
import '../../../infrastructure/json_entity_store.dart';
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

final class HistoryController
    extends Notifier<AsyncListState<HistoryEntry>> {
  @override
  AsyncListState<HistoryEntry> build() {
    Future.microtask(load);
    final bus = ref.read(domainEventBusProvider);
    bus.on<DayCellChanged>(_onCellChanged);
    bus.on<NoteChanged>(_onNoteChanged);
    bus.on<NoteRemoved>(_onNoteChanged);
    return AsyncListState<HistoryEntry>();
  }

  HistoryRepository get _repository =>
      ref.read(historyRepositoryProvider);

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
    await _append(
      targetId: event.aggregateId,
      kind: HistoryKind.note,
      content: event.eventName,
      occurredAt: event.occurredAt,
    );
  }

  Future<void> _append({
    required String targetId,
    required HistoryKind kind,
    required String content,
    required DateTime occurredAt,
  }) async {
    await _repository.append(
      HistoryEntry(
        id: ref.read(idGeneratorProvider).next(),
        targetId: targetId,
        kind: kind,
        content: content,
        author: '本机',
        occurredAt: occurredAt,
      ),
    );
    await load();
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
        state = state.copyWith(
          items: sorted,
          loading: false,
          clearError: true,
        );
      case Fail<List<HistoryEntry>>(:final failure):
        state = state.copyWith(loading: false, error: failure.message);
    }
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    await load();
  }

  Future<void> clear() async {
    await _repository.clear();
    await load();
  }

  /// 把历史快照「恢复」回单元格（旧版 `IDS_DESKTOPCAL_HISTORY_BUTTON_REVERT`）。
  Future<void> revertCell(HistoryEntry entry) async {
    if (entry.kind != HistoryKind.cell) return;
    final date = DateKey.parse(entry.targetId);
    await ref
        .read(calendarControllerProvider.notifier)
        .restoreCellFromText(date, entry.content);
  }
}
