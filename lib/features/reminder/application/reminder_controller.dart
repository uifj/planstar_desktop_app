/// 提醒调度应用服务：领域事件 → 重排本地通知；通知点击 → 应用内置顶弹窗。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../calendar/application/calendar_controller.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../calendar/domain/recurrence_policy.dart';
import '../../settings/application/settings_controller.dart';

final class ReminderAlert {
  const ReminderAlert({
    required this.eventId,
    required this.title,
    required this.date,
  });

  final String eventId;
  final String title;
  final DateKey date;
}

final class ReminderState {
  const ReminderState({this.alert, this.scheduled = 0, this.message});

  final ReminderAlert? alert;
  final int scheduled;
  final String? message;

  ReminderState copyWith({
    ReminderAlert? alert,
    int? scheduled,
    String? message,
    bool clearAlert = false,
    bool clearMessage = false,
  }) => ReminderState(
    alert: clearAlert ? null : (alert ?? this.alert),
    scheduled: scheduled ?? this.scheduled,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderState>(ReminderController.new);

final class ReminderController extends Notifier<ReminderState> {
  @override
  ReminderState build() {
    // 仅由应用根 ref.read，需保活以持续接收领域事件与通知点击。
    ref.keepAlive();
    final bus = ref.read(domainEventBusProvider);
    bus.on<CalendarEventCreated>(_onChanged);
    bus.on<CalendarEventChanged>(_onChanged);
    bus.on<CalendarEventRemoved>(_onChanged);
    bus.on<SettingsChanged>(_onChanged);
    bus.on<CrossEngineDataChanged>(_onChanged);

    final gateway = ref.read(notificationGatewayProvider);
    gateway.activations.listen(_onActivation);
    Future.microtask(rescheduleAll);
    return const ReminderState();
  }

  Future<void> _onChanged(DomainEvent event) => rescheduleAll();

  void _onActivation(String payload) {
    final parts = payload.split('|');
    final eventId = parts.first;
    var title = '任务提醒';
    var dateKey = DateKey.today(ref.read(clockProvider).now()).key;
    if (parts.length > 1) dateKey = parts[1];
    final events = ref.read(calendarControllerProvider).events;
    for (final event in events) {
      if (event.id == eventId) {
        title = event.content;
        break;
      }
    }
    state = state.copyWith(
      alert: ReminderAlert(
        eventId: eventId,
        title: title,
        date: DateKey.parse(dateKey),
      ),
    );
    final tone = ref.read(settingsControllerProvider).reminderTone;
    ref.read(soundGatewayProvider).play(tone);
  }

  /// 重新计算未来 90 天内所有提醒，先清后建（旧版无重复通知能力，逐条调度）。
  Future<void> rescheduleAll() async {
    final gateway = ref.read(notificationGatewayProvider);
    await gateway.cancelAll();
    final events = await ref.read(calendarRepositoryProvider).allEvents();
    if (events case Fail<List<CalendarEvent>>(:final Failure failure)) {
      state = state.copyWith(message: failure.message);
      return;
    }
    final today = DateKey.today(ref.read(clockProvider).now());
    final range = DateRange(today, today.addDays(90));
    var count = 0;
    for (final event in events.requireData) {
      final spec = event.reminder;
      if (spec == null) continue;
      for (final occurrence in RecurrencePolicy.occurrences(event, range)) {
        for (final fireAt in spec.fireTimesFor(occurrence)) {
          await gateway.schedule(
            ScheduledReminder(
              notificationId: _notificationId(event.id, fireAt),
              eventId: event.id,
              title: event.content,
              body: '${occurrence.cnFull} ${spec.timeLabel}',
              fireAt: fireAt,
              payload: '${event.id}|${occurrence.key}',
            ),
          );
          count++;
        }
      }
    }
    state = state.copyWith(scheduled: count, clearMessage: true);
  }

  int _notificationId(String eventId, DateTime fireAt) {
    final hash = '$eventId${fireAt.millisecondsSinceEpoch}'.codeUnits.fold<int>(
      0,
      (int acc, int c) => (acc * 31 + c) & 0x3FFFFFFF,
    );
    return 100000 + hash % 900000;
  }

  void dismiss() => state = state.copyWith(clearAlert: true);

  void showTestAlert() => _onActivation(
    'preview|${DateKey.today(ref.read(clockProvider).now()).key}',
  );
}
