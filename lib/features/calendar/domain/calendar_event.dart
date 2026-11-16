/// 日历事件聚合根。
///
/// 一个事件 = 一条内容 + 一条重复规则 + 一组「按次」的完成 / 例外状态。
/// 旧版把「重复任务 / 提醒 / 倒数日 / 订阅推送」用同一个 `unionId` 建模，
/// 这里用 [CalendarEventType] 保留同样的分流逻辑。
library;

import 'package:core/domain.dart';

import '../../../core/app_events.dart';
import '../../../core/value_objects.dart';
import 'recurrence.dart';
import 'reminder_spec.dart';

enum CalendarEventType {
  task('重复任务', 1),
  reminder('提醒', 2),
  countdown('倒数纪念日', 3),
  subscription('订阅推送', 4);

  const CalendarEventType(this.label, this.legacyCode);

  final String label;
  final int legacyCode;

  static CalendarEventType fromName(String? name) =>
      CalendarEventType.values.firstWhere(
        (CalendarEventType t) => t.name == name,
        orElse: () => CalendarEventType.task,
      );
}

/// 重复事件删除三态（旧版 `仅删除当前 / 当前及未来 / 所有`）。
enum DeleteScope {
  current('仅删除当前事件'),
  currentAndFuture('删除当前及未来全部事件'),
  all('删除所有事件');

  const DeleteScope(this.label);

  final String label;
}

final class CalendarEvent extends AggregateRoot<String> {
  CalendarEvent._({
    required String id,
    required this.type,
    required this.content,
    required this.startDate,
    required this.color,
    required this.backgroundColor,
    required this.recurrence,
    required this.reminder,
    required this.completedDates,
    required this.excludedDates,
    required this.recurrenceUntil,
    required this.createdAt,
    required this.updatedAt,
    this.subscriptionId,
    this.source,
  }) : super(id);

  /// 创建聚合：记录过去式领域事件，由仓储在持久化成功后取走分发。
  factory CalendarEvent.create({
    required String id,
    required String content,
    required DateKey startDate,
    required DateTime occurredAt,
    CalendarEventType type = CalendarEventType.task,
    EventColor color = EventColor.defaultText,
    EventColor backgroundColor = EventColor.transparent,
    RecurrenceRule recurrence = const RecurrenceRule(),
    ReminderSpec? reminder,
    List<DateKey> completedDates = const <DateKey>[],
    List<DateKey> excludedDates = const <DateKey>[],
    DateKey? recurrenceUntil,
    String? subscriptionId,
    String? source,
  }) {
    final event = CalendarEvent._(
      id: id,
      type: type,
      content: content,
      startDate: startDate,
      color: color,
      backgroundColor: backgroundColor,
      recurrence: recurrence,
      reminder: reminder,
      completedDates: completedDates,
      excludedDates: excludedDates,
      recurrenceUntil: recurrenceUntil,
      createdAt: occurredAt,
      updatedAt: occurredAt,
      subscriptionId: subscriptionId,
      source: source,
    );
    event.raiseDomainEvent(
      CalendarEventCreated(
        aggregateId: id,
        occurredAt: occurredAt,
        date: startDate,
      ),
    );
    return event;
  }

  final CalendarEventType type;
  final String content;
  final DateKey startDate;
  final EventColor color;
  final EventColor backgroundColor;
  final RecurrenceRule recurrence;
  final ReminderSpec? reminder;
  final List<DateKey> completedDates;
  final List<DateKey> excludedDates;

  /// 「删除当前及未来」用截止日截断，而不是物理删除历史发生。
  final DateKey? recurrenceUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? subscriptionId;
  final String? source;

  bool isCompletedOn(DateKey date) => completedDates.contains(date);

  bool isExcludedOn(DateKey date) =>
      excludedDates.contains(date) ||
      (recurrenceUntil != null && date.differenceInDays(recurrenceUntil!) > 0);

  CalendarEvent changed({
    required DateTime occurredAt,
    String? content,
    DateKey? startDate,
    CalendarEventType? type,
    EventColor? color,
    EventColor? backgroundColor,
    RecurrenceRule? recurrence,
    ReminderSpec? reminder,
    List<DateKey>? completedDates,
    List<DateKey>? excludedDates,
    DateKey? recurrenceUntil,
    String? subscriptionId,
    String? source,
    bool clearReminder = false,
  }) {
    final event = CalendarEvent._(
      id: id,
      type: type ?? this.type,
      content: content ?? this.content,
      startDate: startDate ?? this.startDate,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      recurrence: recurrence ?? this.recurrence,
      reminder: clearReminder ? null : (reminder ?? this.reminder),
      completedDates: completedDates ?? this.completedDates,
      excludedDates: excludedDates ?? this.excludedDates,
      recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
      createdAt: createdAt,
      updatedAt: occurredAt,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      source: source ?? this.source,
    );
    event.raiseDomainEvent(
      CalendarEventChanged(
        aggregateId: id,
        occurredAt: occurredAt,
        date: event.startDate,
      ),
    );
    return event;
  }

  CalendarEvent markCompleted(DateKey date, bool value, DateTime occurredAt) {
    final next = List<DateKey>.of(completedDates);
    if (value) {
      if (!next.contains(date)) next.add(date);
    } else {
      next.remove(date);
    }
    return changed(completedDates: next, occurredAt: occurredAt);
  }

  /// 应用「仅删除当前事件」：把该次发生记为例外。
  CalendarEvent exclude(DateKey date, DateTime occurredAt) {
    if (excludedDates.contains(date)) return this;
    return changed(
      excludedDates: <DateKey>[...excludedDates, date],
      occurredAt: occurredAt,
    );
  }

  /// 应用「删除当前及未来」：截断重复序列。
  CalendarEvent truncateBefore(DateKey date, DateTime occurredAt) => changed(
        recurrenceUntil: date.addDays(-1),
        occurredAt: occurredAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type.name,
        'content': content,
        'startDate': startDate.key,
        'color': color.argb,
        'backgroundColor': backgroundColor.argb,
        'recurrence': recurrence.toJson(),
        'reminder': reminder?.toJson(),
        'completedDates': completedDates.map((DateKey d) => d.key).toList(),
        'excludedDates': excludedDates.map((DateKey d) => d.key).toList(),
        'recurrenceUntil': recurrenceUntil?.key,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'subscriptionId': subscriptionId,
        'source': source,
      };

  factory CalendarEvent.fromJson(Map<String, Object?> json) => CalendarEvent._(
        id: json['id'] as String,
        type: CalendarEventType.fromName(json['type'] as String?),
        content: json['content'] as String? ?? '',
        startDate: DateKey.parse(json['startDate']! as String),
        color: EventColor(json['color'] as int? ?? 0xFF1F2024),
        backgroundColor: EventColor(
          json['backgroundColor'] as int? ?? 0x00000000,
        ),
        recurrence: RecurrenceRule.fromJson(
          Map<String, Object?>.from(
            (json['recurrence'] as Map?) ?? const <String, Object?>{},
          ),
        ),
        reminder: json['reminder'] == null
            ? null
            : ReminderSpec.fromJson(
                Map<String, Object?>.from(json['reminder']! as Map),
              ),
        completedDates: (json['completedDates'] as List? ?? const <Object?>[])
            .map((Object? d) => DateKey.parse(d! as String))
            .toList(),
        excludedDates: (json['excludedDates'] as List? ?? const <Object?>[])
            .map((Object? d) => DateKey.parse(d! as String))
            .toList(),
        recurrenceUntil: json['recurrenceUntil'] == null
            ? null
            : DateKey.parse(json['recurrenceUntil']! as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        subscriptionId: json['subscriptionId'] as String?,
        source: json['source'] as String?,
      );
}
