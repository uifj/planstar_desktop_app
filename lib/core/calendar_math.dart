/// 日历数学与农历 / 节气 / 节假日适配。
///
/// 农历数据由 pub.dev 的 `lunar` 包提供，覆盖旧版 `ShowLunarCalendar /
/// Show24SolarTerms / ShowFestival / ShowHoliday` 开关所需的信息。
/// 旧版 `ShowJiYi`（忌宜）无渲染消费方，已随 yi/ji 字段一并移除（ADR-0001）。
library;

import 'package:core/domain.dart';
import 'package:lunar/lunar.dart';

import 'value_objects.dart';

/// 某一天的展示元数据（读模型）。
final class CalendarDayMeta extends ValueObject {
  const CalendarDayMeta({
    required this.date,
    required this.lunarLabel,
    required this.solarTerm,
    required this.festivals,
    required this.isRestDay,
    required this.isMakeupWorkday,
    required this.weekNumber,
  });

  final DateKey date;
  final String lunarLabel;
  final String solarTerm;
  final List<String> festivals;
  final bool isRestDay;
  final bool isMakeupWorkday;
  final int weekNumber;

  @override
  List<Object?> get props => <Object?>[
    date,
    lunarLabel,
    solarTerm,
    festivals,
    isRestDay,
    isMakeupWorkday,
    weekNumber,
  ];

  /// 单元格副标题优先级：节气 > 节日 > 农历日。
  String subtitle({
    required bool showLunar,
    required bool showSolarTerms,
    required bool showFestival,
  }) {
    if (showSolarTerms && solarTerm.isNotEmpty) return solarTerm;
    if (showFestival && festivals.isNotEmpty) return festivals.first;
    if (showLunar) return lunarLabel;
    return '';
  }
}

abstract final class CalendarMath {
  /// 一天中的 00:00（去掉时分秒）。
  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 某月第一天。
  static DateTime firstOfMonth(DateTime value) =>
      DateTime(value.year, value.month, 1);

  /// 某月的天数。
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// 以 [startOfWeek]（1=周一…7=周日）为基准，求所在周的周一。
  static DateTime startOfWeekOf(DateTime date, int startOfWeek) {
    final offset = (date.weekday - startOfWeek + 7) % 7;
    return DateTime(date.year, date.month, date.day - offset);
  }

  /// ISO 周序号（配合 `StartOneWeek` 偏移量）。
  static int weekNumberOf(DateTime date, int firstWeekOffset) {
    final first = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(first).inDays + 1;
    return ((dayOfYear + first.weekday - 2) / 7).floor() + 1 + firstWeekOffset;
  }

  /// 生成网格：每个元素是一个「月份列」的日期序列。
  ///
  /// [rows] 对应旧版 `MaxRows`，[columns] 对应 `MaxColumns`，
  /// [passedWeeks] 对应 `Passedweek`（浮动模式下从当前周往前多显示几周）。
  static List<List<DateKey>> buildGrid({
    required DateTime anchor,
    required int startOfWeek,
    required int rows,
    required int columns,
    required int passedWeeks,
    required bool singleLine,
    required DateTime today,
  }) {
    final effectiveRows = singleLine ? 1 : rows.clamp(1, 8);
    final result = <List<DateKey>>[];
    for (var column = 0; column < columns.clamp(1, 6); column++) {
      final month = DateTime(anchor.year, anchor.month + column, 1);
      var firstVisible = startOfWeekOf(firstOfMonth(month), startOfWeek);
      if (passedWeeks > 0) {
        firstVisible = firstVisible.subtract(Duration(days: 7 * passedWeeks));
      }
      if (singleLine &&
          today.year == month.year &&
          today.month == month.month) {
        firstVisible = startOfWeekOf(today, startOfWeek);
      }
      result.add(
        List<DateKey>.generate(
          effectiveRows * 7,
          (int index) => DateKey(firstVisible.add(Duration(days: index))),
        ),
      );
    }
    return result;
  }

  /// 用 `lunar` 包解析农历 / 节气 / 节日 / 法定假日。
  ///
  /// 进程级 LRU 缓存：农历与节假日表是 lunar 包内置静态数据，
  /// (日期, 周偏移) → 元信息是纯函数，可常驻；若未来引入自定义节假日
  /// 数据源，必须按数据版本失效。
  static CalendarDayMeta metaOf(DateKey date, {int firstWeekOffset = 0}) {
    final cacheKey = '${date.key}|$firstWeekOffset';
    final cached = _metaCache.remove(cacheKey);
    if (cached != null) {
      _metaCache[cacheKey] = cached;
      return cached;
    }

    final solar = Solar.fromDate(date.date);
    final lunar = solar.getLunar();
    final jieQi = lunar.getJieQi();
    final festivals = <String>{
      ...solar.getFestivals(),
      ...lunar.getFestivals(),
    }.toList();

    // 初一等农历日才显示农历，节气与节日优先。
    final lunarLabel = lunar.getDay() == 1
        ? '${lunar.getMonthInChinese()}月'
        : lunar.getDayInChinese();

    final holiday = HolidayUtil.getHoliday(date.key);

    final meta = CalendarDayMeta(
      date: date,
      lunarLabel: lunarLabel,
      solarTerm: jieQi,
      festivals: festivals,
      isRestDay: holiday != null && !holiday.isWork(),
      isMakeupWorkday: holiday != null && holiday.isWork(),
      weekNumber: weekNumberOf(date.date, firstWeekOffset),
    );
    if (_metaCache.length >= _metaCacheLimit) {
      _metaCache.remove(_metaCache.keys.first);
    }
    _metaCache[cacheKey] = meta;
    return meta;
  }

  static const int _metaCacheLimit = 4096;
  static final Map<String, CalendarDayMeta> _metaCache =
      <String, CalendarDayMeta>{};

  /// 中文星期表头。
  static const List<String> weekdayShort = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  /// 按 `startOfWeek` 旋转星期表头。
  static List<String> weekdayHeaders(int startOfWeek) {
    final rotated = <String>[];
    for (var i = 0; i < 7; i++) {
      rotated.add(weekdayShort[(startOfWeek - 1 + i) % 7]);
    }
    return rotated;
  }
}
