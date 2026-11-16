/// `flutter_local_notifications` 适配器：把应用层的 [NotificationGateway]
/// 端口映射到 Windows / Linux / macOS 的本地通知实现。
library;

import 'dart:async';

import 'package:core/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/ports.dart';

final class FlutterLocalNotificationsGateway implements NotificationGateway {
  FlutterLocalNotificationsGateway({
    required this.logger,
    required this.clock,
    this.locationName = 'Asia/Shanghai',
  });

  final AppLogger logger;
  final Clock clock;
  final String locationName;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _activations =
      StreamController<String>.broadcast();
  final Map<String, Set<int>> _idsByEvent = <String, Set<int>>{};

  bool _initialized = false;

  @override
  Stream<String> get activations => _activations.stream;

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(locationName));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: '打开日历'),
          windows: WindowsInitializationSettings(
            appName: '企划星桌面日历',
            appUserModelId: 'Planstar.DesktopCalendar.App',
            guid: '6B8F1C42-9C34-4D2B-A2E7-9F1A0D5C7E31',
          ),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      _initialized = true;
      logger.info('本地通知插件初始化完成');
    } catch (error, stackTrace) {
      // 桌面通知不可用时不能让应用起不来：应用内提醒弹窗仍可用。
      logger.warn('本地通知初始化失败，改用应用内提醒',
          error: error, stackTrace: stackTrace);
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _activations.add(payload);
    }
  }

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    if (!_initialized) return;
    if (reminder.fireAt.isBefore(clock.now())) {
      // 已经过期的提醒不进系统调度队列，由应用内「过期提醒」列表呈现。
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'planstar_reminder',
            '任务提醒',
            channelDescription: '日历清单任务提醒',
            importance: Importance.max,
            priority: Priority.high,
          ),
          windows: WindowsNotificationDetails(
            duration: WindowsNotificationDuration.long,
            scenario: WindowsNotificationScenario.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminder.payload,
      );
      (_idsByEvent.putIfAbsent(reminder.eventId, () => <int>{}))
          .add(reminder.notificationId);
    } catch (error) {
      logger.warn('提醒调度失败：${reminder.eventId}', error: error);
    }
  }

  @override
  Future<void> cancelForEvent(String eventId) async {
    if (!_initialized) return;
    final ids = _idsByEvent.remove(eventId);
    if (ids == null) return;
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (error) {
        logger.warn('取消提醒失败：$id', error: error);
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      _idsByEvent.clear();
    } catch (error) {
      logger.warn('清空提醒失败', error: error);
    }
  }
}
