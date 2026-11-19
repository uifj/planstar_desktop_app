/// 倒数日应用服务 + Riverpod 状态。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/list_state.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/countdown.dart';
import '../infrastructure/local_countdown_repository.dart';

/// 倒数日的持久化键。
const String countdownsStoreKey = 'planstar.countdowns.v1';

/// 倒数日键的重载分组注册。
void registerCountdownReloadTargets(ReloadTargetRegistry registry) =>
    registry.registerKey(countdownsStoreKey, 'countdown');

final countdownRepositoryProvider = Provider<CountdownRepository>(
  (Ref ref) => LocalCountdownRepository(
    store: JsonEntityStore<CountdownItem>(
      store: ref.watch(keyValueStoreProvider),
      key: countdownsStoreKey,
      bus: ref.watch(domainEventBusProvider),
      clock: ref.watch(clockProvider),
      fromJson: CountdownItem.fromJson,
      toJson: (CountdownItem i) => i.toJson(),
      idOf: (CountdownItem i) => i.id,
    ),
  ),
);

final countdownControllerProvider =
    NotifierProvider<CountdownController, AsyncListState<CountdownItem>>(
      CountdownController.new,
    );

final class CountdownController
    extends Notifier<AsyncListState<CountdownItem>> {
  @override
  AsyncListState<CountdownItem> build() {
    Future.microtask(load);
    return AsyncListState<CountdownItem>();
  }

  CountdownRepository get _repository => ref.read(countdownRepositoryProvider);

  Future<void> load() async {
    final result = await _repository.all();
    switch (result) {
      case Success<List<CountdownItem>>(:final List<CountdownItem> data):
        state = state.copyWith(items: data, loading: false, clearError: true);
      case Fail<List<CountdownItem>>(:final failure):
        state = state.copyWith(loading: false, error: failure.message);
    }
  }

  Future<void> create({
    required String title,
    required DateKey targetDate,
    CountdownType type = CountdownType.custom,
    CountdownShowType showType = CountdownShowType.both,
    EventColor color = EventColor.defaultText,
    int? birthYear,
    bool lunar = false,
  }) async {
    final item = CountdownItem.create(
      id: ref.read(idGeneratorProvider).next(),
      title: title,
      targetDate: targetDate,
      occurredAt: ref.read(clockProvider).now(),
      type: type,
      showType: showType,
      color: color,
      birthYear: birthYear,
      lunar: lunar,
    );
    await _repository.save(item);
    await load();
  }

  Future<void> save(CountdownItem item) async {
    await _repository.save(item);
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    await load();
  }

  List<CountdownItem> visibleOnCalendar(DateKey today) =>
      state.items.where((CountdownItem c) => c.showType.onCalendar).toList()
        ..sort(
          (CountdownItem a, CountdownItem b) =>
              a.daysLeft(today).abs().compareTo(b.daysLeft(today).abs()),
        );

  Future<void> openDesktopCard() => ref
      .read(multiWindowGatewayProvider)
      .openCountdownWindow()
      .then<void>((_) {});
}

/// 对月历读模型的贡献（ADR-0004）：按日条目 + 底部横条（排序在贡献侧完成）。
final countdownContributionProvider = Provider<TimelineContribution>((Ref ref) {
  final items = ref.watch(countdownControllerProvider).items;
  final today = DateKey.today(ref.watch(clockProvider).now());
  final bar = items.where((CountdownItem c) => c.showType.onCalendar).toList()
    ..sort(
      (CountdownItem a, CountdownItem b) =>
          a.daysLeft(today).abs().compareTo(b.daysLeft(today).abs()),
    );
  return TimelineContribution(
    tagsOn: (DateTime date) => <TimelineTag>[
      for (final item in items)
        if (item.nextOccurrence(today) == DateKey(date))
          TimelineTag(kind: TimelineTagKind.countdown, text: item.title),
    ],
    bar: <TimelineBarEntry>[
      for (final item in bar)
        TimelineBarEntry(
          title: item.title,
          colorArgb: item.color.argb,
          displayText: item.displayText(today),
        ),
    ],
  );
});
