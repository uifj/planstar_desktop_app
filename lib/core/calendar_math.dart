/// 日历数学与农历 / 节气 / 节假日适配。
///
/// 纯计算，不持有状态。农历数据由 pub.dev 的 `lunar` 包提供，
/// 覆盖旧版 `ShowLunarCalendar / Show24SolarTerms / ShowFestival /
/// ShowHoliday / ShowJiYi` 全部开关所需的信息。
library;

import 'package:lunar/lunar.dart';

import 'value_objects.dart';

/// 某一天的展示元数据（读模型）。
final class CalendarDayMeta {
  const CalendarDayMeta({
    required this.date,
    required this.lunarLabel,
    required this.solarTerm,
    required this.festivals,
    required this.isRestDay,
    required this.isMakeupWorkday,
    required this.yi,
    required this.ji,
    required this.weekNumber,
  });

  final DateKey date;
  final String lunarLabel;
  final String solarTerm;
  final List<String> festivals;
  final bool isRestDay;
  final bool isMakeupWorkday;
  final String yi;
  final String ji;
  final int weekNumber;
}

abstract final class CalendarMath {
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

  /// 农历 / 节气 / 忌宜解析结果按「日期 + 偏移」缓存。
  ///
  /// 月历一次重建要算 42 天，而 `lunar` 包的农历/黄历解析是纯 CPU 开销；
  /// 同一日期在任意 settings / 数据变更后都会重复计算。农历元数据只跟
  /// 公历日期有关，缓存是安全的。2048 条足以覆盖数年浏览范围。
  static const int _metaCacheLimit = 2048;
  static final Map<String, CalendarDayMeta> _metaCache =
      <String, CalendarDayMeta>{};

  /// 用 `lunar` 包解析农历 / 节气 / 节日 / 忌宜 / 法定假日。
  static CalendarDayMeta metaOf(DateKey date, {int firstWeekOffset = 0}) {
    final String cacheKey = '${date.key}|$firstWeekOffset';
    final CalendarDayMeta? cached = _metaCache[cacheKey];
    if (cached != null) return cached;

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
    final yi = lunar.getDayYi();
    final ji = lunar.getDayJi();

    final CalendarDayMeta meta = CalendarDayMeta(
      date: date,
      lunarLabel: lunarLabel,
      solarTerm: jieQi,
      festivals: festivals,
      isRestDay: holiday != null && !holiday.isWork(),
      isMakeupWorkday: holiday != null && holiday.isWork(),
      yi: yi.isEmpty ? '' : yi.take(3).join('·'),
      ji: ji.isEmpty ? '' : ji.take(3).join('·'),
      weekNumber: weekNumberOf(date.date, firstWeekOffset),
    );
    if (_metaCache.length >= _metaCacheLimit) {
      _metaCache.remove(_metaCache.keys.first);
    }
    _metaCache[cacheKey] = meta;
    return meta;
  }
}
