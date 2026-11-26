/// 日历应用服务 + Riverpod 状态 / 月历读模型。
///
/// 数据流：仓储（Result）→ CalendarController（写侧状态）→
/// monthDataProvider（纯函数读模型）→ 月历组件。写侧产生的领域事件由
/// 提醒 / 历史 / 同步控制器订阅，彼此不直接依赖。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/calendar_math.dart';
import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../countdown/application/countdown_controller.dart';
import '../../countdown/domain/countdown.dart';
import '../../settings/application/settings_controller.dart';
import '../../subscription/application/subscription_controller.dart';
import '../../subscription/domain/subscription.dart';
import '../../timetable/application/timetable_controller.dart';
import '../../timetable/domain/timetable.dart';
import '../domain/calendar_event.dart';
import '../domain/day_cell.dart';
import '../domain/recurrence.dart';
import '../domain/recurrence_policy.dart';
import '../domain/reminder_spec.dart';
import '../domain/repositories.dart';
import '../infrastructure/local_calendar_repository.dart';

// ── 组合 ────────────────────────────────────────────────────────────────────

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (Ref ref) => LocalCalendarRepository(
    store: ref.watch(keyValueStoreProvider),
    bus: ref.watch(domainEventBusProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  ),
);

// ── 写侧状态 ───────────────────────────────────────────────────────────────

final class CalendarState {
  const CalendarState({
    this.events = const <CalendarEvent>[],
    this.cells = const <DayCell>[],
    this.loading = true,
    this.error,
  });

  final List<CalendarEvent> events;
  final List<DayCell> cells;
  final bool loading;
  final String? error;

  CalendarState copyWith({
    List<CalendarEvent>? events,
    List<DayCell>? cells,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => CalendarState(
    events: events ?? this.events,
    cells: cells ?? this.cells,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

final class CalendarController extends Notifier<CalendarState> {
  AppLocalizations get _l10n =>
      ref.read(appLocalizationScopeProvider).localizations;

  @override
  CalendarState build() {
    final scope = ref.read(appLocalizationScopeProvider);
    scope.addListener(_onLocaleChanged);
    ref.onDispose(() => scope.removeListener(_onLocaleChanged));
    Future.microtask(load);
    return const CalendarState();
  }

  void _onLocaleChanged() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  CalendarRepository get _repository => ref.read(calendarRepositoryProvider);

  DateTime get _now => ref.read(clockProvider).now();

  Future<void> load() async {
    // 两个读操作互不依赖：同时发起，把两次 JSON 解析的等待时间重叠起来。
    final eventsFuture = _repository.allEvents();
    final cellsFuture = _repository.allCells();
    final events = await eventsFuture;
    final cells = await cellsFuture;
    if (events case Fail<List<CalendarEvent>>(:final Failure failure)) {
      state = state.copyWith(
        loading: false,
        error: failureLabel(failure, _l10n),
      );
      return;
    }
    if (cells case Fail<List<DayCell>>(:final Failure failure)) {
      state = state.copyWith(
        loading: false,
        error: failureLabel(failure, _l10n),
      );
      return;
    }
    state = state.copyWith(
      events: events.requireData,
      cells: cells.requireData,
      loading: false,
      clearError: true,
    );
  }

  // ── 事件 CRUD ────────────────────────────────────────────────────────────

  Future<CalendarEvent> createEvent({
    required String content,
    required DateKey startDate,
    CalendarEventType type = CalendarEventType.task,
    EventColor color = EventColor.defaultText,
    EventColor backgroundColor = EventColor.transparent,
    RecurrenceRule recurrence = const RecurrenceRule(),
    ReminderSpec? reminder,
    String? subscriptionId,
    String? source,
  }) async {
    final event = CalendarEvent.create(
      id: ref.read(idGeneratorProvider).next(),
      content: content,
      startDate: startDate,
      occurredAt: _now,
      type: type,
      color: color,
      backgroundColor: backgroundColor,
      recurrence: recurrence,
      reminder: reminder,
      subscriptionId: subscriptionId,
      source: source,
    );
    await _repository.saveEvent(event);
    await load();
    return event;
  }

  Future<void> saveEvent(CalendarEvent event) async {
    await _repository.saveEvent(event);
    await load();
  }

  /// 重复事件删除三态：current=记例外、future=截断、all=物理删除。
  Future<void> deleteEvent(
    CalendarEvent event, {
    required DateKey onDate,
    required DeleteScope scope,
  }) async {
    switch (scope) {
      case DeleteScope.current:
        if (!event.recurrence.isRecurring) {
          await _repository.deleteEvent(event.id);
        } else {
          await _repository.saveEvent(event.exclude(onDate, _now));
        }
      case DeleteScope.currentAndFuture:
        if (!event.recurrence.isRecurring) {
          await _repository.deleteEvent(event.id);
        } else {
          await _repository.saveEvent(event.truncateBefore(onDate, _now));
        }
      case DeleteScope.all:
        await _repository.deleteEvent(event.id);
    }
    await load();
  }

  Future<void> toggleEventCompleted(CalendarEvent event, DateKey date) async {
    final next = event.markCompleted(date, !event.isCompletedOn(date), _now);
    await _repository.saveEvent(next);
    final settings = ref.read(settingsControllerProvider);
    await ref.read(soundGatewayProvider).play(settings.taskCompleteTone);
    await load();
  }

  /// 未完成任务 30 天内自动顺延（旧版 `AutoDelay` / VIP）。
  Future<void> autoDelayUncompleted(DateKey today) async {
    final cutoff = today.addDays(-30);
    for (final event in state.events) {
      if (event.recurrence.isRecurring ||
          event.startDate.differenceInDays(cutoff) < 0 ||
          event.startDate.differenceInDays(today) > 0) {
        continue;
      }
      var hasCompletion = false;
      for (final date in event.completedDates) {
        if (date == event.startDate) hasCompletion = true;
      }
      if (hasCompletion) continue;
      await _repository.saveEvent(
        event.changed(startDate: today, occurredAt: _now),
      );
    }
    await load();
  }

  // ── 单元格编辑 ──────────────────────────────────────────────────────────

  DayCell _cellOf(DateKey date) {
    for (final cell in state.cells) {
      if (cell.date == date) return cell;
    }
    return DayCell.create(date, _now);
  }

  Future<void> saveCellLines(DateKey date, List<RichLine> lines) async {
    final settings = ref.read(settingsControllerProvider);
    var ordered = List<RichLine>.of(lines);
    if (settings.completeSort) {
      ordered = <RichLine>[
        ...ordered.where((RichLine l) => !l.completed),
        ...ordered.where((RichLine l) => l.completed),
      ];
    }
    await _repository.saveCell(
      _cellOf(date).withLines(ordered, occurredAt: _now),
    );
    await load();
  }

  Future<void> setCellBackgroundColor(DateKey date, EventColor color) async {
    await _repository.saveCell(_cellOf(date).withBackgroundColor(color, _now));
    await load();
  }

  Future<void> toggleLineCompleted(DateKey date, String lineId) async {
    final lines = _cellOf(date).lines.map((RichLine line) {
      if (line.id != lineId) return line;
      return line.copyWith(completed: !line.completed);
    }).toList();
    await saveCellLines(date, lines);
    await ref
        .read(soundGatewayProvider)
        .play(ref.read(settingsControllerProvider).taskCompleteTone);
  }

  Future<void> setLineColor(
    DateKey date,
    String lineId,
    EventColor color,
  ) async {
    final lines = _cellOf(date).lines
        .map(
          (RichLine line) =>
              line.id == lineId ? line.copyWith(color: color) : line,
        )
        .toList();
    await saveCellLines(date, lines);
  }

  Future<void> removeLine(DateKey date, String lineId) async {
    final lines = _cellOf(
      date,
    ).lines.where((RichLine line) => line.id != lineId).toList();
    await saveCellLines(date, lines);
  }

  /// 从单元格的一行文字创建事件，并把 eventId 回写到该行。
  Future<void> promoteLineToEvent(
    DateKey date,
    String lineId,
    CalendarEventType type, {
    RecurrenceRule recurrence = const RecurrenceRule(),
    ReminderSpec? reminder,
  }) async {
    final cell = _cellOf(date);
    RichLine? target;
    for (final line in cell.lines) {
      if (line.id == lineId) target = line;
    }
    if (target == null || target.text.trim().isEmpty) return;
    final event = await createEvent(
      content: target.text,
      startDate: date,
      type: type,
      color: target.color,
      recurrence: recurrence,
      reminder: reminder,
    );
    final lines = cell.lines
        .map(
          (RichLine line) =>
              line.id == lineId ? line.copyWith(eventId: event.id) : line,
        )
        .toList();
    await saveCellLines(date, lines);
  }

  Future<void> restoreCellFromText(DateKey date, String text) async {
    final lines = text
        .split('\n')
        .where((String line) => line.isNotEmpty)
        .map(
          (String line) =>
              RichLine(id: ref.read(idGeneratorProvider).next(), text: line),
        )
        .toList();
    await saveCellLines(date, lines);
  }
}

// ── 选中日 / 编辑面板 ─────────────────────────────────────────────────────

final selectedDateProvider = NotifierProvider<SelectedDateController, DateKey?>(
  SelectedDateController.new,
);

final class SelectedDateController extends Notifier<DateKey?> {
  @override
  DateKey? build() => null;

  void select(DateKey date) => state = date;

  void clear() => state = null;
}

// ── 导航状态 ───────────────────────────────────────────────────────────────

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

// ── 读模型 ─────────────────────────────────────────────────────────────────

final class EventOccurrence {
  const EventOccurrence(this.event, this.date);

  final CalendarEvent event;
  final DateKey date;

  bool get completed => event.isCompletedOn(date);
}

final class CalendarDayModel {
  const CalendarDayModel({
    required this.date,
    required this.meta,
    required this.cell,
    required this.events,
    required this.subscriptionEvents,
    required this.lessons,
    required this.countdowns,
    required this.isToday,
    required this.isCurrentMonth,
  });

  final DateKey date;
  final CalendarDayMeta meta;
  final DayCell? cell;
  final List<EventOccurrence> events;
  final List<SubscriptionEvent> subscriptionEvents;
  final List<Lesson> lessons;
  final List<CountdownItem> countdowns;
  final bool isToday;
  final bool isCurrentMonth;

  bool get isRestDay => meta.isRestDay || meta.isMakeupWorkday;
}

final class MonthData {
  const MonthData({
    required this.anchor,
    required this.weekdayHeaders,
    required this.columns,
    required this.countdownBar,
  });

  final DateTime anchor;
  final List<String> weekdayHeaders;
  final List<List<CalendarDayModel>> columns;
  final List<CountdownItem> countdownBar;
}

final monthDataProvider = Provider<MonthData>((Ref ref) {
  final settings = ref.watch(settingsControllerProvider);
  final calendar = ref.watch(calendarControllerProvider);
  final anchor = ref.watch(monthNavigationProvider);
  final countdowns = ref.watch(countdownControllerProvider).items;
  final subscriptions = ref.watch(subscriptionControllerProvider).items;
  final timetables = ref.watch(timetableControllerProvider).items;
  final today = DateKey.today(ref.watch(clockProvider).now());
  final l10n = ref.read(appLocalizationScopeProvider).localizations;

  final grids = CalendarMath.buildGrid(
    anchor: anchor,
    startOfWeek: settings.startOfWeek,
    rows: settings.maxRows,
    columns: settings.maxColumns,
    passedWeeks: settings.passedWeeks,
    singleLine: settings.displayMode.isSingleLine,
    today: today.date,
  );

  // 展开一次网格日期：后续 event / lesson / countdown 索引都复用它，
  // 避免对 42 个格子逐个做全量扫描（O(cells × N)）。
  final List<DateKey> allDays = grids.isEmpty || grids.first.isEmpty
      ? const <DateKey>[]
      : grids.expand((List<DateKey> c) => c).toList(growable: false);

  final eventMap = <DateKey, List<EventOccurrence>>{};
  if (allDays.isNotEmpty) {
    final sortedDays = List<DateKey>.of(allDays)
      ..sort((DateKey a, DateKey b) => a.key.compareTo(b.key));
    final range = DateRange(sortedDays.first, sortedDays.last);
    for (final event in calendar.events) {
      for (final date in RecurrencePolicy.occurrences(event, range)) {
        (eventMap.putIfAbsent(
          date,
          () => <EventOccurrence>[],
        )).add(EventOccurrence(event, date));
      }
    }
  }

  final subscriptionMap = <DateKey, List<SubscriptionEvent>>{};
  for (final subscription in subscriptions) {
    if (!subscription.enabled) continue;
    for (final item in subscription.events) {
      (subscriptionMap.putIfAbsent(
        item.date,
        () => <SubscriptionEvent>[],
      )).add(item);
    }
  }

  final cellMap = <DateKey, DayCell>{
    for (final cell in calendar.cells) cell.date: cell,
  };

  // 课程表与倒数日只按「可见日期」预计算一次：
  // 原实现每个格子都要重新解析课表 / 重新算 nextOccurrence（42 × N）。
  final uniqueDays = allDays.toSet();
  final lessonMap = <DateKey, List<Lesson>>{};
  for (final DateKey date in uniqueDays) {
    for (final Timetable timetable in timetables) {
      final List<Lesson> lessons = timetable.lessonsOn(date);
      if (lessons.isNotEmpty) {
        (lessonMap[date] ??= <Lesson>[]).addAll(lessons);
      }
    }
  }
  final countdownMap = <DateKey, List<CountdownItem>>{};
  for (final CountdownItem item in countdowns) {
    (countdownMap[item.nextOccurrence(today)] ??= <CountdownItem>[]).add(item);
  }

  final columns = grids.map((List<DateKey> days) {
    final month = days[days.length ~/ 2];
    return days.map((DateKey date) {
      return CalendarDayModel(
        date: date,
        meta: CalendarMath.metaOf(
          date,
          firstWeekOffset: settings.firstWeekOffset,
        ),
        cell: cellMap[date],
        events: eventMap[date] ?? const <EventOccurrence>[],
        subscriptionEvents:
            subscriptionMap[date] ?? const <SubscriptionEvent>[],
        lessons: lessonMap[date] ?? const <Lesson>[],
        countdowns: countdownMap[date] ?? const <CountdownItem>[],
        isToday: date == today,
        isCurrentMonth: date.month == month.month && date.year == month.year,
      );
    }).toList();
  }).toList();

  return MonthData(
    anchor: anchor,
    weekdayHeaders: List<String>.generate(
      7,
      (int index) =>
          weekdayShort((settings.startOfWeek - 1 + index) % 7 + 1, l10n),
    ),
    columns: columns,
    countdownBar:
        countdowns.where((CountdownItem c) => c.showType.onCalendar).toList()
          ..sort(
            (CountdownItem a, CountdownItem b) =>
                a.daysLeft(today).abs().compareTo(b.daysLeft(today).abs()),
          ),
  );
});
