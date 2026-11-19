/// 倒数日仓储本地实现。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';

import '../../../core/app_events.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/countdown.dart';

final class LocalCountdownRepository implements CountdownRepository {
  LocalCountdownRepository({required this._store});

  final JsonEntityStore<CountdownItem> _store;

  @override
  Future<Result<List<CountdownItem>>> all() => _store.all();

  @override
  Future<Result<void>> save(CountdownItem item) =>
      _store.upsert(item, events: item.pullDomainEvents().toList());

  @override
  Future<Result<void>> delete(String id) => _store.delete(
    id,
    events: <DomainEvent>[
      CountdownRemoved(aggregateId: id, occurredAt: _store.clock.now()),
    ],
  );

  @override
  Future<Result<void>> clear() => _store.deleteAll();
}
