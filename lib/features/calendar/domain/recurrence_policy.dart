/// 重复规则展开引擎（领域服务）。
///
/// 覆盖旧版 16 种重复规则；采用「从起始日逐日推进 + 纯函数判定」的实现，
/// 保证同一输入永远得到同一结果，也便于纯 Dart 单测。
library;

import 'package:lunar/lunar.dart';

import '../../../core/calendar_math.dart';
import '../../../core/value_objects.dart';
import 'calendar_event.dart';
import 'recurrence.dart';

abstract final class RecurrencePolicy {
  /// 展开 [range] 内的全部发生日（已剔除例外与完成截断）。
  static List<DateKey> occurrences(
    CalendarEvent event,
    DateRange range, {
    int maxDays = 4000,
  }) {
    final rule = event.recurrence;
    final origin = event.startDate;
    final result = <DateKey>[];
    if (!rule.isRecurring) {
      if (range.contains(origin) && !event.isExcludedOn(origin)) {
        result.add(origin);
      }
      return result;
    }

    final hardEnd = _earliest(range.end, rule.until, event.recurrenceUntil);
    if (hardEnd.differenceInDays(origin) < 0) return result;

    final originLunar = rule.kind == RecurrenceKind.lunarYearly
        ? Solar.fromDate(origin.date).getLunar()
        : null;
    var cursor = origin;
    var emitted = 0;
    for (
      var step = 0;
      step < maxDays && cursor.differenceInDays(hardEnd) <= 0;
      step++
    ) {
      if (_matches(cursor, origin, rule, originLunar)) {
        emitted++;
        if (rule.count != null && emitted > rule.count!) break;
        if (range.contains(cursor) && !event.isExcludedOn(cursor)) {
          result.add(cursor);
        }
      }
      cursor = cursor.addDays(1);
    }
    return result;
  }

  /// [event] 是否在 [date] 发生（用于单元格渲染）。
  ///
  /// 单次判定请用 [expansionOf] 复用上下文；此便捷入口每次重建上下文，
  /// 带 count 的事件会重新走一次有界推进。
  static bool happensOn(CalendarEvent event, DateKey date) =>
      expansionOf(event).happensOn(date);

  /// 每事件展开上下文：预计算循环不变量（origin 农历、count 硬边界），
  /// 供同一轮读模型计算内对多个日期复用，避免逐日重算。
  static RecurrenceExpansion expansionOf(CalendarEvent event) {
    final rule = event.recurrence;
    Lunar? originLunar;
    DateKey? countEnd;
    if (rule.isRecurring) {
      if (rule.kind == RecurrenceKind.lunarYearly) {
        originLunar = Solar.fromDate(event.startDate.date).getLunar();
      }
      if (rule.count != null) {
        countEnd = _countHorizon(event, originLunar);
      }
    }
    return RecurrenceExpansion._(event, originLunar, countEnd);
  }

  /// 第 count 次发生日（count 约束的硬边界）。
  ///
  /// 与 occurrences 一致：例外日也计入次数；maxDays 内未达 count 返回 null
  /// （occurrences 同样在该上限处停止展开）。
  static DateKey? _countHorizon(
    CalendarEvent event,
    Lunar? originLunar, {
    int maxDays = 4000,
  }) {
    final rule = event.recurrence;
    final origin = event.startDate;
    var cursor = origin;
    var emitted = 0;
    for (var step = 0; step < maxDays; step++) {
      if (_matches(cursor, origin, rule, originLunar)) {
        emitted++;
        if (emitted == rule.count) return cursor;
      }
      cursor = cursor.addDays(1);
    }
    return null;
  }

  static DateKey _earliest(DateKey a, DateKey? b, DateKey? c) {
    var result = a;
    if (b != null && b.differenceInDays(result) < 0) result = b;
    if (c != null && c.differenceInDays(result) < 0) result = c;
    return result;
  }

  static bool _matches(
    DateKey date,
    DateKey origin,
    RecurrenceRule rule, [
    Lunar? originLunar,
  ]) {
    final days = date.differenceInDays(origin);
    if (days < 0) return false;
    final interval = rule.interval < 1 ? 1 : rule.interval;
    final months = (date.year - origin.year) * 12 + date.month - origin.month;

    switch (rule.kind) {
      case RecurrenceKind.none:
        return days == 0;
      case RecurrenceKind.daily:
        return days % interval == 0;
      case RecurrenceKind.workday:
        return date.weekday <= 5 && days % interval == 0;
      case RecurrenceKind.weekly:
        return days % (7 * interval) == 0;
      case RecurrenceKind.monthly:
        return date.day == origin.day && months % interval == 0;
      case RecurrenceKind.monthLastDay:
        return date.day == CalendarMath.daysInMonth(date.year, date.month);
      case RecurrenceKind.quarterly:
        return date.day == origin.day && months % (3 * interval) == 0;
      case RecurrenceKind.yearly:
        return date.month == origin.month &&
            date.day == origin.day &&
            (date.year - origin.year) % interval == 0;
      case RecurrenceKind.lunarYearly:
        final current = Solar.fromDate(date.date).getLunar();
        final start = originLunar ?? Solar.fromDate(origin.date).getLunar();
        return current.getMonth() == start.getMonth() &&
            current.getDay() == start.getDay();
      case RecurrenceKind.legalWorkday:
        final meta = CalendarMath.metaOf(date);
        final isLegalWorkday =
            !meta.isRestDay && (date.weekday <= 5 || meta.isMakeupWorkday);
        return isLegalWorkday && days % interval == 0;
      case RecurrenceKind.ebbinghaus:
        return days == 0 || RecurrenceRule.ebbinghausOffsets.contains(days);
      case RecurrenceKind.customDay:
        return days % interval == 0;
      case RecurrenceKind.customWeek:
        if (!rule.weekdays.contains(date.weekday)) return false;
        final weeks = days ~/ 7;
        return weeks % interval == 0;
      case RecurrenceKind.customMonthDay:
        return rule.monthDays.contains(date.day);
      case RecurrenceKind.customMonthWeek:
        final nth = rule.nthWeekday ~/ 10;
        final weekday = rule.nthWeekday % 10;
        return date.weekday == weekday &&
            ((date.day - 1) ~/ 7) + 1 == nth &&
            months % interval == 0;
      case RecurrenceKind.customYear:
        return date.month == origin.month &&
            date.day == origin.day &&
            (date.year - origin.year) % interval == 0;
    }
  }
}

/// 单事件的重复判定上下文（不可变），由 [RecurrencePolicy.expansionOf] 创建。
final class RecurrenceExpansion {
  const RecurrenceExpansion._(this._event, this._originLunar, this._countEnd);

  final CalendarEvent _event;
  final Lunar? _originLunar;
  final DateKey? _countEnd;

  bool happensOn(DateKey date) {
    if (_event.isExcludedOn(date)) return false;
    final rule = _event.recurrence;
    if (!rule.isRecurring) return _event.startDate == date;
    if (date.differenceInDays(_event.startDate) < 0) return false;
    if (rule.until != null && date.differenceInDays(rule.until!) > 0) {
      return false;
    }
    if (_countEnd != null && date.differenceInDays(_countEnd) > 0) {
      return false;
    }
    return RecurrencePolicy._matches(
      date,
      _event.startDate,
      rule,
      _originLunar,
    );
  }
}
