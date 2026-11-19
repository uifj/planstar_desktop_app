/// 日历表现层 Provider：导航 / 选中态 / 月历读模型（纯函数读侧）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../bootstrap/timeline.dart';
import '../../../core/ports/timeline.dart';
import '../../../core/value_objects.dart';
import '../../settings/application/settings_controller.dart';
import '../application/calendar_controller.dart';
import '../domain/calendar_event.dart';
import '../domain/recurrence_policy.dart';
import 'read_model/month_data.dart';

final selectedDateProvider = NotifierProvider<SelectedDateController, DateKey?>(
  SelectedDateController.new,
);

final class SelectedDateController extends Notifier<DateKey?> {
  @override
  DateKey? build() => null;

  void select(DateKey date) => state = date;

  void clear() => state = null;
}

final monthNavigationProvider = NotifierProvider<MonthNavigation, DateTime>(
  MonthNavigation.new,
);

final class MonthNavigation extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, 1);
  }

  void previous() => state = DateTime(state.year, state.month - 1, 1);

  void next() => state = DateTime(state.year, state.month + 1, 1);

  void today() {
    final now = ref.read(clockProvider).now();
    state = DateTime(now.year, now.month, 1);
  }

  void goTo(DateTime date) => state = DateTime(date.year, date.month, 1);
}

final monthDataProvider = Provider<MonthData>((Ref ref) {
  final settings = ref.watch(settingsControllerProvider);
  final calendar = ref.watch(calendarControllerProvider);
  final anchor = ref.watch(monthNavigationProvider);
  final contributions = ref.watch(timelineContributionsProvider);
  final today = DateKey.today(ref.watch(clockProvider).now());
  return CalendarReadModelAssembler(contributions: contributions).assemble(
    anchor: anchor,
    settings: settings,
    calendar: calendar,
    today: today,
  );
});

/// 日期骨架（ADR-0006）：只依赖设置 + 导航 + 今天，不含事件/单元格。
/// 翻月重建网格结构；改数据不触发骨架变化。
final visibleDaysProvider = Provider<VisibleDays>((Ref ref) {
  final settings = ref.watch(settingsControllerProvider);
  final anchor = ref.watch(monthNavigationProvider);
  final today = DateKey.today(ref.watch(clockProvider).now());
  return const CalendarReadModelAssembler(
    contributions: <TimelineContribution>[],
  ).skeleton(anchor: anchor, settings: settings, today: today);
});

/// 每事件展开上下文：仅随 events 列表变化重算（copyWith 保留 events 身份，
/// 单元格变更不触发），供各日模型复用，避免逐日重建展开上下文。
final calendarExpansionsProvider =
    Provider<List<(CalendarEvent, RecurrenceExpansion)>>((Ref ref) {
      final events = ref.watch(
        calendarControllerProvider.select((s) => s.events),
      );
      return CalendarReadModelAssembler.expansionsOf(events);
    });

/// 单日读模型 family（ADR-0006）：任一日历变化都重算，但 [CalendarDayModel]
/// 值相等保证只有内容变化的日期通知其 watcher（Riverpod 按 == 跳过未变值），
/// 其余 DayCellWidget 不重建。
final dayModelProvider = Provider.family<CalendarDayModel, DateKey>((
  Ref ref,
  DateKey date,
) {
  final calendar = ref.watch(calendarControllerProvider);
  final settings = ref.watch(settingsControllerProvider);
  final expansions = ref.watch(calendarExpansionsProvider);
  final visible = ref.watch(visibleDaysProvider);
  final contributions = ref.watch(timelineContributionsProvider);
  final today = DateKey.today(ref.watch(clockProvider).now());
  return CalendarReadModelAssembler(contributions: contributions).day(
    date: date,
    settings: settings,
    calendar: calendar,
    today: today,
    referenceMonth: visible.monthOf[date] ?? date.date,
    expansions: expansions,
  );
});

/// 底部倒数日条条目（贡献侧预计算）。
final countdownBarProvider = Provider<List<TimelineBarEntry>>((Ref ref) {
  final contributions = ref.watch(timelineContributionsProvider);
  return CalendarReadModelAssembler(contributions: contributions).bar;
});
