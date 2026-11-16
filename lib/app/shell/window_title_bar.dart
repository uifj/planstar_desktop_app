/// 无边框窗口的自定义标题栏（旧版 `bar_title` / `go_home` / `previous_page`
/// / `next_page` / `cloud_sync` / `sys_menu` 工具条的等价实现）。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bootstrap/core_providers.dart';
import '../../features/calendar/application/calendar_controllers.dart';
import '../../features/reminder/application/reminder_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/sync/application/sync_controller.dart';

final class WindowTitleBar extends ConsumerWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final anchor = ref.watch(monthNavigationProvider);
    final account = ref.watch(syncControllerProvider).account;
    final scheduled = ref.watch(reminderControllerProvider).scheduled;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => ref.read(windowGatewayProvider).startDragging(),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colors.bgCard,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(LucideIcons.calendarDays, size: 20, color: colors.brand),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '企划星 · 桌面日历清单',
              style: TextStyle(
                fontSize: AppTypography.subtitle,
                fontWeight: AppTypography.medium,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            _icon(LucideIcons.chevronsLeft, '上一页', () =>
                ref.read(monthNavigationProvider.notifier).previous()),
            _icon(LucideIcons.house, '返回今日', () =>
                ref.read(monthNavigationProvider.notifier).today()),
            _icon(LucideIcons.chevronsRight, '下一页', () =>
                ref.read(monthNavigationProvider.notifier).next()),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${anchor.year}年${anchor.month}月',
              style: TextStyle(
                fontSize: AppTypography.body,
                color: colors.textSecondary,
              ),
            ),
            const Spacer(),
            _icon(LucideIcons.search, '搜日历清单', () => context.go('/search')),
            _icon(LucideIcons.bell, '提醒（已排 $scheduled 条）', () =>
                ref.read(reminderControllerProvider.notifier).showTestAlert()),
            _icon(LucideIcons.cloudSync, '手动同步', () =>
                ref.read(syncControllerProvider.notifier).syncNow()),
            _icon(LucideIcons.sunMoon, '切换主题', () {
              final current = ref.read(settingsControllerProvider).themeMode;
              final next = current == AppThemeMode.dark
                  ? AppThemeMode.light
                  : AppThemeMode.dark;
              ref
                  .read(settingsControllerProvider.notifier)
                  .update((AppSettings s) => s.copyWith(themeMode: next));
            }),
            _icon(LucideIcons.settings, '设置', () => context.go('/settings')),
            const SizedBox(width: AppSpacing.sm),
            Text(
              account.displayName,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _windowButton(
              context,
              LucideIcons.minus,
              () => ref.read(windowGatewayProvider).minimize(),
            ),
            _windowButton(
              context,
              LucideIcons.maximize2,
              () => ref.read(windowGatewayProvider).toggleMaximize(),
            ),
            _windowButton(
              context,
              LucideIcons.x,
              () => ref.read(windowGatewayProvider).close(),
              danger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _windowButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final colors = context.appColors;
    return IconButton(
      icon: Icon(icon, size: 16, color: danger ? colors.error : null),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
