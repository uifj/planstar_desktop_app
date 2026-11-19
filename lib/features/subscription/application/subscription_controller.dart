/// 订阅应用服务 + Riverpod 状态。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/list_state.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/subscription.dart';
import '../infrastructure/local_subscription_repository.dart';

/// 订阅的持久化键。
const String subscriptionsStoreKey = 'planstar.subscriptions.v1';

/// 订阅键的重载分组注册。
void registerSubscriptionReloadTargets(ReloadTargetRegistry registry) =>
    registry.registerKey(subscriptionsStoreKey, 'subscription');

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (Ref ref) => LocalSubscriptionRepository(
    store: JsonEntityStore<Subscription>(
      store: ref.watch(keyValueStoreProvider),
      key: subscriptionsStoreKey,
      bus: ref.watch(domainEventBusProvider),
      clock: ref.watch(clockProvider),
      fromJson: Subscription.fromJson,
      toJson: (Subscription s) => s.toJson(),
      idOf: (Subscription s) => s.id,
    ),
    api: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
    endpoint:
        ref
            .watch(appConfigProvider)
            .section('cloud')
            .getString('subscriptionEndpoint') ??
        'subscriptions/',
  ),
);

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, AsyncListState<Subscription>>(
      SubscriptionController.new,
    );

final class SubscriptionController
    extends Notifier<AsyncListState<Subscription>> {
  @override
  AsyncListState<Subscription> build() {
    Future.microtask(load);
    return AsyncListState<Subscription>();
  }

  SubscriptionRepository get _repository =>
      ref.read(subscriptionRepositoryProvider);

  Future<void> load() async {
    final result = await _repository.all();
    switch (result) {
      case Success<List<Subscription>>(:final List<Subscription> data):
        state = state.copyWith(items: data, loading: false, clearError: true);
      case Fail<List<Subscription>>(:final failure):
        state = state.copyWith(loading: false, error: failure.message);
    }
  }

  Future<void> create({
    required String name,
    required String shareLink,
    SubscriptionSource source = SubscriptionSource.local,
  }) async {
    final subscription = Subscription.create(
      id: ref.read(idGeneratorProvider).next(),
      name: name,
      shareLink: shareLink.isEmpty
          ? 'planstar://subscribe/${ref.read(idGeneratorProvider).next()}'
          : shareLink,
      source: source,
    );
    await _repository.save(subscription);
    await load();
  }

  /// 手动同步一个订阅；失败时保留已有事件并给出可读错误。
  Future<void> refresh(String id, {bool all = false}) async {
    final targets = state.items
        .where((Subscription s) => all || s.id == id)
        .toList();
    for (final subscription in targets) {
      final result = await _repository.fetchRemote(subscription);
      switch (result) {
        case Success<List<SubscriptionEvent>>(
          :final List<SubscriptionEvent> data,
        ):
          await _repository.save(
            subscription.withEvents(data, ref.read(clockProvider).now()),
          );
        case Fail<List<SubscriptionEvent>>(:final Failure failure):
          state = state.copyWith(error: failure.message);
      }
    }
    await load();
  }

  Future<void> toggle(String id) async {
    for (final subscription in state.items) {
      if (subscription.id != id) continue;
      await _repository.save(
        subscription.copyWith(enabled: !subscription.enabled),
      );
    }
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    await load();
  }

  /// 供月历读模型使用：所有启用订阅在某天的推送。
  List<SubscriptionEvent> eventsOn(DateKey date) => state.items
      .where((Subscription s) => s.enabled)
      .expand((Subscription s) => s.events)
      .where((SubscriptionEvent e) => e.date == date)
      .toList(growable: false);
}

/// 对月历读模型的贡献（ADR-0004）：只读自身状态，启用订阅的事件按日预计算。
final subscriptionContributionProvider = Provider<TimelineContribution>((
  Ref ref,
) {
  final items = ref.watch(subscriptionControllerProvider).items;
  final byDay = <DateTime, List<TimelineTag>>{};
  for (final subscription in items) {
    if (!subscription.enabled) continue;
    for (final item in subscription.events) {
      (byDay.putIfAbsent(
        item.date.date,
        () => <TimelineTag>[],
      )).add(TimelineTag(kind: TimelineTagKind.subscription, text: item.title));
    }
  }
  return TimelineContribution(
    tagsOn: (DateTime date) => byDay[date] ?? const <TimelineTag>[],
  );
});
