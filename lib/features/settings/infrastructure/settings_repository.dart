/// 设置仓储：把 `AppSettings` 存进 `core` 的 `KeyValueStore` 端口。
library;

import 'dart:async';

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';

import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../domain/app_settings.dart';

abstract interface class SettingsRepository {
  Future<Result<AppSettings>> load();

  Future<Result<void>> save(AppSettings settings);
}

/// 设置键的重载分组注册。
void registerSettingsReloadTargets(ReloadTargetRegistry registry) =>
    registry.registerKey(LocalSettingsRepository.key, 'settings');

final class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository({
    required this._store,
    required this._bus,
    required this._clock,
  });

  static const String key = 'planstar.settings.v1';

  final KeyValueStore _store;
  final DomainEventBus _bus;
  final Clock _clock;

  @override
  Future<Result<AppSettings>> load() async {
    final result = await guardAsync<Map<String, Object?>?>(
      () => _store.readJson(key),
    );
    return result.map((Map<String, Object?>? json) {
      if (json == null) return AppSettings.defaults;
      // 旧版把月历画成静态壁纸；新版改为桌面可编辑组件。旧配置里没有
      // desktopWidgetEnabled，据此做一次性迁移，避免旧值把壁纸重新打开。
      if (json.containsKey('desktopWidgetEnabled')) {
        return AppSettings.fromJson(json);
      }
      final migrated = AppSettings.fromJson(json)
          .copyWith(wallpaperAutoRender: false, desktopWidgetEnabled: true);
      unawaited(save(migrated));
      return migrated;
    });
  }

  @override
  Future<Result<void>> save(AppSettings settings) async {
    final written = await guardAsync<void>(
      () => _store.writeJson(key, settings.toJson()),
    );
    return written.flatMapAsync((_) async {
      await _bus.dispatch(<DomainEvent>[
        SettingsChanged(aggregateId: key, occurredAt: _clock.now()),
      ]);
      return const Success<void>(null);
    });
  }
}
