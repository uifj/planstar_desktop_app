/// 日历单元格聚合根：一天的富文本记录（双击编辑的对象）。
library;

import 'package:core/domain.dart';

import '../../../core/app_events.dart';
import '../../../core/value_objects.dart';

final class DayCell extends AggregateRoot<String> {
  DayCell._({
    required this.date,
    required this.lines,
    required this.backgroundColor,
    required this.updatedAt,
  }) : super(date.key);

  factory DayCell.create(DateKey date, DateTime occurredAt) {
    final cell = DayCell._(
      date: date,
      lines: const <RichLine>[],
      backgroundColor: EventColor.transparent,
      updatedAt: occurredAt,
    );
    cell.raiseDomainEvent(
      DayCellChanged(
        aggregateId: date.key,
        occurredAt: occurredAt,
        date: date,
        snapshot: '',
      ),
    );
    return cell;
  }

  final DateKey date;
  final List<RichLine> lines;
  final EventColor backgroundColor;
  final DateTime updatedAt;

  DayCell withLines(
    List<RichLine> nextLines, {
    EventColor? backgroundColor,
    required DateTime occurredAt,
  }) {
    final cell = DayCell._(
      date: date,
      lines: nextLines,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      updatedAt: occurredAt,
    );
    cell.raiseDomainEvent(
      DayCellChanged(
        aggregateId: date.key,
        occurredAt: occurredAt,
        date: date,
        snapshot: nextLines.map((RichLine l) => l.text).join('\n'),
      ),
    );
    // 按行 id 对比前后状态：只有「既存行从未完成变完成」才是完成事实。
    // 改色/删行/新增即完成的行都不发 TaskCompleted（ADR-0005）。
    final before = <String, RichLine>{
      for (final RichLine line in lines) line.id: line,
    };
    for (final RichLine line in nextLines) {
      if (!line.completed) continue;
      final old = before[line.id];
      if (old != null && !old.completed) {
        cell.raiseDomainEvent(
          TaskCompleted(
            aggregateId: date.key,
            occurredAt: occurredAt,
            date: date,
            source: TaskCompletionSource.cellLine,
          ),
        );
      }
    }
    return cell;
  }

  DayCell withBackgroundColor(EventColor color, DateTime occurredAt) =>
      withLines(lines, backgroundColor: color, occurredAt: occurredAt);

  String get snapshot => lines.map((RichLine l) => l.text).join('\n');

  Map<String, Object?> toJson() => <String, Object?>{
    'date': date.key,
    'lines': lines.map((RichLine l) => l.toJson()).toList(),
    'backgroundColor': backgroundColor.argb,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DayCell.fromJson(Map<String, Object?> json) => DayCell._(
    date: DateKey.parse(json['date']! as String),
    lines: (json['lines'] as List? ?? const <Object?>[])
        .map(
          (Object? l) =>
              RichLine.fromJson(Map<String, Object?>.from(l! as Map)),
        )
        .toList(),
    backgroundColor: EventColor(json['backgroundColor'] as int? ?? 0x00000000),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}
