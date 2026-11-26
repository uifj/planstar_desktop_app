/// 日历限界上下文的仓储端口（驱动侧由 `infrastructure` 实现）。
library;

import 'package:core/result.dart';

import '../../../core/value_objects.dart';
import 'calendar_event.dart';
import 'day_cell.dart';

abstract interface class CalendarRepository {
  Future<Result<List<CalendarEvent>>> allEvents();

  Future<Result<CalendarEvent?>> eventById(String id);

  Future<Result<void>> saveEvent(CalendarEvent event);

  Future<Result<void>> deleteEvent(String id);

  Future<Result<List<DayCell>>> allCells();

  Future<Result<DayCell?>> cellByDate(DateKey date);

  Future<Result<void>> saveCell(DayCell cell);

  Future<Result<void>> deleteCell(DateKey date);

  Future<Result<void>> clear();
}

/// 导出 / 导入使用的聚合快照。
final class CalendarSnapshot {
  const CalendarSnapshot({
    required this.events,
    required this.cells,
    required this.exportedAt,
  });

  final List<CalendarEvent> events;
  final List<DayCell> cells;
  final DateTime exportedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 1,
    'exportedAt': exportedAt.toIso8601String(),
    'events': events.map((CalendarEvent e) => e.toJson()).toList(),
    'cells': cells.map((DayCell c) => c.toJson()).toList(),
  };

  factory CalendarSnapshot.fromJson(Map<String, Object?> json) =>
      CalendarSnapshot(
        exportedAt:
            DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
            DateTime.now(),
        events: (json['events'] as List? ?? const <Object?>[])
            .map(
              (Object? e) =>
                  CalendarEvent.fromJson(Map<String, Object?>.from(e! as Map)),
            )
            .toList(),
        cells: (json['cells'] as List? ?? const <Object?>[])
            .map(
              (Object? c) =>
                  DayCell.fromJson(Map<String, Object?>.from(c! as Map)),
            )
            .toList(),
      );
}
