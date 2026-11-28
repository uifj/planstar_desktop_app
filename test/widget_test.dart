/// 领域层纯 Dart 单测：重复规则、提醒展开、设置序列化。
///
/// 这些测试不需要 Flutter engine / 插件通道，可直接 `flutter test` 运行。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/core/calendar_math.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/calendar/domain/calendar_event.dart';
import 'package:planstar_desktop_app/features/calendar/domain/recurrence.dart';
import 'package:planstar_desktop_app/features/calendar/domain/recurrence_policy.dart';
import 'package:planstar_desktop_app/features/calendar/domain/reminder_spec.dart';
import 'package:planstar_desktop_app/features/settings/domain/app_settings.dart';

void main() {
  final origin = DateKey(DateTime(2026, 11, 16));
  final occurredAt = DateTime(2026, 11, 16, 9);

  CalendarEvent build({
    RecurrenceRule recurrence = const RecurrenceRule(),
    List<DateKey> excluded = const <DateKey>[],
    DateKey? until,
  }) => CalendarEvent.create(
    id: 'evt-1',
    content: '写周报',
    startDate: origin,
    occurredAt: occurredAt,
    recurrence: recurrence,
    excludedDates: excluded,
    recurrenceUntil: until,
  );

  group('日期值对象', () {
    test('归一化时分秒并支持天数差', () {
      final a = DateKey(DateTime(2026, 11, 16, 23, 59));
      final b = DateKey(DateTime(2026, 11, 20));
      expect(a.key, '2026-11-16');
      expect(b.differenceInDays(a), 4);
      expect(a.addDays(7).key, '2026-11-23');
      expect(DateKey.parse('2026-11-16'), a);
    });

    test('网格以周起始日对齐', () {
      final grid = CalendarMath.buildGrid(
        anchor: DateTime(2026, 11, 1),
        startOfWeek: 1,
        rows: 6,
        columns: 1,
        passedWeeks: 0,
        singleLine: false,
        today: origin.date,
      );
      expect(grid.single.length, 42);
      expect(grid.single.first.weekday, 1);
    });
  });

  group('重复规则', () {
    test('不重复只在起始日发生', () {
      final event = build();
      expect(RecurrencePolicy.happensOn(event, origin), isTrue);
      expect(RecurrencePolicy.happensOn(event, origin.addDays(1)), isFalse);
    });

    test('每隔 2 天重复', () {
      final event = build(
        recurrence: const RecurrenceRule(
          kind: RecurrenceKind.daily,
          interval: 2,
        ),
      );
      final range = DateRange(origin, origin.addDays(8));
      final dates = RecurrencePolicy.occurrences(
        event,
        range,
      ).map((DateKey d) => d.key).toList();
      expect(dates, <String>[
        '2026-11-16',
        '2026-11-18',
        '2026-11-20',
        '2026-11-22',
        '2026-11-24',
      ]);
    });

    test('自定义周重复 + 例外 + 次数上限', () {
      final event = build(
        recurrence: const RecurrenceRule(
          kind: RecurrenceKind.customWeek,
          weekdays: <int>[1, 3],
          count: 3,
        ),
        excluded: <DateKey>[origin.addDays(2)],
      );
      final range = DateRange(origin, origin.addDays(14));
      expect(RecurrencePolicy.occurrences(event, range).length, 2);
    });

    test('仅删除当前 = 例外，删除当前及未来 = 截断', () {
      final event = build(
        recurrence: const RecurrenceRule(kind: RecurrenceKind.daily),
      );
      final excluded = event.exclude(origin.addDays(2), occurredAt);
      expect(RecurrencePolicy.happensOn(excluded, origin.addDays(2)), isFalse);
      final truncated = event.truncateBefore(origin.addDays(4), occurredAt);
      expect(RecurrencePolicy.happensOn(truncated, origin.addDays(5)), isFalse);
    });

    test('艾宾浩斯偏移固定为 1/2/4/7/15/30 天', () {
      final event = build(
        recurrence: const RecurrenceRule(kind: RecurrenceKind.ebbinghaus),
      );
      final range = DateRange(origin, origin.addDays(31));
      expect(RecurrencePolicy.occurrences(event, range), <DateKey>[
        origin,
        for (final offset in RecurrenceRule.ebbinghausOffsets)
          origin.addDays(offset),
      ]);
    });
  });

  group('提醒', () {
    test('多选提前量展开为具体触发时刻', () {
      const spec = ReminderSpec(
        hour: 9,
        minute: 30,
        advanceDays: <int>[0, 1, 7],
      );
      final fires = spec.fireTimesFor(origin);
      expect(fires.length, 3);
      expect(fires.first, DateTime(2026, 11, 9, 9, 30));
      expect(fires.last, DateTime(2026, 11, 16, 9, 30));
    });
  });

  group('设置', () {
    test('默认显示可编辑桌面组件，且不再自动画静态壁纸', () {
      expect(AppSettings.defaults.desktopWidgetEnabled, isTrue);
      expect(AppSettings.defaults.wallpaperAutoRender, isFalse);
      final legacy = AppSettings.fromJson(const <String, Object?>{});
      expect(legacy.desktopWidgetEnabled, isTrue);
      expect(legacy.wallpaperAutoRender, isFalse);
    });

    test('更新其他设置时保留无运行时行为的旧配置字段', () {
      final legacy = AppSettings.fromJson(const <String, Object?>{
        'showJiYi': true,
        'autoDelay': true,
      });
      final updated = legacy.copyWith(showLunar: false);
      expect(updated.showJiYi, isTrue);
      expect(updated.autoDelay, isTrue);
      expect(updated.toJson()['showJiYi'], isTrue);
      expect(updated.toJson()['autoDelay'], isTrue);
    });

    test('全量字段往返序列化保持一致', () {
      final settings = AppSettings.defaults.copyWith(
        maxRows: 4,
        showLunar: false,
        desktopWidgetEnabled: false,
        themeMode: AppThemeMode.dark,
        restDays: const <int>[5, 6],
        desktopEmbedded: true,
        wallpaperAutoRender: false,
        wallpaperImageDirectory: r'C:\wallpapers',
        wallpaperMode: WallpaperMode.rotation,
      );
      expect(AppSettings.fromJson(settings.toJson()), settings);
    });
  });
}
