/// 日历写侧应用服务：事件 / 单元格命令与 Riverpod 状态。
///
/// 数据流：仓储（Result）→ CalendarController（写侧状态）→
/// 读模型（presentation/calendar_providers.dart）→ 月历组件。
/// 写成功乐观更新状态（ADR-0002b），全量 load 只留给初次与跨 engine 广播；
/// 领域事件由仓储在落盘成功后分发，提醒 / 历史 / 同步各自订阅。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/calendar_event.dart';
import '../domain/day_cell.dart';
import '../domain/recurrence.dart';
import '../domain/reminder_spec.dart';
import '../domain/repositories.dart';
import '../infrastructure/local_calendar_repository.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (Ref ref) => LocalCalendarRepository(
    store: ref.watch(keyValueStoreProvider),
    bus: ref.watch(domainEventBusProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  ),
);

final class CalendarState {
  const CalendarState({
    this.events = const <CalendarEvent>[],
    this.cells = const <DateKey, DayCell>{},
    this.loading = true,
    this.error,
  });

  final List<CalendarEvent> events;
  final Map<DateKey, DayCell> cells;
  final bool loading;
  final String? error;

  // 哨兵区分「未传」与「显式传 null」，copyWith(error: null) 即清除错误。
  static const Object _errorUnset = Object();

  CalendarState copyWith({
    List<CalendarEvent>? events,
    Map<DateKey, DayCell>? cells,
    bool? loading,
    Object? error = _errorUnset,
  }) => CalendarState(
    events: events ?? this.events,
    cells: cells ?? this.cells,
    loading: loading ?? this.loading,
    error: identical(error, _errorUnset) ? this.error : error as String?,
  );
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

final class CalendarController extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    Future.microtask(load);
    return const CalendarState();
  }

  CalendarRepository get _repository => ref.read(calendarRepositoryProvider);

  DateTime get _now => ref.read(clockProvider).now();

  Future<void> load() async {
    final events = await _repository.allEvents();
    final cells = await _repository.allCells();
    if (events case Fail<List<CalendarEvent>>(:final Failure failure)) {
      state = state.copyWith(loading: false, error: failure.message);
      return;
    }
    if (cells case Fail<List<DayCell>>(:final Failure failure)) {
      state = state.copyWith(loading: false, error: failure.message);
      return;
    }
    state = state.copyWith(
      events: events.requireData,
      cells: <DateKey, DayCell>{
        for (final cell in cells.requireData) cell.date: cell,
      },
      loading: false,
      error: null,
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
    await _saveEvent(event);
    return event;
  }

  Future<void> saveEvent(CalendarEvent event) => _saveEvent(event);

  /// 重复事件删除三态：current=记例外、future=截断、all=物理删除。
  Future<void> deleteEvent(
    CalendarEvent event, {
    required DateKey onDate,
    required DeleteScope scope,
  }) async {
    switch (scope) {
      case DeleteScope.current:
        if (!event.recurrence.isRecurring) {
          await _removeEvent(event.id);
        } else {
          await _saveEvent(event.exclude(onDate, _now));
        }
      case DeleteScope.currentAndFuture:
        if (!event.recurrence.isRecurring) {
          await _removeEvent(event.id);
        } else {
          await _saveEvent(event.truncateBefore(onDate, _now));
        }
      case DeleteScope.all:
        await _removeEvent(event.id);
    }
  }

  Future<void> toggleEventCompleted(CalendarEvent event, DateKey date) async {
    final next = event.markCompleted(date, !event.isCompletedOn(date), _now);
    await _saveEvent(next);
  }

  /// 未完成任务 30 天内自动顺延（旧版 `AutoDelay` / VIP）。
  Future<void> autoDelayUncompleted(DateKey today) async {
    final cutoff = today.addDays(-30);
    final delayed = <CalendarEvent>[
      for (final event in state.events)
        if (!event.recurrence.isRecurring &&
            event.startDate.differenceInDays(cutoff) >= 0 &&
            event.startDate.differenceInDays(today) <= 0 &&
            !event.completedDates.contains(event.startDate))
          event.changed(startDate: today, occurredAt: _now),
    ];
    if (delayed.isEmpty) return;
    final result = await _repository.saveEvents(delayed);
    if (result case Success<void>()) {
      final byId = <String, CalendarEvent>{
        for (final event in delayed) event.id: event,
      };
      state = state.copyWith(
        events: <CalendarEvent>[
          for (final event in state.events) byId[event.id] ?? event,
        ],
      );
    }
  }

  // ── 单元格编辑 ──────────────────────────────────────────────────────────

  DayCell _cellOf(DateKey date) =>
      state.cells[date] ?? DayCell.create(date, _now);

  Future<void> saveCellLines(DateKey date, List<RichLine> lines) async {
    final settings = ref.read(settingsControllerProvider);
    var ordered = List<RichLine>.of(lines);
    if (settings.completeSort) {
      ordered = <RichLine>[
        ...ordered.where((RichLine l) => !l.completed),
        ...ordered.where((RichLine l) => l.completed),
      ];
    }
    await _saveCell(_cellOf(date).withLines(ordered, occurredAt: _now));
  }

  Future<void> setCellBackgroundColor(DateKey date, EventColor color) async {
    await _saveCell(_cellOf(date).withBackgroundColor(color, _now));
  }

  Future<void> toggleLineCompleted(DateKey date, String lineId) async {
    final lines = _cellOf(date).lines.map((RichLine line) {
      if (line.id != lineId) return line;
      return line.copyWith(completed: !line.completed);
    }).toList();
    await saveCellLines(date, lines);
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
    final lines = _cellOf(date).lines
        .where((RichLine line) => line.id != lineId)
        .toList();
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

  // ── 乐观更新：写成功才改状态，失败保持原样（ADR-0002b）─────────────────

  Future<void> _saveEvent(CalendarEvent event) async {
    final result = await _repository.saveEvent(event);
    if (result case Success<void>()) {
      state = state.copyWith(
        events: <CalendarEvent>[
          ...state.events.where((CalendarEvent e) => e.id != event.id),
          event,
        ],
      );
    }
  }

  Future<void> _removeEvent(String id) async {
    final result = await _repository.deleteEvent(id);
    if (result case Success<void>()) {
      state = state.copyWith(
        events: state.events
            .where((CalendarEvent e) => e.id != id)
            .toList(growable: false),
      );
    }
  }

  Future<void> _saveCell(DayCell cell) async {
    final result = await _repository.saveCell(cell);
    if (result case Success<void>()) {
      state = state.copyWith(
        cells: <DateKey, DayCell>{...state.cells, cell.date: cell},
      );
    }
  }
}
