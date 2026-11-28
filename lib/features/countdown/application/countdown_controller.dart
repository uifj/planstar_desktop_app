/// 倒数日应用服务 + Riverpod 状态。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/list_state.dart';
import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/countdown.dart';
import '../infrastructure/local_countdown_repository.dart';

final countdownRepositoryProvider = Provider<CountdownRepository>(
  (Ref ref) => LocalCountdownRepository(
    store: JsonEntityStore<CountdownItem>(
      store: ref.watch(keyValueStoreProvider),
      key: 'planstar.countdowns.v1',
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
    final scope = ref.read(appLocalizationScopeProvider);
    scope.addListener(_onLocaleChanged);
    ref.onDispose(() => scope.removeListener(_onLocaleChanged));
    Future.microtask(load);
    return AsyncListState<CountdownItem>();
  }

  void _onLocaleChanged() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  CountdownRepository get _repository => ref.read(countdownRepositoryProvider);

  AppLocalizations get _l10n =>
      ref.read(appLocalizationScopeProvider).localizations;

  Future<void> load() async {
    final result = await _repository.all();
    switch (result) {
      case Success<List<CountdownItem>>(:final List<CountdownItem> data):
        state = state.copyWith(items: data, loading: false, clearError: true);
      case Fail<List<CountdownItem>>(:final failure):
        state = state.copyWith(
          loading: false,
          error: _l10n.countdownLoadFailed(failureLabel(failure, _l10n)),
        );
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

  Future<void> openDesktopCard() => ref
      .read(multiWindowGatewayProvider)
      .openCountdownWindow()
      .then<void>((_) {});
}
