/// 共享内核：跨限界上下文复用的值对象。
///
/// 全部为纯 Dart，不 import Flutter，可直接被 `dart test` 覆盖。
/// 与 `packages/infras/core` 的 `ValueObject` / `Entity` 对齐：
/// 值对象靠属性相等，实体靠身份相等。
library;

import 'package:core/domain.dart';

/// 日历的「天」身份：无量纲、无时区、无时分秒。
final class DateKey extends ValueObject {
  DateKey(DateTime date) : _date = DateTime(date.year, date.month, date.day);

  factory DateKey.parse(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) {
      throw FormatException('非法日期：$raw');
    }
    return DateKey(
      DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
    );
  }

  static DateKey today(DateTime now) => DateKey(now);

  final DateTime _date;

  DateTime get date => _date;
  int get year => _date.year;
  int get month => _date.month;
  int get day => _date.day;

  /// ISO 日期 `YYYY-MM-DD`，同时也是持久化主键。
  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// Dart 的 weekday：1=周一 … 7=周日。
  int get weekday => _date.weekday;

  DateKey addDays(int days) => DateKey(_date.add(Duration(days: days)));

  int differenceInDays(DateKey other) =>
      _date.difference(other._date).inDays.round();

  bool isWithin(DateRange range) =>
      !_date.isBefore(range.start.date) && !_date.isAfter(range.end.date);

  @override
  List<Object?> get props => <Object?>[key];

  @override
  String toString() => key;

  String get cnMonth => '$month月';
  String get cnDate => '$month月$day日';
  String get cnFull => '$year年$month月$day日';
  String get cnWeekday => const <String>[
        '一',
        '二',
        '三',
        '四',
        '五',
        '六',
        '日',
      ][weekday - 1];
}

/// 闭区间日期范围（搜索 / 导出 / 重复规则展开时使用）。
final class DateRange extends ValueObject {
  DateRange(this.start, this.end);

  final DateKey start;
  final DateKey end;

  bool contains(DateKey date) => date.isWithin(this);

  @override
  List<Object?> get props => <Object?>[start, end];

  @override
  String toString() => '${start.key}..${end.key}';
}

/// 颜色值对象：`int` 形式的 ARGB，避免领域层依赖 `dart:ui`。
final class EventColor extends ValueObject {
  const EventColor(this.argb);

  /// 从 `#AARRGGBB` / `#RRGGBB` 解析。
  factory EventColor.fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '').toUpperCase();
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return EventColor.defaultText;
    }
    return EventColor(cleaned.length == 6 ? (0xFF000000 | value) : value);
  }

  /// 旧版 23 色调色板（对齐 `cal_context_menu.xml` 的 23 色）。
  static const List<EventColor> palette = <EventColor>[
    EventColor(0xFFE54545),
    EventColor(0xFFF58989),
    EventColor(0xFFFF7200),
    EventColor(0xFFFFA455),
    EventColor(0xFFE0A800),
    EventColor(0xFFD8D26B),
    EventColor(0xFF0ABF77),
    EventColor(0xFF5AD69E),
    EventColor(0xFF00ABD6),
    EventColor(0xFF4086FF),
    EventColor(0xFF1C66E5),
    EventColor(0xFF7AAFFF),
    EventColor(0xFF8157FF),
    EventColor(0xFFB18CFF),
    EventColor(0xFFF5457F),
    EventColor(0xFFFF9AC0),
    EventColor(0xFF795548),
    EventColor(0xFF9E9E9E),
    EventColor(0xFF607D8B),
    EventColor(0xFF3A3C42),
    EventColor(0xFF000000),
    EventColor(0xFFFFFFFF),
    EventColor(0x00000000),
  ];

  static const EventColor defaultText = EventColor(0xFF1F2024);
  static const EventColor transparent = EventColor(0x00000000);

  final int argb;

  String get hex => '#${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  bool get isTransparent => (argb >> 24) == 0;

  @override
  List<Object?> get props => <Object?>[argb];
}

/// 单元格 / 便签里的「一行富文本」。
///
/// 旧版每一行的文字颜色、完成状态、关联事件都是独立的；把它提为共享值对象，
/// 日历单元格与便签就不需要各写一份。
final class RichLine extends ValueObject {
  const RichLine({
    required this.id,
    required this.text,
    this.color = EventColor.defaultText,
    this.completed = false,
    this.eventId,
    this.reminderTime,
  });

  final String id;
  final String text;
  final EventColor color;
  final bool completed;
  final String? eventId;

  /// 该行显示的提醒时间（旧版 `ShowReminderDate`）。
  final DateTime? reminderTime;

  RichLine copyWith({
    String? text,
    EventColor? color,
    bool? completed,
    String? eventId,
    DateTime? reminderTime,
    bool clearEventId = false,
    bool clearReminderTime = false,
  }) =>
      RichLine(
        id: id,
        text: text ?? this.text,
        color: color ?? this.color,
        completed: completed ?? this.completed,
        eventId: clearEventId ? null : (eventId ?? this.eventId),
        reminderTime:
            clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'text': text,
        'color': color.argb,
        'completed': completed,
        'eventId': eventId,
        'reminderTime': reminderTime?.toIso8601String(),
      };

  factory RichLine.fromJson(Map<String, Object?> json) => RichLine(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        color: EventColor(json['color'] as int? ?? 0xFF1F2024),
        completed: json['completed'] as bool? ?? false,
        eventId: json['eventId'] as String?,
        reminderTime: json['reminderTime'] == null
            ? null
            : DateTime.tryParse(json['reminderTime']! as String),
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        text,
        color,
        completed,
        eventId,
        reminderTime?.toIso8601String(),
      ];
}
