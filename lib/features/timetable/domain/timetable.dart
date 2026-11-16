/// 课程表聚合（旧版 `timetable.lua` / `timetable_frame.xml`）。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';

import '../../../core/value_objects.dart';

enum WeekParity {
  all('全选'),
  odd('单周'),
  even('双周');

  const WeekParity(this.label);

  final String label;

  static WeekParity fromName(String? name) => WeekParity.values.firstWhere(
        (WeekParity p) => p.name == name,
        orElse: () => WeekParity.all,
      );
}

final class ClassPeriod extends ValueObject {
  const ClassPeriod({
    required this.index,
    required this.startLabel,
    required this.endLabel,
  });

  final int index;
  final String startLabel;
  final String endLabel;

  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'startLabel': startLabel,
        'endLabel': endLabel,
      };

  factory ClassPeriod.fromJson(Map<String, Object?> json) => ClassPeriod(
        index: (json['index'] as num?)?.toInt() ?? 1,
        startLabel: json['startLabel'] as String? ?? '08:00',
        endLabel: json['endLabel'] as String? ?? '08:45',
      );

  @override
  List<Object?> get props => <Object?>[index, startLabel, endLabel];
}

final class Lesson extends ValueObject {
  const Lesson({
    required this.id,
    required this.name,
    required this.weekday,
    required this.period,
    this.teacher = '',
    this.room = '',
    this.parity = WeekParity.all,
    this.color = EventColor.defaultText,
  });

  final String id;
  final String name;
  final int weekday;
  final int period;
  final String teacher;
  final String room;
  final WeekParity parity;
  final EventColor color;

  bool conflictsWith(Lesson other) =>
      other.id != id &&
      other.weekday == weekday &&
      other.period == period &&
      (parity == WeekParity.all ||
          other.parity == WeekParity.all ||
          parity == other.parity);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'weekday': weekday,
        'period': period,
        'teacher': teacher,
        'room': room,
        'parity': parity.name,
        'color': color.argb,
      };

  factory Lesson.fromJson(Map<String, Object?> json) => Lesson(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        weekday: (json['weekday'] as num?)?.toInt() ?? 1,
        period: (json['period'] as num?)?.toInt() ?? 1,
        teacher: json['teacher'] as String? ?? '',
        room: json['room'] as String? ?? '',
        parity: WeekParity.fromName(json['parity'] as String?),
        color: EventColor(json['color'] as int? ?? 0xFF1F2024),
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        weekday,
        period,
        teacher,
        room,
        parity,
        color,
      ];
}

final class Timetable extends AggregateRoot<String> {
  Timetable._({
    required String id,
    required this.name,
    required this.startDate,
    required this.weeks,
    required this.periodsPerDay,
    required this.lessonMinutes,
    required this.breakMinutes,
    required this.periods,
    required this.hideWeekend,
    required this.lessons,
  }) : super(id);

  factory Timetable.create({
    required String id,
    required String name,
    required DateKey startDate,
    int weeks = 20,
    int periodsPerDay = 8,
    int lessonMinutes = 45,
    int breakMinutes = 10,
    bool hideWeekend = false,
  }) {
    final periods = List<ClassPeriod>.generate(
      periodsPerDay,
      (int i) {
        final start = 8 * 60 + i * (lessonMinutes + breakMinutes);
        String label(int minutes) =>
            '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
            '${(minutes % 60).toString().padLeft(2, '0')}';
        return ClassPeriod(
          index: i + 1,
          startLabel: label(start),
          endLabel: label(start + lessonMinutes),
        );
      },
    );
    return Timetable._(
      id: id,
      name: name,
      startDate: startDate,
      weeks: weeks,
      periodsPerDay: periodsPerDay,
      lessonMinutes: lessonMinutes,
      breakMinutes: breakMinutes,
      periods: periods,
      hideWeekend: hideWeekend,
      lessons: const <Lesson>[],
    );
  }

  final String name;
  final DateKey startDate;
  final int weeks;
  final int periodsPerDay;
  final int lessonMinutes;
  final int breakMinutes;
  final List<ClassPeriod> periods;
  final bool hideWeekend;
  final List<Lesson> lessons;

  /// 时间冲突校验（旧版 `IDS_LESSON_PERIOD_CONFLICT`）。
  List<Lesson> conflictsOf(Lesson candidate) =>
      lessons.where((Lesson l) => candidate.conflictsWith(l)).toList();

  /// 某天是本学期第几周（1-based），不在学期内返回 `null`。
  int? weekIndexOf(DateKey date) {
    final days = date.differenceInDays(startDate);
    if (days < 0) return null;
    final week = days ~/ 7 + 1;
    return week <= weeks ? week : null;
  }

  List<Lesson> lessonsOn(DateKey date) {
    final week = weekIndexOf(date);
    if (week == null) return const <Lesson>[];
    return lessons
        .where(
          (Lesson l) =>
              l.weekday == date.weekday &&
              (l.parity == WeekParity.all ||
                  (week.isOdd && l.parity == WeekParity.odd) ||
                  (week.isEven && l.parity == WeekParity.even)),
        )
        .toList();
  }

  Timetable copyWith({
    String? name,
    DateKey? startDate,
    int? weeks,
    int? periodsPerDay,
    bool? hideWeekend,
    List<Lesson>? lessons,
  }) =>
      Timetable._(
        id: id,
        name: name ?? this.name,
        startDate: startDate ?? this.startDate,
        weeks: weeks ?? this.weeks,
        periodsPerDay: periodsPerDay ?? this.periodsPerDay,
        lessonMinutes: lessonMinutes,
        breakMinutes: breakMinutes,
        periods: periods,
        hideWeekend: hideWeekend ?? this.hideWeekend,
        lessons: lessons ?? this.lessons,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'startDate': startDate.key,
        'weeks': weeks,
        'periodsPerDay': periodsPerDay,
        'lessonMinutes': lessonMinutes,
        'breakMinutes': breakMinutes,
        'periods': periods.map((ClassPeriod p) => p.toJson()).toList(),
        'hideWeekend': hideWeekend,
        'lessons': lessons.map((Lesson l) => l.toJson()).toList(),
      };

  factory Timetable.fromJson(Map<String, Object?> json) => Timetable._(
        id: json['id'] as String,
        name: json['name'] as String? ?? '新建课程表',
        startDate: DateKey.parse(json['startDate']! as String),
        weeks: (json['weeks'] as num?)?.toInt() ?? 20,
        periodsPerDay: (json['periodsPerDay'] as num?)?.toInt() ?? 8,
        lessonMinutes: (json['lessonMinutes'] as num?)?.toInt() ?? 45,
        breakMinutes: (json['breakMinutes'] as num?)?.toInt() ?? 10,
        periods: (json['periods'] as List? ?? const <Object?>[])
            .map(
              (Object? p) => ClassPeriod.fromJson(
                Map<String, Object?>.from(p! as Map),
              ),
            )
            .toList(),
        hideWeekend: json['hideWeekend'] as bool? ?? false,
        lessons: (json['lessons'] as List? ?? const <Object?>[])
            .map(
              (Object? l) =>
                  Lesson.fromJson(Map<String, Object?>.from(l! as Map)),
            )
            .toList(),
      );
}

abstract interface class TimetableRepository {
  Future<Result<List<Timetable>>> all();

  Future<Result<void>> save(Timetable timetable);

  Future<Result<void>> delete(String id);
}
