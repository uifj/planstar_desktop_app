/// 主窗口壳：自定义标题栏 + 左侧导航 + 快捷键 + 页面容器。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/application/calendar_controllers.dart';
import '../../features/desktop/application/desktop_controller.dart';
import '../../features/sync/application/sync_controller.dart';
import 'window_title_bar.dart';

final class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination('/calendar', '日历', Icons.calendar_month_outlined),
    _Destination('/notes', '便签', Icons.sticky_note_2_outlined),
    _Destination('/countdown', '倒数日', Icons.hourglass_top_outlined),
    _Destination('/timetable', '课程表', Icons.table_chart_outlined),
    _Destination('/subscription', '订阅', Icons.rss_feed_outlined),
    _Destination('/search', '搜索', Icons.search_outlined),
    _Destination('/history', '历史', Icons.history_outlined),
    _Destination('/transfer', '导入导出', Icons.import_export_outlined),
    _Destination('/account', '账号同步', Icons.cloud_sync_outlined),
    _Destination('/settings', '设置', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final desktopMessage = ref.watch(desktopControllerProvider).message;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            ref.read(desktopControllerProvider.notifier).hide(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            navigationShell.goBranch(0),
        const SingleActivator(LogicalKeyboardKey.keyB,
            control: true, alt: true): () => navigationShell.goBranch(1),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            ref.read(syncControllerProvider.notifier).syncNow(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
            ref.read(monthNavigationProvider.notifier).previous(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
            ref.read(monthNavigationProvider.notifier).next(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: <Widget>[
              const WindowTitleBar(),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 84,
                      decoration: BoxDecoration(
                        color: colors.bgCard,
                        border: Border(
                          right: BorderSide(color: colors.border),
                        ),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: _destinations.length,
                        itemBuilder: (BuildContext context, int index) {
                          final item = _destinations[index];
                          final selected =
                              navigationShell.currentIndex == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxs,
                              horizontal: AppSpacing.xs,
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              onTap: () => navigationShell.goBranch(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? colors.brandSubtle
                                      : null,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Icon(
                                      item.icon,
                                      size: 20,
                                      color: selected
                                          ? colors.brand
                                          : colors.textTertiary,
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: AppTypography.label,
                                        color: selected
                                            ? colors.brand
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          navigationShell,
                          if (desktopMessage != null)
                            Positioned(
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                              child: Material(
                                color: colors.bgOverlay,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  child: Text(
                                    desktopMessage,
                                    style: TextStyle(
                                      fontSize: AppTypography.caption,
                                      color: colors.onBrand,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Destination {
  const _Destination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}
