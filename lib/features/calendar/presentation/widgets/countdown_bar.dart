/// 日历底部倒数日条（旧版 `calendar bottom countdown`）。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/core_providers.dart';
import '../../../../core/value_objects.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/common.dart';
import '../../../countdown/domain/countdown.dart';
import '../../../desktop/application/desktop_controller.dart';

final class CountdownBar extends ConsumerWidget {
  const CountdownBar({super.key, required this.items});

  final List<CountdownItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.appColors;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final today = DateKey.today(ref.watch(clockProvider).now());
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
                return Tooltip(
                  message: l10n.calendarOpenCountdownCard,
                  child: InkWell(
                    onTap: () => ref
                        .read(desktopControllerProvider.notifier)
                        .openCountdownWindow(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: item.color.toColor().withValues(alpha: 0.10),
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
                            item.localizedDisplayText(l10n, today),
                            style: TextStyle(
                              fontSize: AppTypography.body,
                              fontWeight: AppTypography.medium,
                              color: item.color.toColor(),
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
          AppChip(label: l10n.calendarOpenCountdownCard, dense: true),
        ],
      ),
    );
  }
}
