/// ADR-0001 对拍契约：同一事件同一区间，
/// `occurrences` 结果集 == 逐日 `happensOn` 结果集。
///
/// count 约束用例在 happensOn 补齐前必然红（红因即根因）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/calendar/domain/calendar_event.dart';
import 'package:planstar_desktop_app/features/calendar/domain/recurrence.dart';
import 'package:planstar_desktop_app/features/calendar/domain/recurrence_policy.dart';

void main() {
  CalendarEvent build({
    required DateKey start,
    RecurrenceRule recurrence = const RecurrenceRule(),
    List<DateKey> excluded = const <DateKey>[],
    DateKey? until,
  }) => CalendarEvent.create(
    id: 'parity-1',
    content: '对拍事件',
    startDate: start,
    occurredAt: start.date,
    recurrence: recurrence,
    excludedDates: excluded,
    recurrenceUntil: until,
  );

  void expectParity(CalendarEvent event, DateRange range) {
    final expanded = RecurrencePolicy.occurrences(
      event,
      range,
    ).map((DateKey d) => d.key).toSet();
    final scanned = <String>{};
    for (
      var cursor = range.start;
      cursor.differenceInDays(range.end) <= 0;
      cursor = cursor.addDays(1)
    ) {
      if (RecurrencePolicy.happensOn(event, cursor)) {
        scanned.add(cursor.key);
      }
    }
    expect(scanned, expanded, reason: '区间 $range 内两种判定必须一致');
  }

  group('occurrences × happensOn 对拍', () {
    final origin = DateKey(DateTime(2026, 11, 16));

    test('daily + count：区间覆盖起点', () {
      final event = build(
        start: origin,
        recurrence: const RecurrenceRule(kind: RecurrenceKind.daily, count: 3),
      );
      expectParity(event, DateRange(origin, origin.addDays(10)));
    });

    test('daily + count：count 在可见区间之前耗尽（历史事件）', () {
      final event = build(
        start: DateKey(DateTime(2023, 1, 1)),
        recurrence: const RecurrenceRule(kind: RecurrenceKind.daily, count: 5),
      );
      expectParity(event, DateRange(origin, origin.addDays(41)));
    });

    test('customWeek + count + 例外', () {
      final event = build(
        start: origin,
        recurrence: const RecurrenceRule(
          kind: RecurrenceKind.customWeek,
          weekdays: <int>[1, 3],
          count: 3,
        ),
        excluded: <DateKey>[origin.addDays(2)],
      );
      expectParity(event, DateRange(origin, origin.addDays(14)));
    });

    test('count 把例外日也计入次数（与 occurrences 语义一致）', () {
      final event = build(
        start: origin,
        recurrence: const RecurrenceRule(kind: RecurrenceKind.daily, count: 2),
        excluded: <DateKey>[origin.addDays(1)],
      );
      expectParity(event, DateRange(origin, origin.addDays(6)));
    });

    test('until 截断', () {
      final event = build(
        start: origin,
        recurrence: const RecurrenceRule(kind: RecurrenceKind.daily),
        until: origin.addDays(3),
      );
      expectParity(event, DateRange(origin, origin.addDays(10)));
    });

    test('lunarYearly 跨年', () {
      final event = build(
        start: DateKey(DateTime(2024, 2, 10)),
        recurrence: const RecurrenceRule(kind: RecurrenceKind.lunarYearly),
      );
      expectParity(
        event,
        DateRange(
          DateKey(DateTime(2026, 1, 1)),
          DateKey(DateTime(2026, 12, 31)),
        ),
      );
    });

    test('lunarYearly + count', () {
      final event = build(
        start: DateKey(DateTime(2024, 2, 10)),
        recurrence: const RecurrenceRule(
          kind: RecurrenceKind.lunarYearly,
          count: 2,
        ),
      );
      expectParity(
        event,
        DateRange(
          DateKey(DateTime(2025, 1, 1)),
          DateKey(DateTime(2027, 12, 31)),
        ),
      );
    });

    test('legalWorkday 整月', () {
      final event = build(
        start: DateKey(DateTime(2026, 10, 1)),
        recurrence: const RecurrenceRule(kind: RecurrenceKind.legalWorkday),
      );
      expectParity(
        event,
        DateRange(
          DateKey(DateTime(2026, 11, 1)),
          DateKey(DateTime(2026, 11, 30)),
        ),
      );
    });

    test('其余规则抽样（monthly/yearly/ebbinghaus/workday/weekly）', () {
      final kinds = <RecurrenceRule>[
        const RecurrenceRule(kind: RecurrenceKind.monthly),
        const RecurrenceRule(kind: RecurrenceKind.yearly),
        const RecurrenceRule(kind: RecurrenceKind.ebbinghaus),
        const RecurrenceRule(kind: RecurrenceKind.workday, interval: 2),
        const RecurrenceRule(kind: RecurrenceKind.weekly, interval: 2),
        const RecurrenceRule(kind: RecurrenceKind.monthLastDay),
        const RecurrenceRule(
          kind: RecurrenceKind.customMonthDay,
          monthDays: <int>[1, 15],
        ),
        const RecurrenceRule(kind: RecurrenceKind.customYear),
      ];
      for (final rule in kinds) {
        final event = build(
          start: DateKey(DateTime(2025, 1, 31)),
          recurrence: rule,
        );
        expectParity(
          event,
          DateRange(
            DateKey(DateTime(2026, 1, 1)),
            DateKey(DateTime(2026, 12, 31)),
          ),
        );
      }
    });

    test('expansionOf 上下文与静态 happensOn 判定一致', () {
      final event = build(
        start: origin,
        recurrence: const RecurrenceRule(kind: RecurrenceKind.daily, count: 3),
      );
      final expansion = RecurrencePolicy.expansionOf(event);
      for (var i = 0; i < 10; i++) {
        final date = origin.addDays(i);
        expect(
          expansion.happensOn(date),
          RecurrencePolicy.happensOn(event, date),
          reason: '第 $i 天两种入口必须一致',
        );
      }
      expect(expansion.happensOn(origin.addDays(2)), isTrue);
      expect(expansion.happensOn(origin.addDays(3)), isFalse);
    });
  });
}
