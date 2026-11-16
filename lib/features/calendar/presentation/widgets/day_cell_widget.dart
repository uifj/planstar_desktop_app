/// 单个日期单元格：日期 / 农历节气 / 节假日 / 富文本 / 任务 / 订阅 / 课程。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../../../../core/value_objects.dart';
import '../../../../shared/widgets/common.dart';
import '../../../countdown/domain/countdown.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../subscription/domain/subscription.dart';
import '../../../timetable/domain/timetable.dart';
import '../../application/calendar_controllers.dart';

final class DayCellWidget extends StatelessWidget {
  const DayCellWidget({
    super.key,
    required this.day,
    required this.settings,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTap,
    required this.onToggleLine,
    required this.onToggleEvent,
  });

  final CalendarDayModel day;
  final AppSettings settings;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(Offset position) onSecondaryTap;
  final ValueChanged<String> onToggleLine;
  final ValueChanged<EventOccurrence> onToggleEvent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dimmed = !day.isCurrentMonth;
    final restColor = Color(settings.holidayTextColor);
    final cellColor = day.cell?.backgroundColor;
    final background = (cellColor == null || cellColor.isTransparent)
        ? Color(settings.calendarBackgroundColor)
        : cellColor.toColor();

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onSecondaryTapDown: (TapDownDetails details) =>
          onSecondaryTap(details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: background.withValues(
            alpha: (dimmed ? 0.55 : 1.0) * settings.calendarTransparency,
          ),
          border: Border.all(
            color: selected ? colors.brand : colors.border,
            width: selected ? 2 : 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _header(context, colors, restColor, dimmed),
            const SizedBox(height: 2),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ...day.cell?.lines
                            .where(
                              (RichLine l) =>
                                  settings.showCompleted || !l.completed,
                            )
                            .map(
                              (RichLine line) => _line(context, line),
                            ) ??
                        const <Widget>[],
                    ...day.events.map(_event),
                    ...day.subscriptionEvents.map(
                      (SubscriptionEvent e) =>
                          _tag(context, e.title, colors.warning),
                    ),
                    ...day.lessons.take(2).map(
                          (Lesson l) => _tag(context, l.name, colors.success),
                        ),
                    ...day.countdowns.take(1).map(
                          (CountdownItem c) =>
                              _tag(context, c.title, colors.brand),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    AppColors colors,
    Color restColor,
    bool dimmed,
  ) {
    final subtitle = day.meta.subtitle(
      showLunar: settings.showLunar,
      showSolarTerms: settings.showSolarTerms,
      showFestival: settings.showFestival,
    );
    return Row(
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          decoration: day.isToday
              ? BoxDecoration(
                  color: Color(settings.todayBorderColor),
                  shape: BoxShape.circle,
                )
              : null,
          alignment: Alignment.center,
          child: Text(
            '${day.date.day}',
            style: TextStyle(
              fontSize: settings.calendarFontSize,
              fontWeight: day.isToday ? AppTypography.bold : AppTypography.regular,
              color: day.isToday
                  ? colors.onBrand
                  : (settings.showRestDays && day.isRestDay
                      ? restColor
                      : Color(settings.calendarFontColor)),
            ),
          ),
        ),
        if (settings.showHoliday && day.meta.isRestDay)
          _badge(context, '休', colors.error),
        if (settings.showHoliday && day.meta.isMakeupWorkday)
          _badge(context, '班', colors.warning),
        const Spacer(),
        if (settings.showWeekNumber)
          Text(
            '${day.meta.weekNumber}',
            style: TextStyle(
              fontSize: AppTypography.micro,
              color: colors.textDisabled,
            ),
          ),
        if (subtitle.isNotEmpty)
          Flexible(
            child: Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: AppTypography.micro,
                color: dimmed ? colors.textDisabled : colors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _badge(BuildContext context, String text, Color color) => Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: AppTypography.micro, color: color),
        ),
      );

  Widget _line(BuildContext context, RichLine line) => InkWell(
        onTap: () => onToggleLine(line.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: <Widget>[
              if (settings.bulletStyle == BulletStyle.dot)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: line.color.toColor(),
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(
                  line.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: settings.contentFontSize,
                    color: line.color.toColor(),
                    decoration: line.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              if (settings.showReminderDate && line.reminderTime != null)
                Text(
                  '${line.reminderTime!.hour}:'
                  '${line.reminderTime!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: AppTypography.micro,
                    color: context.appColors.textDisabled,
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _event(EventOccurrence occurrence) => InkWell(
        onTap: () => onToggleEvent(occurrence),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: <Widget>[
              Icon(
                occurrence.completed
                    ? LucideIcons.squareCheck
                    : LucideIcons.square,
                size: 12,
                color: occurrence.event.color.toColor(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  occurrence.event.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: settings.contentFontSize,
                    color: occurrence.event.color.toColor(),
                    decoration: occurrence.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _tag(BuildContext context, String text, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          '· $text',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppTypography.label, color: color),
        ),
      );
}
