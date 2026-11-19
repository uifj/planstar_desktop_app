/// 本地通知端口。
library;

import 'dart:async';

/// 一条待投递的本地通知。
final class ScheduledReminder {
  const ScheduledReminder({
    required this.notificationId,
    required this.eventId,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.payload,
  });

  final int notificationId;
  final String eventId;
  final String title;
  final String body;
  final DateTime fireAt;

  /// 点击通知时回传的数据（通常是 `eventId|date`）。
  final String payload;
}

abstract interface class NotificationGateway {
  Future<void> initialize();

  Future<void> schedule(ScheduledReminder reminder);

  Future<void> cancelForEvent(String eventId);

  Future<void> cancelAll();

  /// 点击通知 / 前台收到提醒时发出的 eventId 流，用于弹置顶提醒窗。
  Stream<String> get activations;
}
