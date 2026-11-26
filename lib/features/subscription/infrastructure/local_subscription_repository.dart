/// 订阅仓储：本地持久化 + `core/network.dart` 的 `ApiClient` 远端拉取。
library;

import 'package:core/logger.dart';
import 'package:core/network.dart';
import 'package:core/result.dart';

import '../../../infrastructure/json_entity_store.dart';
import '../domain/subscription.dart';

final class LocalSubscriptionRepository implements SubscriptionRepository {
  const LocalSubscriptionRepository({
    required JsonEntityStore<Subscription> store,
    required ApiClient api,
    required AppLogger logger,
    required String endpoint,
    this.fetchFailureMessage,
  }) : _store = store,
       _api = api,
       _logger = logger,
       _endpoint = endpoint;

  final JsonEntityStore<Subscription> _store;
  final ApiClient _api;
  final AppLogger _logger;
  final String _endpoint;
  final String Function(String name)? fetchFailureMessage;

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
        fetchFailureMessage?.call(subscription.name) ?? '订阅刷新失败',
        error: failure.cause ?? failure,
        fields: <String, Object?>{
          'code': failure.code,
          'type': failure.type.name,
          'statusCode': failure.statusCode,
          'requestId': failure.requestId,
        },
      );
    }
    return result;
  }
}
