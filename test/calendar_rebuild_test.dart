/// ADR-0006 回归：读模型值相等 + 单日变更的重建隔离。
///
/// 步骤1：CalendarDayModel / EventOccurrence / MonthData / VisibleDays 及其
/// 嵌套值类型（TimelineTag / TimelineBarEntry / CalendarDayMeta）按属性相等。
/// 步骤3：dayModelProvider family 在任一日历变化时重算，但值相等保证只有内容
/// 变化的日期通知 watcher——Provider 通知数与 ConsumerWidget 重建数 1:1，
/// 故「其余 DayCellWidget build 计数不增」以脏标记计数直接验证。
library;

import 'package:core/config.dart';
import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/network.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/calendar_math.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/calendar/domain/calendar_event.dart';
import 'package:planstar_desktop_app/features/calendar/application/calendar_controller.dart';
import 'package:planstar_desktop_app/features/calendar/presentation/calendar_providers.dart';
import 'package:planstar_desktop_app/features/calendar/presentation/read_model/month_data.dart';
import 'package:planstar_desktop_app/features/calendar/presentation/widgets/day_cell_widget.dart';
import 'package:planstar_desktop_app/features/calendar/presentation/widgets/month_grid.dart';

final class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 11, 18, 9);
}

final class _Sound implements SoundGateway {
  @override
  Future<void> play(SoundTone tone) async {}
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    domainEventBusProvider.overrideWithValue(DomainEventBus()),
    clockProvider.overrideWithValue(_Clock()),
    soundGatewayProvider.overrideWithValue(_Sound()),
    appConfigProvider.overrideWithValue(AppConfig.empty),
    apiClientProvider.overrideWithValue(
      ApiClient(buildDio(baseUrl: 'https://unit.test/')),
    ),
    loggerProvider.overrideWithValue(
      AppLogger(sinks: <LogSink>[SilentLogSink()], level: LogLevel.debug),
    ),
  ],
);

Future<void> _settleLoad() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('值相等（ADR-0006 步骤1）', () {
    final date = DateKey(DateTime(2026, 11, 18));
    final meta = CalendarDayMeta(
      date: date,
      lunarLabel: '初一',
      solarTerm: '',
      festivals: const <String>[],
      isRestDay: false,
      isMakeupWorkday: false,
      weekNumber: 47,
    );

    test('TimelineTag / TimelineBarEntry 同内容两实例相等', () {
      expect(
        const TimelineTag(kind: TimelineTagKind.lesson, text: '高数'),
        const TimelineTag(kind: TimelineTagKind.lesson, text: '高数'),
      );
      expect(
        const TimelineTag(kind: TimelineTagKind.lesson, text: '高数').hashCode,
        const TimelineTag(kind: TimelineTagKind.lesson, text: '高数').hashCode,
      );
      expect(
        const TimelineTag(kind: TimelineTagKind.lesson, text: '高数'),
        isNot(const TimelineTag(kind: TimelineTagKind.lesson, text: '线代')),
      );
      expect(
        const TimelineBarEntry(
          title: '考研',
          colorArgb: 0xFF112233,
          displayText: '30天',
        ),
        const TimelineBarEntry(
          title: '考研',
          colorArgb: 0xFF112233,
          displayText: '30天',
        ),
      );
    });

    test('CalendarDayMeta 深比较 festivals 列表', () {
      CalendarDayMeta metaWith(List<String> festivals) => CalendarDayMeta(
        date: date,
        lunarLabel: '初一',
        solarTerm: '',
        festivals: festivals,
        isRestDay: false,
        isMakeupWorkday: false,
        weekNumber: 47,
      );
      expect(metaWith(<String>['元旦']), metaWith(<String>['元旦']));
      expect(metaWith(<String>['元旦']), isNot(metaWith(<String>['春节'])));
    });

    test('EventOccurrence 按事件身份 + 日期相等', () {
      final eventA = CalendarEvent.create(
        id: 'e1',
        content: '任务',
        startDate: date,
        occurredAt: DateTime(2026, 11, 18),
      );
      final eventB = CalendarEvent.create(
        id: 'e1',
        content: '任务',
        startDate: date,
        occurredAt: DateTime(2026, 11, 18),
      );
      final other = DateKey(DateTime(2026, 11, 19));
      expect(EventOccurrence(eventA, date), EventOccurrence(eventB, date));
      expect(
        EventOccurrence(eventA, date),
        isNot(EventOccurrence(eventA, other)),
      );
    });

    test('CalendarDayModel / MonthData / VisibleDays 同内容相等', () {
      CalendarDayModel day({
        bool isToday = false,
        List<TimelineTag> tags = const [],
      }) => CalendarDayModel(
        date: date,
        meta: meta,
        cell: null,
        events: const <EventOccurrence>[],
        tags: tags,
        isToday: isToday,
        isCurrentMonth: true,
      );
      expect(day(), day());
      expect(day().hashCode, day().hashCode);
      expect(day(isToday: true), isNot(day()));
      expect(
        day(
          tags: const [
            TimelineTag(kind: TimelineTagKind.countdown, text: '考研'),
          ],
        ),
        day(
          tags: const [
            TimelineTag(kind: TimelineTagKind.countdown, text: '考研'),
          ],
        ),
      );

      final anchor = DateTime(2026, 11, 1);
      MonthData month(List<List<CalendarDayModel>> columns) => MonthData(
        anchor: anchor,
        weekdayHeaders: const ['一', '二', '三', '四', '五', '六', '日'],
        columns: columns,
        countdownBar: const [],
      );
      expect(
        month([
          [day()],
        ]),
        month([
          [day()],
        ]),
      );
      expect(
        month([
          [day()],
        ]),
        isNot(
          month([
            [day(isToday: true)],
          ]),
        ),
      );

      VisibleDays visible(Map<DateKey, DateTime> monthOf) => VisibleDays(
        anchor: anchor,
        weekdayHeaders: const ['一', '二', '三', '四', '五', '六', '日'],
        columns: [
          [date],
        ],
        monthOf: monthOf,
      );
      expect(visible({date: anchor}), visible({date: anchor}));
      expect(
        visible({date: anchor}),
        isNot(visible({date: DateTime(2026, 12, 1)})),
      );
    });
  });

  test('单日单元格变更只通知该日 dayModelProvider（ADR-0006 步骤3）', () async {
    final container = _container();
    addTearDown(container.dispose);
    await _settleLoad();

    final visible = container.read(visibleDaysProvider);
    final dates = visible.columns.expand((c) => c).toList();
    final target = dates[dates.length ~/ 2];

    final notified = <DateKey, int>{};
    final subs = <ProviderSubscription<void>>[
      for (final d in dates)
        container.listen<void>(
          dayModelProvider(d),
          (prev, next) => notified[d] = (notified[d] ?? 0) + 1,
        ),
    ];

    await container.read(calendarControllerProvider.notifier).saveCellLines(
      target,
      const [RichLine(id: 'l1', text: '单日内容')],
    );
    await _settleLoad();

    final fired = notified.entries.where((e) => e.value > 0).map((e) => e.key);
    expect(fired, [target]);
    for (final s in subs) {
      s.close();
    }
  });

  testWidgets('单日变更只重建该日 DayCellWidget（其余 build 计数不增）', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthGrid(
                onTap: (_) {},
                onDoubleTap: (_) {},
                onSecondaryTap: (_, _) {},
                onToggleLine: (_, _) {},
                onToggleEvent: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final visible = container.read(visibleDaysProvider);
    final dates = visible.columns.expand((c) => c).toList();
    final target = dates[dates.length ~/ 2];
    final total = tester.widgetList(find.byType(DayCellWidget)).length;
    expect(total, dates.length);

    // 统计变更引发的 DayCellWidget 实际重建次数（debug 钩子，逐脏 widget 回调）。
    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (Element e, bool builtOnce) {
      if (e.widget is DayCellWidget) rebuilds++;
    };
    await tester.runAsync(() async {
      await container.read(calendarControllerProvider.notifier).saveCellLines(
        target,
        const [RichLine(id: 'l1', text: '单日内容')],
      );
    });
    await tester.pumpAndSettle();
    debugOnRebuildDirtyWidget = null;

    expect(rebuilds, 1);
    expect(find.text('单日内容'), findsOneWidget);
  });
}
