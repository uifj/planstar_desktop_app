/// ADR-0004 回归：copyWith 哨兵单开关、cells Map 索引、贡献者注入扩展点。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/calendar/application/calendar_controller.dart';
import 'package:planstar_desktop_app/features/calendar/domain/day_cell.dart';
import 'package:planstar_desktop_app/features/calendar/presentation/read_model/month_data.dart';
import 'package:planstar_desktop_app/features/settings/domain/app_settings.dart';

void main() {
  final now = DateTime(2026, 11, 18, 9);
  final today = DateKey(now);

  group('CalendarState.copyWith error 单开关', () {
    test('显式传 null 清除错误', () {
      const state = CalendarState(error: '旧错误');
      expect(state.copyWith(error: null).error, isNull);
    });

    test('不传 error 保留原值', () {
      const state = CalendarState(error: '旧错误');
      expect(state.copyWith(loading: false).error, '旧错误');
    });

    test('传新值替换', () {
      const state = CalendarState(error: '旧错误');
      expect(state.copyWith(error: '新错误').error, '新错误');
    });
  });

  group('CalendarState.cells 按日期索引', () {
    test('Map 直接按 DateKey 查找', () {
      final cell = DayCell.create(today, now);
      final state = CalendarState(cells: <DateKey, DayCell>{today: cell});
      expect(state.cells[today], same(cell));
      expect(state.cells[today.addDays(1)], isNull);
    });
  });

  group('CalendarReadModelAssembler 贡献者扩展点', () {
    MonthData assemble(List<TimelineContribution> contributions) =>
        CalendarReadModelAssembler(contributions: contributions).assemble(
          anchor: DateTime(2026, 11, 1),
          settings: AppSettings.defaults,
          calendar: const CalendarState(),
          today: today,
        );

    CalendarDayModel dayOf(MonthData month, DateKey date) => month.columns
        .expand((List<CalendarDayModel> c) => c)
        .firstWhere((CalendarDayModel d) => d.date == date);

    test('注册假贡献者即可向月历注入条目', () {
      final month = assemble(<TimelineContribution>[
        TimelineContribution(
          tagsOn: (DateTime date) => DateKey(date) == today
              ? const <TimelineTag>[
                  TimelineTag(kind: TimelineTagKind.lesson, text: '假贡献条目'),
                ]
              : const <TimelineTag>[],
          bar: const <TimelineBarEntry>[
            TimelineBarEntry(
              title: '测试条',
              colorArgb: 0xFF123456,
              displayText: '3天后',
            ),
          ],
        ),
      ]);
      final day = dayOf(month, today);
      expect(day.tags.map((TimelineTag t) => t.text), contains('假贡献条目'));
      expect(month.countdownBar.single.title, '测试条');
      expect(month.countdownBar.single.displayText, '3天后');
      expect(month.countdownBar.single.colorArgb, 0xFF123456);
    });

    test('多贡献者条目按注册顺序拼接', () {
      TimelineContribution named(String text) => TimelineContribution(
        tagsOn: (DateTime date) => DateKey(date) == today
            ? <TimelineTag>[
                TimelineTag(kind: TimelineTagKind.subscription, text: text),
              ]
            : const <TimelineTag>[],
      );
      final month = assemble(<TimelineContribution>[
        named('第一条'),
        named('第二条'),
      ]);
      expect(
        dayOf(month, today).tags.map((TimelineTag t) => t.text).toList(),
        <String>['第一条', '第二条'],
      );
    });

    test('无贡献者时读模型仍正常构建', () {
      final month = assemble(const <TimelineContribution>[]);
      expect(month.columns, isNotEmpty);
      expect(month.countdownBar, isEmpty);
      expect(dayOf(month, today).tags, isEmpty);
    });
  });
}
