/// 订阅仓储：本地持久化 + `core/network.dart` 的 `ApiClient` 远端拉取。
library;

import 'package:core/logger.dart';
import 'package:core/network.dart';
import 'package:core/result.dart';

import '../../../infrastructure/json_entity_store.dart';
import '../domain/subscription.dart';

final class LocalSubscriptionRepository implements SubscriptionRepository {
  const LocalSubscriptionRepository({
    required this._store,
    required this._api,
    required this._logger,
    required this._endpoint,
  });

  final JsonEntityStore<Subscription> _store;
  final ApiClient _api;
  final AppLogger _logger;
  final String _endpoint;

  @override
  Future<Result<List<Subscription>>> all() => _store.all();

  @override
  Future<Result<void>> save(Subscription subscription) => _store.upsert(
    subscription,
    events: subscription.pullDomainEvents().toList(),
  );

  @override
  Future<Result<void>> delete(String id) => _store.delete(id);

  @override
  Future<Result<List<SubscriptionEvent>>> fetchRemote(
    Subscription subscription,
  ) async {
    final result = await _api.get<List<SubscriptionEvent>>(
      _endpoint,
      queryParameters: <String, Object?>{
        'source': subscription.source.name,
        'link': subscription.shareLink,
      },
      parser: (Object? data) {
        if (data is! List) return <SubscriptionEvent>[];
        return data
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> e) => SubscriptionEvent.fromJson(
                e.map(
                  (Object? k, Object? v) => MapEntry<String, Object?>('$k', v),
                ),
              ),
            )
            .toList();
      },
    );
    if (result case Fail<List<SubscriptionEvent>>(:final Failure failure)) {
      _logger.warn(
        '订阅拉取失败，保留本地缓存：${subscription.name}',
        error: failure.message,
      );
    }
    return result;
  }
}
