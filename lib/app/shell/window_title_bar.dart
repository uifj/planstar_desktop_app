/// 无边框窗口的自定义标题栏（旧版 `bar_title` / `go_home` / `previous_page`
/// / `next_page` / `cloud_sync` / `sys_menu` 工具条的等价实现）。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../bootstrap/core_providers.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/calendar/application/calendar_controllers.dart';
import '../../features/reminder/application/reminder_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/sync/application/sync_controller.dart';
import '../../l10n/l10n.dart';

final class WindowTitleBar extends ConsumerWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final anchor = ref.watch(monthNavigationProvider);
    final user = ref.watch(authControllerProvider).user;
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
              l10n.appTitle,
              style: TextStyle(
                fontSize: AppTypography.subtitle,
                fontWeight: AppTypography.medium,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            _icon(
              LucideIcons.chevronsLeft,
              l10n.navPreviousMonth,
              () => ref.read(monthNavigationProvider.notifier).previous(),
            ),
            _icon(
              LucideIcons.house,
              l10n.navGoToToday,
              () => ref.read(monthNavigationProvider.notifier).today(),
            ),
            _icon(
              LucideIcons.chevronsRight,
              l10n.navNextMonth,
              () => ref.read(monthNavigationProvider.notifier).next(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              DateFormat.yMMMM(l10n.localeName).format(anchor),
              style: TextStyle(
                fontSize: AppTypography.body,
                color: colors.textSecondary,
              ),
            ),
            const Spacer(),
            _icon(
              LucideIcons.search,
              l10n.navSearchAction,
              () => context.go('/search'),
            ),
            _icon(
              LucideIcons.bell,
              l10n.navReminderStatus(scheduled),
              () =>
                  ref.read(reminderControllerProvider.notifier).showTestAlert(),
            ),
            _icon(
              LucideIcons.cloudSync,
              l10n.commonSyncNow,
              () => ref.read(syncControllerProvider.notifier).syncNow(),
            ),
            _icon(LucideIcons.sunMoon, l10n.navToggleTheme, () {
              final current = ref.read(settingsControllerProvider).themeMode;
              final next = current == AppThemeMode.dark
                  ? AppThemeMode.light
                  : AppThemeMode.dark;
              ref
                  .read(settingsControllerProvider.notifier)
                  .update((AppSettings s) => s.copyWith(themeMode: next));
            }),
            _icon(
              LucideIcons.settings,
              l10n.commonSettings,
              () => context.go('/settings'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              user?.displayName.isNotEmpty == true
                  ? user!.displayName
                  : user?.maskedMobile ?? l10n.navAnonymousAccount,
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
              tooltip: l10n.commonMinimize,
            ),
            _windowButton(
              context,
              LucideIcons.maximize2,
              () => ref.read(windowGatewayProvider).toggleMaximize(),
              tooltip: l10n.commonMaximize,
            ),
            _windowButton(
              context,
              LucideIcons.x,
              () => ref.read(windowGatewayProvider).close(),
              danger: true,
              tooltip: l10n.navHideToTray,
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
    String? tooltip,
  }) {
    final colors = context.appColors;
    final button = IconButton(
      icon: Icon(icon, size: 16, color: danger ? colors.error : null),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
