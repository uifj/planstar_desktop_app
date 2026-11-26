/// 日历仓储的本地实现：复用 `core` 的 `JsonListStore` / `KeyValueStore`。
///
/// 持久化成功后才分发聚合上积攒的领域事件，避免「事件发了但事务没落盘」。
library;

import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';

import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../../core/result_x.dart';
import '../../../core/value_objects.dart';
import '../domain/calendar_event.dart';
import '../domain/day_cell.dart';
import '../domain/repositories.dart';

typedef _Json = Map<String, Object?>;

final class LocalCalendarRepository implements CalendarRepository {
  LocalCalendarRepository({
    required KeyValueStore store,
    required DomainEventBus bus,
    required Clock clock,
    required AppLogger logger,
  }) : _bus = bus,
       _clock = clock,
       _logger = logger,
       _events = JsonListStore<_Json>(
         store: store,
         key: _eventsKey,
         fromJson: (_Json json) => json,
         toJson: (_Json value) => value,
       ),
       _cells = JsonListStore<_Json>(
         store: store,
         key: _cellsKey,
         fromJson: (_Json json) => json,
         toJson: (_Json value) => value,
       );

  static const String _eventsKey = 'planstar.calendar.events.v1';
  static const String _cellsKey = 'planstar.calendar.cells.v1';

  final DomainEventBus _bus;
  final Clock _clock;
  final AppLogger _logger;
  final JsonListStore<_Json> _events;
  final JsonListStore<_Json> _cells;

  @override
  Future<Result<List<CalendarEvent>>> allEvents() async {
    final result = await guardAsync<List<_Json>>(() => _events.readAll());
    return result.map(
      (List<_Json> items) =>
          items.map(CalendarEvent.fromJson).toList(growable: false),
    );
  }

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
  Future<Result<void>> saveEvent(CalendarEvent event) async {
    final current = await guardAsync<List<_Json>>(() => _events.readAll());
    if (current case Fail<List<_Json>>(:final Failure failure)) {
      return Fail<void>(failure);
    }
    final items = current.requireData;
    final next = List<_Json>.of(items)
      ..removeWhere((_Json item) => item['id'] == event.id)
      ..add(event.toJson());
    return _persist(() => _events.writeAll(next), event.pullDomainEvents());
  }

  @override
  Future<Result<void>> deleteEvent(String id) async {
    final current = await guardAsync<List<_Json>>(() => _events.readAll());
    if (current case Fail<List<_Json>>(:final Failure failure)) {
      return Fail<void>(failure);
    }
    final next = List<_Json>.of(current.requireData)
      ..removeWhere((_Json item) => item['id'] == id);
    return _persist(() => _events.writeAll(next), <DomainEvent>[
      CalendarEventRemoved(aggregateId: id, occurredAt: _clock.now()),
    ]);
  }

  @override
  Future<Result<List<DayCell>>> allCells() async {
    final result = await guardAsync<List<_Json>>(() => _cells.readAll());
    return result.map(
      (List<_Json> items) =>
          items.map(DayCell.fromJson).toList(growable: false),
    );
  }

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
  Future<Result<void>> saveCell(DayCell cell) async {
    final current = await guardAsync<List<_Json>>(() => _cells.readAll());
    if (current case Fail<List<_Json>>(:final Failure failure)) {
      return Fail<void>(failure);
    }
    final next = List<_Json>.of(current.requireData)
      ..removeWhere((_Json item) => item['date'] == cell.date.key)
      ..add(cell.toJson());
    return _persist(() => _cells.writeAll(next), cell.pullDomainEvents());
  }

  @override
  Future<Result<void>> deleteCell(DateKey date) async {
    final current = await guardAsync<List<_Json>>(() => _cells.readAll());
    if (current case Fail<List<_Json>>(:final Failure failure)) {
      return Fail<void>(failure);
    }
    final next = List<_Json>.of(current.requireData)
      ..removeWhere((_Json item) => item['date'] == date.key);
    return _persist(() => _cells.writeAll(next), <DomainEvent>[
      DayCellChanged(
        aggregateId: date.key,
        occurredAt: _clock.now(),
        date: date,
        snapshot: '',
      ),
    ]);
  }

  @override
  Future<Result<void>> clear() async {
    final events = await guardAsync<void>(() => _events.clear());
    final cells = await guardAsync<void>(() => _cells.clear());
    return events.isFailure ? events : cells;
  }

  Future<Result<void>> _persist(
    Future<void> Function() write,
    List<DomainEvent> events,
  ) async {
    final written = await guardAsync<void>(write);
    return switch (written) {
      Fail<void>(:final Failure failure) => Fail<void>(failure),
      Success<void>() => await _dispatch(events),
    };
  }

  Future<Result<void>> _dispatch(List<DomainEvent> events) async {
    await _bus.dispatch(events);
    if (events.isNotEmpty) {
      _logger.debug('领域事件已分发：${events.length} 条');
    }
    return const Success<void>(null);
  }
}
