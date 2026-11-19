/// ADR-0005 回归：TaskCompleted 显式领域事件 + SoundReaction 反应器。
///
/// 覆盖：完成转变才发事件、反应器按设置音色播放、tone=none 不播、
/// 落盘失败不发声、命令不再直接碰音频网关、跨 engine 重载不触发发声。
library;

import 'dart:convert';

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
import 'package:planstar_desktop_app/features/calendar/application/sound_reaction.dart';
import 'package:planstar_desktop_app/features/calendar/domain/calendar_event.dart';
import 'package:planstar_desktop_app/features/calendar/domain/day_cell.dart';
import 'package:planstar_desktop_app/features/settings/application/settings_controller.dart';

final class _FakeSound implements SoundGateway {
  final List<SoundTone> played = <SoundTone>[];

  @override
  Future<void> play(SoundTone tone) async {
    played.add(tone);
  }
}

final class _FixedClock implements Clock {
  const _FixedClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant;
}

final class _FailableStore implements KeyValueStore {
  final MemoryKeyValueStore _inner = MemoryKeyValueStore();
  bool failWrites = false;

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('磁盘满了');
    await _inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> clear() => _inner.clear();

  @override
  Future<Set<String>> keys() => _inner.keys();
}

void main() {
  final now = DateTime(2026, 11, 18, 9);
  final date = DateKey(now);

  group('聚合只在「未完成 → 完成」转变时发 TaskCompleted', () {
    test('事件 markCompleted 完成转变发事件，携带日期与来源', () {
      final event = CalendarEvent.create(
        id: 'e1',
        content: '写周报',
        startDate: date,
        occurredAt: now,
      );
      event.pullDomainEvents();
      final next = event.markCompleted(date, true, now);
      final events = next.pullDomainEvents();
      final completed = events.whereType<TaskCompleted>().toList();
      expect(completed, hasLength(1));
      expect(completed.single.date, date);
      expect(completed.single.source, TaskCompletionSource.event);
      expect(completed.single.aggregateId, 'e1');
    });

    test('事件已完成再标记完成（幂等）不发 TaskCompleted', () {
      final event = CalendarEvent.create(
        id: 'e1',
        content: '写周报',
        startDate: date,
        occurredAt: now,
      ).markCompleted(date, true, now);
      event.pullDomainEvents();
      final next = event.markCompleted(date, true, now);
      expect(next.pullDomainEvents().whereType<TaskCompleted>(), isEmpty);
    });

    test('事件取消完成不发 TaskCompleted', () {
      final event = CalendarEvent.create(
        id: 'e1',
        content: '写周报',
        startDate: date,
        occurredAt: now,
      ).markCompleted(date, true, now);
      event.pullDomainEvents();
      final next = event.markCompleted(date, false, now);
      expect(next.pullDomainEvents().whereType<TaskCompleted>(), isEmpty);
    });

    test('清单行未完成 → 完成发 TaskCompleted（来源 cellLine）', () {
      final cell = DayCell.create(date, now).withLines(<RichLine>[
        const RichLine(id: 'l1', text: '买菜'),
      ], occurredAt: now);
      cell.pullDomainEvents();
      final next = cell.withLines(<RichLine>[
        const RichLine(id: 'l1', text: '买菜', completed: true),
      ], occurredAt: now);
      final completed = next.pullDomainEvents().whereType<TaskCompleted>();
      expect(completed, hasLength(1));
      expect(completed.single.source, TaskCompletionSource.cellLine);
      expect(completed.single.date, date);
    });

    test('仅改颜色 / 删除行 / 新增已完成行都不发 TaskCompleted', () {
      final cell = DayCell.create(date, now).withLines(<RichLine>[
        const RichLine(id: 'l1', text: '买菜'),
      ], occurredAt: now);
      cell.pullDomainEvents();
      final recolored = cell.withLines(<RichLine>[
        const RichLine(id: 'l1', text: '买菜', color: EventColor(0xFFFF0000)),
      ], occurredAt: now);
      expect(recolored.pullDomainEvents().whereType<TaskCompleted>(), isEmpty);
      final removed = cell.withLines(const <RichLine>[], occurredAt: now);
      expect(removed.pullDomainEvents().whereType<TaskCompleted>(), isEmpty);
      final added = cell.withLines(<RichLine>[
        const RichLine(id: 'l1', text: '买菜'),
        const RichLine(id: 'l2', text: '新增即完成', completed: true),
      ], occurredAt: now);
      expect(added.pullDomainEvents().whereType<TaskCompleted>(), isEmpty);
    });
  });

  group('SoundReaction 反应器', () {
    test('TaskCompleted 按设置音色播放；none 不播', () async {
      final bus = DomainEventBus();
      final sound = _FakeSound();
      var tone = SoundTone.ding2;
      final reaction = SoundReaction(
        bus: bus,
        sound: sound,
        toneOf: () => tone,
      );
      reaction.start();
      await bus.dispatch(<DomainEvent>[
        TaskCompleted(
          aggregateId: 'e1',
          occurredAt: now,
          date: date,
          source: TaskCompletionSource.event,
        ),
      ]);
      expect(sound.played, <SoundTone>[SoundTone.ding2]);
      tone = SoundTone.none;
      await bus.dispatch(<DomainEvent>[
        TaskCompleted(
          aggregateId: 'e2',
          occurredAt: now,
          date: date,
          source: TaskCompletionSource.cellLine,
        ),
      ]);
      expect(sound.played, hasLength(1));
      reaction.stop();
    });

    test('跨 engine 重载事件不触发发声（不变量）', () async {
      final bus = DomainEventBus();
      final sound = _FakeSound();
      final reaction = SoundReaction(
        bus: bus,
        sound: sound,
        toneOf: () => SoundTone.ding,
      );
      reaction.start();
      await bus.dispatch(<DomainEvent>[
        CrossEngineDataChanged(
          aggregateId: 'planstar.calendar.cells.v1',
          occurredAt: now,
          key: 'planstar.calendar.cells.v1',
          revision: 2,
        ),
      ]);
      expect(sound.played, isEmpty);
      reaction.stop();
    });

    test('stop 后不再发声', () async {
      final bus = DomainEventBus();
      final sound = _FakeSound();
      final reaction = SoundReaction(
        bus: bus,
        sound: sound,
        toneOf: () => SoundTone.ding,
      );
      reaction.start();
      reaction.stop();
      await bus.dispatch(<DomainEvent>[
        TaskCompleted(
          aggregateId: 'e1',
          occurredAt: now,
          date: date,
          source: TaskCompletionSource.event,
        ),
      ]);
      expect(sound.played, isEmpty);
    });
  });

  group('命令与反应器集成（Provider 链）', () {
    late _FailableStore store;
    late DomainEventBus bus;
    late _FakeSound sound;
    late ProviderContainer container;

    setUp(() {
      store = _FailableStore();
      bus = DomainEventBus();
      sound = _FakeSound();
      container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          domainEventBusProvider.overrideWithValue(bus),
          clockProvider.overrideWithValue(_FixedClock(now)),
          soundGatewayProvider.overrideWithValue(sound),
          loggerProvider.overrideWithValue(
            AppLogger(sinks: <LogSink>[SilentLogSink()], level: LogLevel.debug),
          ),
        ],
      );
      // 对齐应用根接线：PlanstarApp.build 首帧即 watch 设置控制器，
      // 用户交互前设置必然已加载；测试容器需显式触发同一初始化。
      container.read(settingsControllerProvider);
    });

    tearDown(() => container.dispose());

    Future<void> pump() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('注册反应器后勾选事件发声一次，且命令本身不直接播放', () async {
      container.read(soundReactionProvider);
      await pump();
      final controller = container.read(calendarControllerProvider.notifier);
      final event = CalendarEvent.create(
        id: 'e1',
        content: '写周报',
        startDate: date,
        occurredAt: now,
      );
      await controller.toggleEventCompleted(event, date);
      expect(sound.played, <SoundTone>[SoundTone.ding]);
      expect(
        container
            .read(calendarControllerProvider)
            .events
            .single
            .isCompletedOn(date),
        isTrue,
      );
    });

    test('未注册反应器时命令不触碰音频网关（解耦回归）', () async {
      await pump();
      final controller = container.read(calendarControllerProvider.notifier);
      final event = CalendarEvent.create(
        id: 'e1',
        content: '写周报',
        startDate: date,
        occurredAt: now,
      );
      await controller.toggleEventCompleted(event, date);
      await controller.toggleLineCompleted(date, 'missing-line');
      expect(sound.played, isEmpty);
    });

    test('勾选清单行经反应器发声一次', () async {
      container.read(soundReactionProvider);
      await pump();
      final controller = container.read(calendarControllerProvider.notifier);
      await controller.saveCellLines(date, <RichLine>[
        const RichLine(id: 'l1', text: '买菜'),
      ]);
      sound.played.clear();
      await controller.toggleLineCompleted(date, 'l1');
      expect(sound.played, <SoundTone>[SoundTone.ding]);
    });

    test('落盘失败不分发事件也不发声', () async {
      container.read(soundReactionProvider);
      await pump();
      final controller = container.read(calendarControllerProvider.notifier);
      store.failWrites = true;
      final event = CalendarEvent.create(
        id: 'e1',
        content: '写周报',
        startDate: date,
        occurredAt: now,
      );
      await controller.toggleEventCompleted(event, date);
      expect(sound.played, isEmpty);
      expect(container.read(calendarControllerProvider).events, isEmpty);
    });

    test('设置 taskCompleteTone=none 时勾选不发声', () async {
      await store.write(
        'planstar.settings.v1',
        jsonEncode(<String, Object?>{'taskCompleteTone': 'none'}),
      );
      // setUp 已按应用根接线初始化过设置（空存储→默认值），
      // 种子落盘后需重载才能生效，与跨 engine 重载路径一致。
      await container.read(settingsControllerProvider.notifier).load();
      container.read(soundReactionProvider);
      await pump();
      final controller = container.read(calendarControllerProvider.notifier);
      final event = CalendarEvent.create(
        id: 'e1',
        content: '写周报',
        startDate: date,
        occurredAt: now,
      );
      await controller.toggleEventCompleted(event, date);
      expect(sound.played, isEmpty);
    });
  });
}
