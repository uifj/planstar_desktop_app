/// 设置状态（Riverpod Notifier）：单一真相源，所有页面只读它。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../domain/app_settings.dart';
import '../infrastructure/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (Ref ref) => LocalSettingsRepository(
    store: ref.watch(keyValueStoreProvider),
    bus: ref.watch(domainEventBusProvider),
    clock: ref.watch(clockProvider),
  ),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final class SettingsController extends Notifier<AppSettings> {
  int _revision = 0;
  Future<void>? _initialLoad;

  @override
  AppSettings build() {
    _initialLoad = Future.microtask(load);
    return AppSettings.defaults;
  }

  Future<void> load() async {
    final revision = ++_revision;
    final result = await ref.read(settingsRepositoryProvider).load();
    if (revision != _revision) return;
    if (result case Success<AppSettings>(:final AppSettings data)) {
      state = data;
      ref.read(appLocalizationScopeProvider).setLanguage(data.language);
    }
  }

  /// 原子更新：先改内存状态，再异步落盘并返回写入结果。
  Future<Result<void>> update(
    AppSettings Function(AppSettings current) transform,
  ) async {
    final initialLoad = _initialLoad;
    if (initialLoad != null) await initialLoad;
    final next = transform(state);
    if (next == state) return const Success<void>(null);
    _revision++;
    state = next;
    ref.read(appLocalizationScopeProvider).setLanguage(next.language);
    return ref.read(settingsRepositoryProvider).save(next);
  }

  Future<Result<void>> restoreDefaults() => update((_) => AppSettings.defaults);

  /// 与 `window_manager` / 开机自启联动的副作用由 DesktopController 监听。
  Future<Result<void>> setStartWithWindow(bool enabled) =>
      update((AppSettings s) => s.copyWith(startWithWindow: enabled));
}
