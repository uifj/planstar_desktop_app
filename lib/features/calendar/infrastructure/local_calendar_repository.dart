/// 日历仓储的本地实现：两个 [JsonEntityStore]（事件 / 单元格）。
///
/// 「读改写 → 落盘成功后分发领域事件」统一走共享存储原语（ADR-0002b），
/// 本类只做聚合 ↔ JSON 的契约适配，不再自带第二套持久化 / 分发流程。
library;

import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';

import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/calendar_event.dart';
import '../domain/day_cell.dart';
import '../domain/repositories.dart';

/// 日历事件的持久化键。
const String calendarEventsStoreKey = 'planstar.calendar.events.v1';

/// 单元格（逐日清单）的持久化键。
const String calendarCellsStoreKey = 'planstar.calendar.cells.v1';

/// 日历的全部键共享一个重载分组（前缀注册）。
void registerCalendarReloadTargets(ReloadTargetRegistry registry) =>
    registry.registerPrefix('planstar.calendar.', 'calendar');

final class LocalCalendarRepository implements CalendarRepository {
  LocalCalendarRepository({
    required KeyValueStore store,
    required DomainEventBus bus,
    required Clock clock,
    required AppLogger logger,
  }) : _clock = clock,
       _events = JsonEntityStore<CalendarEvent>(
         store: store,
         key: calendarEventsStoreKey,
         bus: bus,
         clock: clock,
         fromJson: CalendarEvent.fromJson,
         toJson: (CalendarEvent e) => e.toJson(),
         idOf: (CalendarEvent e) => e.id,
         logger: logger,
       ),
       // 单元格以 date 字段为主键（toJson 里没有 id）。
       _cells = JsonEntityStore<DayCell>(
         store: store,
         key: calendarCellsStoreKey,
         bus: bus,
         clock: clock,
         fromJson: DayCell.fromJson,
         toJson: (DayCell c) => c.toJson(),
         idOf: (DayCell c) => c.date.key,
         idField: 'date',
         logger: logger,
       );

  final Clock _clock;
  final JsonEntityStore<CalendarEvent> _events;
  final JsonEntityStore<DayCell> _cells;

  @override
  Future<Result<List<CalendarEvent>>> allEvents() => _events.all();

  @override
  Future<Result<CalendarEvent?>> eventById(String id) async {
    final all = await allEvents();
    return all.map((List<CalendarEvent> items) {
      for (final event in items) {
        if (event.id == id) return event;
      }
      return null;
    });
  }

  @override
  Future<Result<void>> saveEvent(CalendarEvent event) =>
      _events.upsert(event, events: event.pullDomainEvents());

  @override
  Future<Result<void>> saveEvents(List<CalendarEvent> events) {
    if (events.isEmpty) return Future.value(const Success<void>(null));
    return _events.upsertAll(
      events,
      events: events
          .expand((CalendarEvent e) => e.pullDomainEvents())
          .toList(growable: false),
    );
  }

  @override
  Future<Result<void>> deleteEvent(String id) => _events.delete(
    id,
    events: <DomainEvent>[
      CalendarEventRemoved(aggregateId: id, occurredAt: _clock.now()),
    ],
  );

  @override
  Future<Result<List<DayCell>>> allCells() => _cells.all();

  @override
  Future<Result<DayCell?>> cellByDate(DateKey date) async {
    final all = await allCells();
    return all.map((List<DayCell> items) {
      for (final cell in items) {
        if (cell.date == date) return cell;
      }
      return null;
    });
  }

  @override
  Future<Result<void>> saveCell(DayCell cell) =>
      _cells.upsert(cell, events: cell.pullDomainEvents());

  @override
  Future<Result<void>> deleteCell(DateKey date) => _cells.delete(
    date.key,
    events: <DomainEvent>[
      DayCellChanged(
        aggregateId: date.key,
        occurredAt: _clock.now(),
        date: date,
        snapshot: '',
      ),
    ],
  );

  @override
  Future<Result<void>> clear() async {
    final events = await _events.deleteAll();
    final cells = await _cells.deleteAll();
    return events.isFailure ? events : cells;
  }
}
