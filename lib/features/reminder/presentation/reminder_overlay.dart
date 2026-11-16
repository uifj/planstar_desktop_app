/// 应用内置顶提醒弹窗（旧版 `EventReminderPopup` + 「不再显示窗口」）。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reminder_controller.dart';

final class ReminderOverlay extends ConsumerWidget {
  const ReminderOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(reminderControllerProvider).alert;
    if (alert == null) return const SizedBox.shrink();
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
                    '任务提醒',
                    style: TextStyle(
                      fontSize: AppTypography.subtitle,
                      fontWeight: AppTypography.medium,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => ref
                        .read(reminderControllerProvider.notifier)
                        .dismiss(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                alert.title,
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                alert.date.cnFull,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => ref
                        .read(reminderControllerProvider.notifier)
                        .dismiss(),
                    child: const Text('不再显示窗口'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    onPressed: () => ref
                        .read(reminderControllerProvider.notifier)
                        .dismiss(),
                    child: const Text('知道了'),
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
