/// 重复规则值对象：对齐旧版 16 种 `recurrence_str`。
library;

import 'package:core/domain.dart';

import '../../../core/value_objects.dart';

enum RecurrenceKind {
  none('不重复'),
  daily('日重复'),
  workday('工作日重复'),
  weekly('周重复'),
  monthly('月重复'),
  monthLastDay('每月最后一天'),
  quarterly('每季度'),
  yearly('年重复'),
  lunarYearly('农历年重复'),
  legalWorkday('法定工作日重复'),
  ebbinghaus('艾宾浩斯记忆曲线'),
  customDay('自定义日重复'),
  customWeek('自定义周重复'),
  customMonthDay('自定义月重复（按日期）'),
  customMonthWeek('自定义月重复（按星期）'),
  customYear('自定义年重复');

  const RecurrenceKind(this.label);

  final String label;

  static RecurrenceKind fromName(String? name) =>
      RecurrenceKind.values.firstWhere(
        (RecurrenceKind k) => k.name == name,
        orElse: () => RecurrenceKind.none,
      );
}

final class RecurrenceRule extends ValueObject {
  const RecurrenceRule({
    this.kind = RecurrenceKind.none,
    this.interval = 1,
    this.weekdays = const <int>[],
    this.monthDays = const <int>[],
    this.nthWeekday = 0,
    this.count,
    this.until,
    this.lunar = false,
  });

  /// 艾宾浩斯复习偏移（天）。
  static const List<int> ebbinghausOffsets = <int>[1, 2, 4, 7, 15, 30];

  final RecurrenceKind kind;
  final int interval;
  final List<int> weekdays;
  final List<int> monthDays;

  /// 月按星期：`周序 * 10 + 星期`（如 31 = 第 3 个周一）。
  final int nthWeekday;
  final int? count;
  final DateKey? until;
  final bool lunar;

  bool get isRecurring => kind != RecurrenceKind.none;

  RecurrenceRule copyWith({
    RecurrenceKind? kind,
    int? interval,
    List<int>? weekdays,
    List<int>? monthDays,
    int? nthWeekday,
    int? count,
    DateKey? until,
    bool? lunar,
    bool clearCount = false,
    bool clearUntil = false,
  }) => RecurrenceRule(
    kind: kind ?? this.kind,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    monthDays: monthDays ?? this.monthDays,
    nthWeekday: nthWeekday ?? this.nthWeekday,
    count: clearCount ? null : (count ?? this.count),
    until: clearUntil ? null : (until ?? this.until),
    lunar: lunar ?? this.lunar,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'interval': interval,
    'weekdays': weekdays,
    'monthDays': monthDays,
    'nthWeekday': nthWeekday,
    'count': count,
    'until': until?.key,
    'lunar': lunar,
  };

  factory RecurrenceRule.fromJson(Map<String, Object?> json) => RecurrenceRule(
    kind: RecurrenceKind.fromName(json['kind'] as String?),
    interval: (json['interval'] as num?)?.toInt() ?? 1,
    weekdays: (json['weekdays'] as List?)?.cast<int>() ?? const <int>[],
    monthDays: (json['monthDays'] as List?)?.cast<int>() ?? const <int>[],
    nthWeekday: (json['nthWeekday'] as num?)?.toInt() ?? 0,
    count: (json['count'] as num?)?.toInt(),
    until: json['until'] == null
        ? null
        : DateKey.parse(json['until']! as String),
    lunar: json['lunar'] as bool? ?? false,
  );

  @override
  List<Object?> get props => <Object?>[
    kind,
    interval,
    weekdays,
    monthDays,
    nthWeekday,
    count,
    until,
    lunar,
  ];
}
