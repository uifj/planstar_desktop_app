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
    NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

final class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    Future.microtask(load);
    return AppSettings.defaults;
  }

  Future<void> load() async {
    final result = await ref.read(settingsRepositoryProvider).load();
    if (result case Success<AppSettings>(:final AppSettings data)) {
      state = data;
    }
  }

  /// 原子更新：先改内存状态，再异步落盘（设置项失败不回滚 UI）。
  Future<void> update(AppSettings Function(AppSettings current) transform) {
    final next = transform(state);
    if (next == state) return Future<void>.value();
    state = next;
    return ref.read(settingsRepositoryProvider).save(next);
  }

  Future<void> restoreDefaults() => update((_) => AppSettings.defaults);

  /// 与 `window_manager` / 开机自启联动的副作用由 DesktopController 监听。
  Future<void> setStartWithWindow(bool enabled) =>
      update((AppSettings s) => s.copyWith(startWithWindow: enabled));
}
