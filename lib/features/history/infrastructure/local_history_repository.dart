/// 历史仓储本地实现。
library;

import 'package:core/result.dart';

import '../../../infrastructure/json_entity_store.dart';
import '../domain/history_entry.dart';

final class LocalHistoryRepository implements HistoryRepository {
  const LocalHistoryRepository({required this._store});

  final JsonEntityStore<HistoryEntry> _store;

  @override
  Future<Result<List<HistoryEntry>>> all() => _store.all();

  @override
  Future<Result<void>> append(HistoryEntry entry) =>
      _store.upsert(entry, events: entry.pullDomainEvents().toList());

  @override
  Future<Result<void>> delete(String id) => _store.delete(id);

  @override
  Future<Result<void>> clear() => _store.deleteAll();
}
