/// 课程表仓储本地实现。
library;

import 'package:core/result.dart';

import '../../../infrastructure/json_entity_store.dart';
import '../domain/timetable.dart';

final class LocalTimetableRepository implements TimetableRepository {
  const LocalTimetableRepository({required this._store});

  final JsonEntityStore<Timetable> _store;

  @override
  Future<Result<List<Timetable>>> all() => _store.all();

  @override
  Future<Result<void>> save(Timetable timetable) =>
      _store.upsert(timetable, events: timetable.pullDomainEvents().toList());

  @override
  Future<Result<void>> delete(String id) => _store.delete(id);
}
