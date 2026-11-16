/// 课程表应用服务 + Riverpod 状态。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/list_state.dart';
import '../../../core/value_objects.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/timetable.dart';
import '../infrastructure/local_timetable_repository.dart';

final timetableRepositoryProvider = Provider<TimetableRepository>(
  (Ref ref) => LocalTimetableRepository(
    store: JsonEntityStore<Timetable>(
      store: ref.watch(keyValueStoreProvider),
      key: 'planstar.timetables.v1',
      bus: ref.watch(domainEventBusProvider),
      clock: ref.watch(clockProvider),
      fromJson: Timetable.fromJson,
      toJson: (Timetable t) => t.toJson(),
      idOf: (Timetable t) => t.id,
    ),
  ),
);

final timetableControllerProvider =
    NotifierProvider<TimetableController, AsyncListState<Timetable>>(
  TimetableController.new,
);

final class TimetableController
    extends Notifier<AsyncListState<Timetable>> {
  @override
  AsyncListState<Timetable> build() {
    Future.microtask(load);
    return AsyncListState<Timetable>();
  }

  TimetableRepository get _repository =>
      ref.read(timetableRepositoryProvider);

  Future<void> load() async {
    final result = await _repository.all();
    switch (result) {
      case Success<List<Timetable>>(:final List<Timetable> data):
        state = state.copyWith(
          items: data,
          loading: false,
          clearError: true,
        );
      case Fail<List<Timetable>>(:final failure):
        state = state.copyWith(loading: false, error: failure.message);
    }
  }

  Future<void> create({
    required String name,
    required DateKey startDate,
    int weeks = 20,
    int periodsPerDay = 8,
  }) async {
    final timetable = Timetable.create(
      id: ref.read(idGeneratorProvider).next(),
      name: name,
      startDate: startDate,
      weeks: weeks,
      periodsPerDay: periodsPerDay,
    );
    await _repository.save(timetable);
    await load();
  }

  Future<void> save(Timetable timetable) async {
    await _repository.save(timetable);
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    await load();
  }

  Future<void> addLesson(
    String timetableId,
    Lesson lesson, {
    bool allowConflict = false,
  }) async {
    final found = state.items
        .where((Timetable t) => t.id == timetableId)
        .toList();
    if (found.isEmpty) return;
    final timetable = found.first;
    if (!allowConflict && timetable.conflictsOf(lesson).isNotEmpty) {
      state = state.copyWith(error: '新增课程与其他课程有时间冲突');
      return;
    }
    await save(
      timetable.copyWith(
        lessons: <Lesson>[...timetable.lessons, lesson],
      ),
    );
  }

  Future<void> removeLesson(String timetableId, String lessonId) async {
    final found = state.items
        .where((Timetable t) => t.id == timetableId)
        .toList();
    if (found.isEmpty) return;
    await save(
      found.first.copyWith(
        lessons: found.first.lessons
            .where((Lesson l) => l.id != lessonId)
            .toList(),
      ),
    );
  }

  /// 供月历读模型使用：合并所有课程表在某一天的课程。
  List<Lesson> lessonsOn(DateKey date) => state.items
      .expand((Timetable t) => t.lessonsOn(date))
      .toList(growable: false);
}
