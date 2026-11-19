/// 通用 JSON 列表仓储骨架。
///
/// 所有本地聚合（便签 / 倒数日 / 课程表 / 订阅 / 历史）共用同一套
/// 「读全部 → 覆盖写 → 持久化成功后分发领域事件」流程，避免每个仓储
/// 各写一遍而产生不一致的失败语义。
library;

import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';

import '../core/ports.dart';

typedef JsonMap = Map<String, Object?>;

final class JsonEntityStore<T extends Object> {
  JsonEntityStore({
    required KeyValueStore store,
    required String key,
    required this._bus,
    required this._clock,
    required this._fromJson,
    required this._toJson,
    required this._idOf,
    this._idField = 'id',
    this._logger,
  }) : _items = JsonListStore<JsonMap>(
         store: store,
         key: key,
         fromJson: (JsonMap json) => json,
         toJson: (JsonMap value) => value,
       );

  final DomainEventBus _bus;
  final Clock _clock;
  final T Function(JsonMap) _fromJson;
  final JsonMap Function(T) _toJson;
  final String Function(T) _idOf;
  final String _idField;
  final AppLogger? _logger;
  final JsonListStore<JsonMap> _items;

  Clock get clock => _clock;

  Future<Result<List<T>>> all() async {
    final result = await guardAsync<List<JsonMap>>(() => _items.readAll());
    return result.map((List<JsonMap> items) => items.map(_fromJson).toList());
  }

  Future<Result<void>> upsert(T item, {List<DomainEvent>? events}) async {
    final current = await guardAsync<List<JsonMap>>(() => _items.readAll());
    return current.flatMapAsync((List<JsonMap> items) {
      final id = _idOf(item);
      final next = List<JsonMap>.of(items)
        ..removeWhere(
          (JsonMap json) => json[_idField] == id || json['key'] == id,
        )
        ..add(_toJson(item));
      return _persist(() => _items.writeAll(next), events);
    });
  }

  Future<Result<void>> upsertAll(
    List<T> items, {
    List<DomainEvent>? events,
  }) async {
    final current = await guardAsync<List<JsonMap>>(() => _items.readAll());
    return current.flatMapAsync((List<JsonMap> existing) {
      final ids = items.map(_idOf).toSet();
      final next = List<JsonMap>.of(existing)
        ..removeWhere((JsonMap json) => ids.contains(json[_idField]))
        ..addAll(items.map(_toJson));
      return _persist(() => _items.writeAll(next), events);
    });
  }

  Future<Result<void>> delete(String id, {List<DomainEvent>? events}) async {
    final current = await guardAsync<List<JsonMap>>(() => _items.readAll());
    return current.flatMapAsync((List<JsonMap> items) {
      final next = List<JsonMap>.of(items)
        ..removeWhere(
          (JsonMap json) => json[_idField] == id || json['key'] == id,
        );
      return _persist(() => _items.writeAll(next), events);
    });
  }

  Future<Result<void>> deleteAll() async {
    final result = await guardAsync<void>(() => _items.clear());
    return result;
  }

  Future<Result<void>> _persist(
    Future<void> Function() write,
    List<DomainEvent>? events,
  ) async {
    final written = await guardAsync<void>(write);
    return switch (written) {
      Fail<void>(:final Failure failure) => Fail<void>(failure),
      Success<void>() => await _dispatch(events ?? const <DomainEvent>[]),
    };
  }

  Future<Result<void>> _dispatch(List<DomainEvent> events) async {
    await _bus.dispatch(events);
    if (events.isNotEmpty) {
      _logger?.debug('领域事件已分发：${events.length} 条');
    }
    return const Success<void>(null);
  }
}
