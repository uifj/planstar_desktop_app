/// 单个日期单元格：日期 / 农历节气 / 节假日 / 富文本 / 任务 / 订阅 / 课程。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/ports/timeline.dart';
import '../../../../core/value_objects.dart';
import '../../../../shared/widgets/common.dart';
import '../../../settings/domain/app_settings.dart';
import '../calendar_providers.dart';
import '../read_model/month_data.dart';

/// ADR-0006：单元格自取当日读模型与选中态切片；单日数据变化只重建本 cell。
final class DayCellWidget extends ConsumerWidget {
  const DayCellWidget({
    super.key,
    required this.date,
    required this.settings,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTap,
    required this.onToggleLine,
    required this.onToggleEvent,
  });

  final DateKey date;
  final AppSettings settings;
  final void Function(CalendarDayModel day) onTap;
  final void Function(CalendarDayModel day) onDoubleTap;
  final void Function(CalendarDayModel day, Offset position) onSecondaryTap;
  final void Function(CalendarDayModel day, String lineId) onToggleLine;
  final void Function(CalendarDayModel day, EventOccurrence occurrence)
  onToggleEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(dayModelProvider(date));
    final selected = ref.watch(selectedDateProvider.select((d) => d == date));
    return _DayCellView(
      day: day,
      settings: settings,
      selected: selected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onSecondaryTap: onSecondaryTap,
      onToggleLine: onToggleLine,
      onToggleEvent: onToggleEvent,
    );
  }
}

final class _DayCellView extends StatelessWidget {
  const _DayCellView({
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
  final void Function(CalendarDayModel day) onTap;
  final void Function(CalendarDayModel day) onDoubleTap;
  final void Function(CalendarDayModel day, Offset position) onSecondaryTap;
  final void Function(CalendarDayModel day, String lineId) onToggleLine;
  final void Function(CalendarDayModel day, EventOccurrence occurrence)
  onToggleEvent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dimmed = !day.isCurrentMonth;
    final restColor = Color(settings.holidayTextColor);
    // 周六周日按 weekday 判定（1=周一…7=周日），复用用户已有的休息日设置。
    final weekend =
        settings.showRestDays && settings.restDays.contains(day.date.weekday);
    final cellColor = day.cell?.backgroundColor;
    final hasCustom = cellColor != null && !cellColor.isTransparent;
    var background = hasCustom
        ? cellColor.toColor()
        : Color(settings.calendarBackgroundColor);
    // 周末列叠一层低饱和暖色；不覆盖用户自定义底色，也不作用于补位日期。
    if (weekend && !hasCustom && !dimmed) {
      background = Color.alphaBlend(
        BasePalette.orangeLight3.withValues(alpha: 0.10),
        background,
      );
    }

    return GestureDetector(
      onTap: () => onTap(day),
      onDoubleTap: () => onDoubleTap(day),
      onSecondaryTapDown: (TapDownDetails details) =>
          onSecondaryTap(day, details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: background.withValues(
            alpha: (dimmed ? 0.55 : 1.0) * settings.calendarTransparency,
          ),
          border: Border.all(
            color: selected
                ? colors.brand
                : weekend && !hasCustom && !dimmed
                ? BasePalette.orangeLight3.withValues(alpha: 0.45)
                : colors.border,
            width: selected ? 2 : 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _header(context, colors, restColor, dimmed, weekend),
            const SizedBox(height: 2),
            Expanded(
              // 行高固定，溢出裁剪而非滚动（ADR-0006）：OverflowBox 给 Column
              // 自然高度避免 RenderFlex 溢出报错，ClipRect 裁到单元格边界；
              // 完整内容经选中日的 CellEditorPanel 查看（既有兜底）。
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ...day.cell?.lines
                              .where(
                                (RichLine l) =>
                                    settings.showCompleted || !l.completed,
                              )
                              .map((RichLine line) => _line(context, line)) ??
                          const <Widget>[],
                      ...day.events.map(_event),
                      // 截断规则属渲染侧：订阅全量、课程取 2、倒数日取 1。
                      ...day.tags
                          .where(
                            (TimelineTag t) =>
                                t.kind == TimelineTagKind.subscription,
                          )
                          .map(
                            (TimelineTag t) =>
                                _tag(context, t.text, colors.warning),
                          ),
                      ...day.tags
                          .where(
                            (TimelineTag t) => t.kind == TimelineTagKind.lesson,
                          )
                          .take(2)
                          .map(
                            (TimelineTag t) =>
                                _tag(context, t.text, colors.success),
                          ),
                      ...day.tags
                          .where(
                            (TimelineTag t) =>
                                t.kind == TimelineTagKind.countdown,
                          )
                          .take(1)
                          .map(
                            (TimelineTag t) =>
                                _tag(context, t.text, colors.brand),
                          ),
                    ],
                  ),
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
    bool weekend,
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
              fontWeight: day.isToday
                  ? AppTypography.bold
                  : AppTypography.regular,
              color: day.isToday
                  ? colors.onBrand
                  : dimmed
                  ? colors.textDisabled
                  : (settings.showRestDays && (day.isRestDay || weekend)
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
    onTap: () => onToggleLine(day, line.id),
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
    onTap: () => onToggleEvent(day, occurrence),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: <Widget>[
          Icon(
            occurrence.completed ? LucideIcons.squareCheck : LucideIcons.square,
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
