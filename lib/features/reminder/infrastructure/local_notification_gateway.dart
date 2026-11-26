/// `flutter_local_notifications` 适配器：把应用层的 [NotificationGateway]
/// 端口映射到 Windows / Linux / macOS 的本地通知实现。
library;

import 'dart:async';

import 'package:core/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/ports.dart';
import '../../../l10n/l10n.dart';

final class FlutterLocalNotificationsGateway implements NotificationGateway {
  FlutterLocalNotificationsGateway({
    required this.logger,
    required this.clock,
    this.locationName = 'Asia/Shanghai',
    AppLocalizationScope? localizationScope,
  }) : _localizationScope = localizationScope;

  final AppLogger logger;
  final Clock clock;
  final String locationName;
  final AppLocalizationScope? _localizationScope;
  AppLocalizations get _l10n =>
      _localizationScope?.localizations ??
      lookupAppLocalizations(const Locale('zh'));

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
        settings: InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(
            defaultActionName: _l10n.notificationOpenCalendar,
          ),
          windows: WindowsInitializationSettings(
            // Windows binds attribution at initialization; keep the brand stable
            // while notification titles and bodies are localized when scheduled.
            appName: 'Planstar',
            appUserModelId: 'Planstar.DesktopCalendar.App',
            guid: '6B8F1C42-9C34-4D2B-A2E7-9F1A0D5C7E31',
          ),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      _initialized = true;
      logger.info(_l10n.reminderLogInitialized);
    } catch (error, stackTrace) {
      // 桌面通知不可用时不能让应用起不来：应用内提醒弹窗仍可用。
      logger.warn(
        _l10n.reminderLogInitializeFailed,
        error: error,
        stackTrace: stackTrace,
      );
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
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'planstar_reminder',
            _l10n.notificationChannel,
            channelDescription: _l10n.notificationChannelDescription,
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
      (_idsByEvent.putIfAbsent(
        reminder.eventId,
        () => <int>{},
      )).add(reminder.notificationId);
    } catch (error) {
      logger.warn(
        _l10n.reminderLogScheduleFailed(reminder.eventId),
        error: error,
      );
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
        logger.warn(_l10n.reminderLogCancelFailed(id.toString()), error: error);
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
      logger.warn(_l10n.reminderLogClearFailed, error: error);
    }
  }
}
