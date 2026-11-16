/// 应用级领域事件。
///
/// 聚合只记录「已经发生的事实」，仓储在**持久化成功后** `pullDomainEvents()`
/// 并交给 `DomainEventBus` 分发；控制器通过订阅事件做跨上下文联动
/// （提醒重排、历史留痕、同步标记脏数据），不互相直接调用。
library;

import 'package:core/domain.dart';

import 'value_objects.dart';

/// 事件基类：统一带上聚合 id 与发生时刻。
abstract base class AppDomainEvent extends DomainEvent {
  const AppDomainEvent({
    required this.aggregateId,
    required super.occurredAt,
  });

  final String aggregateId;
}

final class CalendarEventCreated extends AppDomainEvent {
  const CalendarEventCreated({
    required super.aggregateId,
    required super.occurredAt,
    required this.date,
  });

  final DateKey date;
}

final class CalendarEventChanged extends AppDomainEvent {
  const CalendarEventChanged({
    required super.aggregateId,
    required super.occurredAt,
    required this.date,
  });

  final DateKey date;
}

final class CalendarEventRemoved extends AppDomainEvent {
  const CalendarEventRemoved({
    required super.aggregateId,
    required super.occurredAt,
  });
}

final class DayCellChanged extends AppDomainEvent {
  const DayCellChanged({
    required super.aggregateId,
    required super.occurredAt,
    required this.date,
    required this.snapshot,
  });

  final DateKey date;
  final String snapshot;
}

final class NoteChanged extends AppDomainEvent {
  const NoteChanged({
    required super.aggregateId,
    required super.occurredAt,
  });
}

final class NoteRemoved extends AppDomainEvent {
  const NoteRemoved({
    required super.aggregateId,
    required super.occurredAt,
  });
}

final class CountdownChanged extends AppDomainEvent {
  const CountdownChanged({
    required super.aggregateId,
    required super.occurredAt,
  });
}

final class CountdownRemoved extends AppDomainEvent {
  const CountdownRemoved({
    required super.aggregateId,
    required super.occurredAt,
  });
}

final class SettingsChanged extends AppDomainEvent {
  const SettingsChanged({
    required super.aggregateId,
    required super.occurredAt,
  });
}

final class ReminderFired extends AppDomainEvent {
  const ReminderFired({
    required super.aggregateId,
    required super.occurredAt,
    required this.title,
  });

  final String title;
}
