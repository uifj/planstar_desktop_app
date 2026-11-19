/// 月历视图模型与显式装配器（ADR-0004）。
///
/// 兄弟 feature 的条目经 [TimelineContribution] 注入，日历不再 import
/// countdown / subscription / timetable；新增来源只需在组合根注册贡献。
library;

import 'package:core/domain.dart';

import '../../../../core/calendar_math.dart';
import '../../../../core/ports/timeline.dart';
import '../../../../core/value_objects.dart';
import '../../../settings/domain/app_settings.dart';
import '../../application/calendar_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/day_cell.dart';
import '../../domain/recurrence_policy.dart';

final class EventOccurrence extends ValueObject {
  const EventOccurrence(this.event, this.date);

  final CalendarEvent event;
  final DateKey date;

  bool get completed => event.isCompletedOn(date);

  @override
  List<Object?> get props => <Object?>[event, date];
}

final class CalendarDayModel extends ValueObject {
  const CalendarDayModel({
    required this.date,
    required this.meta,
    required this.cell,
    required this.events,
    required this.tags,
    required this.isToday,
    required this.isCurrentMonth,
  });

  final DateKey date;
  final CalendarDayMeta meta;
  final DayCell? cell;
  final List<EventOccurrence> events;

  /// 兄弟 feature 的按日条目（全量、按贡献注册顺序）；
  /// 截断与配色是渲染侧决策（见 DayCellWidget / 壁纸渲染）。
  final List<TimelineTag> tags;
  final bool isToday;
  final bool isCurrentMonth;

  bool get isRestDay => meta.isRestDay || meta.isMakeupWorkday;

  @override
  List<Object?> get props => <Object?>[
    date,
    meta,
    cell,
    events,
    tags,
    isToday,
    isCurrentMonth,
  ];
}

final class MonthData extends ValueObject {
  const MonthData({
    required this.anchor,
    required this.weekdayHeaders,
    required this.columns,
    required this.countdownBar,
  });

  final DateTime anchor;
  final List<String> weekdayHeaders;
  final List<List<CalendarDayModel>> columns;
  final List<TimelineBarEntry> countdownBar;

  @override
  List<Object?> get props => <Object?>[
    anchor,
    weekdayHeaders,
    columns,
    countdownBar,
  ];
}

/// 月历日期骨架（ADR-0006）：只依赖设置 + 导航 + 今天，不含事件/单元格数据。
/// 翻月只重建骨架，单日数据变化只影响该日模型，互不牵连。
final class VisibleDays extends ValueObject {
  const VisibleDays({
    required this.anchor,
    required this.weekdayHeaders,
    required this.columns,
    required this.monthOf,
  });

  final DateTime anchor;
  final List<String> weekdayHeaders;
  final List<List<DateKey>> columns;

  /// 每个日期所属列的参考月（取列中日），用于 isCurrentMonth 判定（补位日变暗）。
  final Map<DateKey, DateTime> monthOf;

  @override
  List<Object?> get props => <Object?>[
    anchor,
    weekdayHeaders,
    columns,
    monthOf,
  ];
}

/// 把写侧状态 + 全局设置 + 各来源贡献装配成月历读模型的纯函数装配器。
final class CalendarReadModelAssembler {
  const CalendarReadModelAssembler({required this.contributions});

  final List<TimelineContribution> contributions;

  /// 日期骨架（纯几何，不含事件/单元格）。
  VisibleDays skeleton({
    required DateTime anchor,
    required AppSettings settings,
    required DateKey today,
  }) {
    final grids = CalendarMath.buildGrid(
      anchor: anchor,
      startOfWeek: settings.startOfWeek,
      rows: settings.maxRows,
      columns: settings.maxColumns,
      passedWeeks: settings.passedWeeks,
      singleLine: settings.displayMode.isSingleLine,
      today: today.date,
    );
    final monthOf = <DateKey, DateTime>{};
    for (final column in grids) {
      final month = column[column.length ~/ 2].date;
      for (final date in column) {
        monthOf[date] = month;
      }
    }
    return VisibleDays(
      anchor: anchor,
      weekdayHeaders: CalendarMath.weekdayHeaders(settings.startOfWeek),
      columns: grids,
      monthOf: monthOf,
    );
  }

  /// 每事件展开上下文（ADR-0001 反转展开）：预计算 count 边界与农历不变量，
  /// 供同一轮读模型计算内对多个日期复用，避免逐日重算。
  static List<(CalendarEvent, RecurrenceExpansion)> expansionsOf(
    List<CalendarEvent> events,
  ) => <(CalendarEvent, RecurrenceExpansion)>[
    for (final event in events) (event, RecurrencePolicy.expansionOf(event)),
  ];

  /// 单日读模型：family provider 与全量 [assemble] 共用此纯函数（单一真实源）。
  CalendarDayModel day({
    required DateKey date,
    required AppSettings settings,
    required CalendarState calendar,
    required DateKey today,
    required DateTime referenceMonth,
    required List<(CalendarEvent, RecurrenceExpansion)> expansions,
  }) => CalendarDayModel(
    date: date,
    meta: CalendarMath.metaOf(date, firstWeekOffset: settings.firstWeekOffset),
    cell: calendar.cells[date],
    events: <EventOccurrence>[
      for (final (event, expansion) in expansions)
        if (expansion.happensOn(date)) EventOccurrence(event, date),
    ],
    tags: <TimelineTag>[
      for (final contribution in contributions)
        ...contribution.tagsOn(date.date),
    ],
    isToday: date == today,
    isCurrentMonth:
        date.month == referenceMonth.month && date.year == referenceMonth.year,
  );

  /// 底部横条条目（贡献侧预计算）。
  List<TimelineBarEntry> get bar => <TimelineBarEntry>[
    for (final contribution in contributions) ...contribution.bar,
  ];

  MonthData assemble({
    required DateTime anchor,
    required AppSettings settings,
    required CalendarState calendar,
    required DateKey today,
  }) {
    final visible = skeleton(anchor: anchor, settings: settings, today: today);
    final expansions = expansionsOf(calendar.events);
    final columns = visible.columns.map((List<DateKey> days) {
      final month = visible.monthOf[days[days.length ~/ 2]]!;
      return days
          .map(
            (DateKey date) => day(
              date: date,
              settings: settings,
              calendar: calendar,
              today: today,
              referenceMonth: month,
              expansions: expansions,
            ),
          )
          .toList();
    }).toList();

    return MonthData(
      anchor: anchor,
      weekdayHeaders: visible.weekdayHeaders,
      columns: columns,
      countdownBar: bar,
    );
  }
}
