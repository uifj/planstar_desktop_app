/// 日历底部倒数日条（旧版 `calendar bottom countdown`）。
///
/// 条目是贡献侧预计算好的 [TimelineBarEntry]，本组件不 import countdown。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ports/timeline.dart';
import '../../../../shared/widgets/common.dart';
import '../../../desktop/application/desktop_controller.dart';
import '../calendar_providers.dart';

final class CountdownBar extends ConsumerWidget {
  const CountdownBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final items = ref.watch(countdownBarProvider);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: <Widget>[
          Icon(LucideIcons.hourglass, size: 18, color: colors.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                final color = Color(item.colorArgb);
                return InkWell(
                  onTap: () => ref
                      .read(desktopControllerProvider.notifier)
                      .openCountdownWindow(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: AppTypography.body,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          item.displayText,
                          style: TextStyle(
                            fontSize: AppTypography.body,
                            fontWeight: AppTypography.medium,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const AppChip(label: '点击打开桌面卡片', dense: true),
        ],
      ),
    );
  }
}
