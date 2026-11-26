/// 月历网格：支持多列月份、单行模式、周序号列与单元格间距设置。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';

import '../../../../core/value_objects.dart';
import '../../../settings/domain/app_settings.dart';
import '../../application/calendar_controllers.dart';
import 'day_cell_widget.dart';

final class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.data,
    required this.settings,
    required this.selectedDate,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTap,
    required this.onToggleLine,
    required this.onToggleEvent,
  });

  final MonthData data;
  final AppSettings settings;
  final DateKey? selectedDate;
  final void Function(CalendarDayModel day) onTap;
  final void Function(CalendarDayModel day) onDoubleTap;
  final void Function(CalendarDayModel day, Offset position) onSecondaryTap;
  final void Function(CalendarDayModel day, String lineId) onToggleLine;
  final void Function(CalendarDayModel day, EventOccurrence occurrence)
  onToggleEvent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final column in data.columns) ...<Widget>[
          Expanded(child: _column(context, colors, column)),
          const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _column(
    BuildContext context,
    AppColors colors,
    List<CalendarDayModel> days,
  ) {
    final rows = (days.length / 7).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _weekHeader(context, colors),
        const SizedBox(height: AppSpacing.xxs),
        for (var row = 0; row < rows; row++) ...<Widget>[
          SizedBox(
            height: settings.displayMode.isSingleLine ? 96 : 112,
            child: Row(
              children: <Widget>[
                for (var col = 0; col < 7; col++) ...<Widget>[
                  if (col > 0) SizedBox(width: settings.cellGap),
                  Expanded(
                    child: Builder(
                      builder: (BuildContext context) {
                        final index = row * 7 + col;
                        if (index >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final day = days[index];
                        return DayCellWidget(
                          day: day,
                          settings: settings,
                          selected: selectedDate == day.date,
                          onTap: () => onTap(day),
                          onDoubleTap: () => onDoubleTap(day),
                          onSecondaryTap: (Offset position) =>
                              onSecondaryTap(day, position),
                          onToggleLine: (String id) => onToggleLine(day, id),
                          onToggleEvent: (EventOccurrence occurrence) =>
                              onToggleEvent(day, occurrence),
                        );
                      },
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

  Widget _weekHeader(BuildContext context, AppColors colors) => Row(
    children: <Widget>[
      for (int i = 0; i < data.weekdayHeaders.length; i++)
        Expanded(
          child: Center(
            child: Text(
              data.weekdayHeaders[i],
              style: TextStyle(
                fontSize: AppTypography.label,
                color: _isRestDayColumn(i)
                    ? BasePalette.orangeLight6
                    : colors.textSecondary,
                fontWeight: _isRestDayColumn(i)
                    ? AppTypography.medium
                    : AppTypography.regular,
              ),
            ),
          ),
        ),
    ],
  );

  /// 第 [index] 列对应的 weekday，按用户设置的每周起始日旋转后再比对休息日。
  bool _isRestDayColumn(int index) =>
      settings.showRestDays &&
      settings.restDays.contains(((settings.startOfWeek - 1 + index) % 7) + 1);
}
