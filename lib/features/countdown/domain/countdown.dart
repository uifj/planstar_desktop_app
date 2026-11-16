/// 倒数日聚合根 + 仓储端口（旧版 `dkappcal/countdown_func.lua`）。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';

import '../../../core/app_events.dart';
import '../../../core/value_objects.dart';

enum CountdownType {
  custom('倒计时'),
  birthday('生日'),
  memorial('纪念日'),
  festival('节日'),
  exam('考试');

  const CountdownType(this.label);

  final String label;

  static CountdownType fromName(String? name) =>
      CountdownType.values.firstWhere(
        (CountdownType t) => t.name == name,
        orElse: () => CountdownType.custom,
      );
}

enum CountdownShowType {
  desktopCard('卡片方式显示'),
  calendarBottom('日历底部显示'),
  both('两者都显示');

  const CountdownShowType(this.label);

  final String label;

  bool get onDesktop =>
      this == desktopCard || this == both;

  bool get onCalendar =>
      this == calendarBottom || this == both;

  static CountdownShowType fromName(String? name) =>
      CountdownShowType.values.firstWhere(
        (CountdownShowType t) => t.name == name,
        orElse: () => CountdownShowType.both,
      );
}

final class CountdownItem extends AggregateRoot<String> {
  CountdownItem._({
    required String id,
    required this.title,
    required this.targetDate,
    required this.type,
    required this.showType,
    required this.color,
    required this.lunar,
    required this.birthYear,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  factory CountdownItem.create({
    required String id,
    required String title,
    required DateKey targetDate,
    required DateTime occurredAt,
    CountdownType type = CountdownType.custom,
    CountdownShowType showType = CountdownShowType.both,
    EventColor color = EventColor.defaultText,
    bool lunar = false,
    int? birthYear,
  }) {
    final item = CountdownItem._(
      id: id,
      title: title,
      targetDate: targetDate,
      type: type,
      showType: showType,
      color: color,
      lunar: lunar,
      birthYear: birthYear,
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );
    item.raiseDomainEvent(
      CountdownChanged(aggregateId: id, occurredAt: occurredAt),
    );
    return item;
  }

  final String title;
  final DateKey targetDate;
  final CountdownType type;
  final CountdownShowType showType;
  final EventColor color;
  final bool lunar;
  final int? birthYear;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 生日 / 纪念日按「下一次周年」计算，普通倒数日按固定日期计算。
  DateKey nextOccurrence(DateKey today) {
    if (type != CountdownType.birthday && type != CountdownType.memorial) {
      return targetDate;
    }
    var candidate = DateKey(
      DateTime(today.year, targetDate.month, targetDate.day),
    );
    if (candidate.differenceInDays(today) < 0) {
      candidate = DateKey(
        DateTime(today.year + 1, targetDate.month, targetDate.day),
      );
    }
    return candidate;
  }

  int daysLeft(DateKey today) => nextOccurrence(today).differenceInDays(today);

  String displayText(DateKey today) {
    final days = daysLeft(today);
    if (days == 0) return '今天';
    if (days > 0) return '还有$days天';
    if (type == CountdownType.birthday || type == CountdownType.memorial) {
      return '已过${-days}天';
    }
    return '过期${-days}天';
  }

  String ageText(DateKey today) {
    if (type != CountdownType.birthday || birthYear == null) return '';
    return '${nextOccurrence(today).year - birthYear!}岁生日';
  }

  CountdownItem changed({
    required DateTime occurredAt,
    String? title,
    DateKey? targetDate,
    CountdownType? type,
    CountdownShowType? showType,
    EventColor? color,
    bool? lunar,
    int? birthYear,
  }) {
    final next = CountdownItem._(
      id: id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      type: type ?? this.type,
      showType: showType ?? this.showType,
      color: color ?? this.color,
      lunar: lunar ?? this.lunar,
      birthYear: birthYear ?? this.birthYear,
      createdAt: createdAt,
      updatedAt: occurredAt,
    );
    next.raiseDomainEvent(
      CountdownChanged(aggregateId: id, occurredAt: occurredAt),
    );
    return next;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'targetDate': targetDate.key,
        'type': type.name,
        'showType': showType.name,
        'color': color.argb,
        'lunar': lunar,
        'birthYear': birthYear,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CountdownItem.fromJson(Map<String, Object?> json) =>
      CountdownItem._(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        targetDate: DateKey.parse(json['targetDate']! as String),
        type: CountdownType.fromName(json['type'] as String?),
        showType: CountdownShowType.fromName(json['showType'] as String?),
        color: EventColor(json['color'] as int? ?? 0xFF1F2024),
        lunar: json['lunar'] as bool? ?? false,
        birthYear: (json['birthYear'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

abstract interface class CountdownRepository {
  Future<Result<List<CountdownItem>>> all();

  Future<Result<void>> save(CountdownItem item);

  Future<Result<void>> delete(String id);

  Future<Result<void>> clear();
}
