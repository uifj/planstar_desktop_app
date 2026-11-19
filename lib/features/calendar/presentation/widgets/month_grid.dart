/// 月历网格：支持多列月份、单行模式、周序号列与单元格间距设置。
///
/// ADR-0006：网格结构只 watch 日期骨架 [visibleDaysProvider]（设置 + 导航），
/// 每个单元格经 [dayModelProvider] family 自取当日读模型；单日数据变化只重建
/// 该 cell，回调以稳定引用上抛 day，不再逐 cell 现造闭包。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/value_objects.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/domain/app_settings.dart';
import '../calendar_providers.dart';
import '../read_model/month_data.dart';
import 'day_cell_widget.dart';

final class MonthGrid extends ConsumerWidget {
  const MonthGrid({
    super.key,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTap,
    required this.onToggleLine,
    required this.onToggleEvent,
  });

  final void Function(CalendarDayModel day) onTap;
  final void Function(CalendarDayModel day) onDoubleTap;
  final void Function(CalendarDayModel day, Offset position) onSecondaryTap;
  final void Function(CalendarDayModel day, String lineId) onToggleLine;
  final void Function(CalendarDayModel day, EventOccurrence occurrence)
  onToggleEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final visible = ref.watch(visibleDaysProvider);
    final settings = ref.watch(settingsControllerProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final column in visible.columns) ...<Widget>[
          Expanded(
            child: _column(
              context,
              colors,
              settings,
              visible.weekdayHeaders,
              column,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _column(
    BuildContext context,
    AppColors colors,
    AppSettings settings,
    List<String> weekdayHeaders,
    List<DateKey> days,
  ) {
    final rows = (days.length / 7).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _weekHeader(context, colors, settings, weekdayHeaders),
        const SizedBox(height: AppSpacing.xxs),
        for (var row = 0; row < rows; row++) ...<Widget>[
          SizedBox(
            height: settings.displayMode.isSingleLine ? 96 : 112,
            child: Row(
              children: <Widget>[
                for (var col = 0; col < 7; col++) ...<Widget>[
                  if (col > 0) SizedBox(width: settings.cellGap),
                  Expanded(
                    child: (row * 7 + col) >= days.length
                        ? const SizedBox.shrink()
                        : DayCellWidget(
                            date: days[row * 7 + col],
                            settings: settings,
                            onTap: onTap,
                            onDoubleTap: onDoubleTap,
                            onSecondaryTap: onSecondaryTap,
                            onToggleLine: onToggleLine,
                            onToggleEvent: onToggleEvent,
                          ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: settings.cellGap),
        ],
      ],
    );
  }

  Widget _weekHeader(
    BuildContext context,
    AppColors colors,
    AppSettings settings,
    List<String> weekdayHeaders,
  ) => Row(
    children: <Widget>[
      for (int i = 0; i < weekdayHeaders.length; i++)
        Expanded(
          child: Center(
            child: Text(
              weekdayHeaders[i],
              style: TextStyle(
                fontSize: AppTypography.label,
                color: _isRestDayColumn(settings, i)
                    ? BasePalette.orangeLight6
                    : colors.textSecondary,
                fontWeight: _isRestDayColumn(settings, i)
                    ? AppTypography.medium
                    : AppTypography.regular,
              ),
            ),
          ),
        ),
    ],
  );

  /// 第 [index] 列对应的 weekday，按用户设置的每周起始日旋转后再比对休息日。
  bool _isRestDayColumn(AppSettings settings, int index) =>
      settings.showRestDays &&
      settings.restDays.contains(((settings.startOfWeek - 1 + index) % 7) + 1);
}
