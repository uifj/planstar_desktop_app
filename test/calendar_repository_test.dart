/// ADR-0002a 回归：批量写一次落盘、先落盘后分发、autoDelay 批量化。
library;

import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/app_events.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/calendar/application/calendar_controller.dart';
import 'package:planstar_desktop_app/features/calendar/domain/calendar_event.dart';
import 'package:planstar_desktop_app/features/calendar/infrastructure/local_calendar_repository.dart';

final class _CountingStore implements KeyValueStore {
  _CountingStore();

  final MemoryKeyValueStore _inner = MemoryKeyValueStore();
  final Map<String, int> writeCounts = <String, int>{};
  final Map<String, int> readCounts = <String, int>{};
  final List<String> journal = <String>[];
  bool failWrites = false;

  void resetCounts() {
    writeCounts.clear();
    readCounts.clear();
  }

  @override
  Future<String?> read(String key) {
    readCounts[key] = (readCounts[key] ?? 0) + 1;
    return _inner.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('磁盘满了');
    writeCounts[key] = (writeCounts[key] ?? 0) + 1;
    journal.add('write:$key');
    await _inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> clear() => _inner.clear();

  @override
  Future<Set<String>> keys() => _inner.keys();
}

final class _FixedClock implements Clock {
  const _FixedClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant;
}

final class _SilentSound implements SoundGateway {
  @override
  Future<void> play(SoundTone tone) async {}
}

void main() {
  final now = DateTime(2026, 11, 18, 9);
  final today = DateKey(now);

  CalendarEvent event(
    String id, {
    DateKey? startDate,
    List<DateKey> completed = const <DateKey>[],
  }) => CalendarEvent.create(
    id: id,
    content: '任务$id',
    startDate: startDate ?? today.addDays(-8),
    occurredAt: now,
    completedDates: completed,
  );

  group('LocalCalendarRepository.saveEvents 批量写', () {
    test('多个事件一次落盘', () async {
      final store = _CountingStore();
      final repo = LocalCalendarRepository(
        store: store,
        bus: DomainEventBus(),
        clock: _FixedClock(now),
        logger: AppLogger(
          sinks: <LogSink>[SilentLogSink()],
          level: LogLevel.debug,
        ),
      );
      final result = await repo.saveEvents(<CalendarEvent>[
        event('a'),
        event('b'),
        event('c'),
      ]);
      expect(result.isSuccess, isTrue);
      expect(store.writeCounts['planstar.calendar.events.v1'], 1);
      expect((await repo.allEvents()).requireData, hasLength(3));
    });

    test('同 id 覆盖旧值，其余保留', () async {
      final store = _CountingStore();
      final repo = LocalCalendarRepository(
        store: store,
        bus: DomainEventBus(),
        clock: _FixedClock(now),
        logger: AppLogger(
          sinks: <LogSink>[SilentLogSink()],
          level: LogLevel.debug,
        ),
      );
      await repo.saveEvent(event('a'));
      store.resetCounts();
      final updated = event('a').changed(content: '改过了', occurredAt: now);
      await repo.saveEvents(<CalendarEvent>[updated, event('b')]);
      expect(store.writeCounts['planstar.calendar.events.v1'], 1);
      final all = (await repo.allEvents()).requireData;
      expect(all, hasLength(2));
      expect(all.firstWhere((CalendarEvent e) => e.id == 'a').content, '改过了');
    });

    test('先落盘后分发；写失败不分发', () async {
      final store = _CountingStore();
      final bus = DomainEventBus();
      bus.on<CalendarEventCreated>(
        (CalendarEventCreated e) =>
            store.journal.add('dispatch:${e.aggregateId}'),
      );
      final repo = LocalCalendarRepository(
        store: store,
        bus: bus,
        clock: _FixedClock(now),
        logger: AppLogger(
          sinks: <LogSink>[SilentLogSink()],
          level: LogLevel.debug,
        ),
      );
      await repo.saveEvents(<CalendarEvent>[event('a'), event('b')]);
      expect(store.journal, <String>[
        'write:planstar.calendar.events.v1',
        'dispatch:a',
        'dispatch:b',
      ]);

      store.journal.clear();
      store.failWrites = true;
      final failed = await repo.saveEvents(<CalendarEvent>[event('c')]);
      expect(failed.isFailure, isTrue);
      expect(store.journal, isEmpty);
    });

    test('空列表零开销', () async {
      final store = _CountingStore();
      final repo = LocalCalendarRepository(
        store: store,
        bus: DomainEventBus(),
        clock: _FixedClock(now),
        logger: AppLogger(
          sinks: <LogSink>[SilentLogSink()],
          level: LogLevel.debug,
        ),
      );
      final result = await repo.saveEvents(<CalendarEvent>[]);
      expect(result.isSuccess, isTrue);
      expect(store.writeCounts, isEmpty);
    });
  });

  group('CalendarController.autoDelayUncompleted 批量化', () {
    test('多个待顺延事件只写一次，且只顺延该顺延的', () async {
      final store = _CountingStore();
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          domainEventBusProvider.overrideWithValue(DomainEventBus()),
          clockProvider.overrideWithValue(_FixedClock(now)),
          soundGatewayProvider.overrideWithValue(_SilentSound()),
          loggerProvider.overrideWithValue(
            AppLogger(sinks: <LogSink>[SilentLogSink()], level: LogLevel.debug),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(calendarControllerProvider.notifier);
      await controller.load();

      await controller.createEvent(
        content: '过期1',
        startDate: today.addDays(-8),
      );
      await controller.createEvent(
        content: '过期2',
        startDate: today.addDays(-5),
      );
      await controller.createEvent(
        content: '已完成',
        startDate: today.addDays(-6),
      );
      // 把「已完成」标记完成。
      final completed = container
          .read(calendarControllerProvider)
          .events
          .firstWhere((CalendarEvent e) => e.content == '已完成');
      await controller.toggleEventCompleted(completed, completed.startDate);
      await controller.createEvent(content: '未来', startDate: today.addDays(2));

      store.resetCounts();
      await controller.autoDelayUncompleted(today);
      expect(
        store.writeCounts['planstar.calendar.events.v1'],
        1,
        reason: '两个待顺延事件应合并为一次批量落盘',
      );

      final events = container.read(calendarControllerProvider).events;
      expect(
        events.firstWhere((CalendarEvent e) => e.content == '过期1').startDate,
        today,
      );
      expect(
        events.firstWhere((CalendarEvent e) => e.content == '过期2').startDate,
        today,
      );
      expect(
        events.firstWhere((CalendarEvent e) => e.content == '已完成').startDate,
        today.addDays(-6),
      );
      expect(
        events.firstWhere((CalendarEvent e) => e.content == '未来').startDate,
        today.addDays(2),
      );
    });
  });

  group('CalendarController 增量更新（ADR-0002b）', () {
    ProviderContainer container(_CountingStore store) {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          domainEventBusProvider.overrideWithValue(DomainEventBus()),
          clockProvider.overrideWithValue(_FixedClock(now)),
          soundGatewayProvider.overrideWithValue(_SilentSound()),
          loggerProvider.overrideWithValue(
            AppLogger(sinks: <LogSink>[SilentLogSink()], level: LogLevel.debug),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('createEvent 乐观更新状态，不重读单元格存储', () async {
      final store = _CountingStore();
      final c = container(store);
      final controller = c.read(calendarControllerProvider.notifier);
      await controller.load();
      final cellsReadsBefore = store.readCounts[calendarCellsStoreKey] ?? 0;

      await controller.createEvent(content: '新任务', startDate: today);

      expect(
        c
            .read(calendarControllerProvider)
            .events
            .map((CalendarEvent e) => e.content),
        contains('新任务'),
      );
      expect(
        store.readCounts[calendarCellsStoreKey] ?? 0,
        cellsReadsBefore,
        reason: '写成功应乐观更新，不再全量 load 重读两个列表',
      );
    });

    test('saveCellLines 成功后 cells 按日期直接可查', () async {
      final store = _CountingStore();
      final c = container(store);
      final controller = c.read(calendarControllerProvider.notifier);
      await controller.load();

      await controller.saveCellLines(today, <RichLine>[
        RichLine(id: 'l1', text: '一行'),
      ]);

      final cell = c.read(calendarControllerProvider).cells[today];
      expect(cell?.lines.single.text, '一行');
    });

    test('写失败不更新状态', () async {
      final store = _CountingStore();
      final c = container(store);
      final controller = c.read(calendarControllerProvider.notifier);
      await controller.load();
      store.failWrites = true;

      await controller.createEvent(content: '落盘失败', startDate: today);

      expect(
        c
            .read(calendarControllerProvider)
            .events
            .map((CalendarEvent e) => e.content),
        isNot(contains('落盘失败')),
      );
    });
  });
}
