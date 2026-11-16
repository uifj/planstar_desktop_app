/// 应用根：主题完全来自 `core_design_system`，路由来自 go_router。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/desktop/application/desktop_controller.dart';
import '../features/history/application/history_controller.dart';
import '../features/reminder/application/reminder_controller.dart';
import '../features/reminder/presentation/reminder_overlay.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/sync/application/cross_engine_sync_controller.dart';
import '../features/sync/application/sync_controller.dart';
import 'router.dart';

final class PlanstarApp extends ConsumerStatefulWidget {
  const PlanstarApp({super.key});

  @override
  ConsumerState<PlanstarApp> createState() => _PlanstarAppState();
}

final class _PlanstarAppState extends ConsumerState<PlanstarApp> {
  @override
  void initState() {
    super.initState();
    // 触发组合根里的桌面 / 提醒 / 历史控制器，让它们完成初始化与事件订阅。
    Future.microtask(() {
      ref.read(desktopControllerProvider);
      ref.read(reminderControllerProvider);
      ref.read(historyControllerProvider);
      ref.read(syncControllerProvider);
      ref.read(crossEngineSyncControllerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsControllerProvider).themeMode;
    return MaterialApp.router(
      title: '企划星 · 桌面日历清单',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _toMaterialThemeMode(mode),
      routerConfig: ref.watch(routerProvider),
      builder: (BuildContext context, Widget? child) => Stack(
        children: <Widget>[
          ?child,
          const ReminderOverlay(),
        ],
      ),
    );
  }

  ThemeMode _toMaterialThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };
}
