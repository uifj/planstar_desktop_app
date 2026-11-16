/// 月历标题栏：月份导航、显示模式切换、新建任务。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/application/settings_controller.dart';
import '../../../settings/domain/app_settings.dart';
import '../../application/calendar_controllers.dart';

final class CalendarTitleBar extends ConsumerWidget {
  const CalendarTitleBar({
    super.key,
    required this.onNewEvent,
  });

  final VoidCallback onNewEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final anchor = ref.watch(monthNavigationProvider);
    final settings = ref.watch(settingsControllerProvider);
    final navigation = ref.read(monthNavigationProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${anchor.year} 年 ${anchor.month} 月',
            style: TextStyle(
              fontSize: AppTypography.title,
              fontWeight: AppTypography.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            tooltip: '上一页',
            icon: const Icon(Icons.chevron_left),
            onPressed: navigation.previous,
          ),
          OutlinedButton(
            onPressed: navigation.today,
            child: const Text('今天'),
          ),
          IconButton(
            tooltip: '下一页',
            icon: const Icon(Icons.chevron_right),
            onPressed: navigation.next,
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 150,
            child: DropdownButton<CalendarDisplayMode>(
              value: settings.displayMode,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: CalendarDisplayMode.values
                  .map(
                    (CalendarDisplayMode mode) => DropdownMenuItem<
                        CalendarDisplayMode>(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(),
              onChanged: (CalendarDisplayMode? value) {
                if (value == null) return;
                ref.read(settingsControllerProvider.notifier).update(
                      (AppSettings s) => s.copyWith(displayMode: value),
                    );
              },
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onNewEvent,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建任务'),
          ),
        ],
      ),
    );
  }
}
