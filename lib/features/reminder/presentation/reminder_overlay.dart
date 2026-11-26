/// 应用内置顶提醒弹窗（旧版 `EventReminderPopup` + 「不再显示窗口」）。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/reminder_controller.dart';

final class ReminderOverlay extends ConsumerWidget {
  const ReminderOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(reminderControllerProvider).alert;
    if (alert == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.appColors;
    return Positioned(
      right: AppSpacing.xl,
      top: AppSpacing.huge,
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.bgCard,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.brand, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(LucideIcons.alarmClock, size: 18, color: colors.brand),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.reminderTaskTitle,
                    style: TextStyle(
                      fontSize: AppTypography.subtitle,
                      fontWeight: AppTypography.medium,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.reminderDismissTooltip,
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () =>
                        ref.read(reminderControllerProvider.notifier).dismiss(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                alert.title ?? l10n.reminderTaskTitle,
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                alert.date.fullDate(l10n),
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                children: <Widget>[
                  TextButton(
                    onPressed: () =>
                        ref.read(reminderControllerProvider.notifier).dismiss(),
                    child: Text(l10n.reminderDontShowAgain),
                  ),
                  FilledButton(
                    onPressed: () =>
                        ref.read(reminderControllerProvider.notifier).dismiss(),
                    child: Text(l10n.reminderAcknowledge),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
