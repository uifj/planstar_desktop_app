import 'dart:async';

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/calendar/application/calendar_controllers.dart';
import 'package:planstar_desktop_app/features/calendar/domain/calendar_event.dart';
import 'package:planstar_desktop_app/features/calendar/domain/day_cell.dart';
import 'package:planstar_desktop_app/features/calendar/domain/reminder_spec.dart';
import 'package:planstar_desktop_app/features/calendar/domain/repositories.dart';
import 'package:planstar_desktop_app/features/reminder/application/reminder_controller.dart';
import 'package:planstar_desktop_app/features/reminder/presentation/reminder_overlay.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

final class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

final class _CalendarRepository implements CalendarRepository {
  _CalendarRepository(this.events);

  final List<CalendarEvent> events;

  @override
  Future<Result<List<CalendarEvent>>> allEvents() async => Success(events);

  @override
  Future<Result<List<DayCell>>> allCells() async => const Success(<DayCell>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _NotificationGateway implements NotificationGateway {
  _NotificationGateway({this.blockFirstCancel = false});

  final bool blockFirstCancel;
  final firstCancel = Completer<void>();
  final secondScheduled = Completer<void>();
  final activationController = StreamController<String>.broadcast();
  final scheduled = <ScheduledReminder>[];
  final operations = <String>[];
  int cancelCalls = 0;

  @override
  Stream<String> get activations => activationController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    operations.add('schedule:${reminder.body}');
    scheduled.add(reminder);
    if (scheduled.length == 2 && !secondScheduled.isCompleted) {
      secondScheduled.complete();
    }
  }

  @override
  Future<void> cancelForEvent(String eventId) async {}

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    operations.add('cancel:$cancelCalls:start');
    if (blockFirstCancel && cancelCalls == 1) await firstCancel.future;
    operations.add('cancel:$cancelCalls:end');
  }

  Future<void> close() => activationController.close();
}

final class _SoundGateway implements SoundGateway {
  @override
  Future<void> play(SoundTone tone) async {}
}

ProviderContainer _createContainer(
  AppLocalizationScope scope,
  _NotificationGateway gateway, {
  List<CalendarEvent> events = const <CalendarEvent>[],
}) {
  final container = ProviderContainer(
    overrides: [
      appLocalizationScopeProvider.overrideWithValue(scope),
      clockProvider.overrideWithValue(_FixedClock(DateTime(2026, 11, 26, 12))),
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      domainEventBusProvider.overrideWithValue(DomainEventBus()),
      notificationGatewayProvider.overrideWithValue(gateway),
      soundGatewayProvider.overrideWithValue(_SoundGateway()),
      calendarRepositoryProvider.overrideWithValue(_CalendarRepository(events)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(() => unawaited(gateway.close()));
  return container;
}

CalendarEvent _event() => CalendarEvent.create(
  id: 'event-1',
  content: '用户事件标题',
  startDate: DateKey(DateTime(2026, 11, 27)),
  occurredAt: DateTime(2026, 11, 26, 12),
  reminder: const ReminderSpec(hour: 9, minute: 0),
);

Widget _reminderApp(ProviderContainer container, AppLocalizationScope scope) =>
    UncontrolledProviderScope(
      container: container,
      child: ValueListenableBuilder<Locale>(
        valueListenable: scope,
        builder: (context, locale, child) => MaterialApp(
          locale: locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: Stack(children: <Widget>[ReminderOverlay()]),
          ),
        ),
      ),
    );

Widget _reminderBuilderApp(
  ProviderContainer container,
  AppLocalizationScope scope,
) =>
    UncontrolledProviderScope(
      container: container,
      child: ValueListenableBuilder<Locale>(
        valueListenable: scope,
        builder: (context, locale, child) => MaterialApp(
          locale: locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (BuildContext context, Widget? child) => Stack(
            children: <Widget>[?child, const ReminderOverlayHost()],
          ),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

void main() {
  setUpAll(initializeDateFormatting);

  test(
    'reminder rescheduling is serialized so the newest locale wins',
    () async {
      final scope = AppLocalizationScope();
      addTearDown(scope.dispose);
      final gateway = _NotificationGateway(blockFirstCancel: true);
      addTearDown(() {
        if (!gateway.firstCancel.isCompleted) gateway.firstCancel.complete();
      });
      final container = _createContainer(scope, gateway, events: [_event()]);
      container.read(reminderControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.cancelCalls, 1);

      scope.setLanguage('en');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.cancelCalls, 1);

      gateway.firstCancel.complete();
      await gateway.secondScheduled.future;
      await Future<void>.delayed(Duration.zero);

      final en = scope.localizations;
      final date = DateKey(DateTime(2026, 11, 27));
      expect(gateway.scheduled, hasLength(2));
      expect(
        gateway.scheduled.last.body,
        en.reminderNotificationBody(date.fullDate(en), '09:00'),
      );
      expect(
        gateway.operations.last,
        'schedule:${en.reminderNotificationBody(date.fullDate(en), '09:00')}',
      );
      expect(container.read(reminderControllerProvider).scheduled, 1);
    },
  );

  testWidgets('missing-event reminder fallback follows locale changes', (
    tester,
  ) async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final gateway = _NotificationGateway();
    final container = _createContainer(scope, gateway);
    container.read(reminderControllerProvider);
    await container.read(reminderControllerProvider.notifier).rescheduleAll();
    container.read(reminderControllerProvider.notifier).showTestAlert();

    await tester.pumpWidget(_reminderApp(container, scope));
    expect(find.text(scope.localizations.reminderTaskTitle), findsNWidgets(2));

    scope.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text(scope.localizations.reminderTaskTitle), findsNWidgets(2));
    expect(find.text('提醒事项'), findsNothing);
  });

  testWidgets('reminder overlay supports MaterialApp builder hosting', (
    tester,
  ) async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final gateway = _NotificationGateway();
    final container = _createContainer(scope, gateway);
    container.read(reminderControllerProvider);
    container.read(reminderControllerProvider.notifier).showTestAlert();

    await tester.pumpWidget(_reminderBuilderApp(container, scope));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(scope.localizations.reminderTaskTitle), findsNWidgets(2));
  });

  testWidgets('event titles remain user content when locale changes', (
    tester,
  ) async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final gateway = _NotificationGateway();
    final container = _createContainer(scope, gateway, events: [_event()]);
    container.read(reminderControllerProvider);
    await container.read(calendarControllerProvider.notifier).load();
    gateway.activationController.add('event-1|2026-11-27');
    await tester.pump();

    await tester.pumpWidget(_reminderApp(container, scope));
    expect(find.text('用户事件标题'), findsOneWidget);

    scope.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('用户事件标题'), findsOneWidget);
    expect(container.read(reminderControllerProvider).alert?.title, '用户事件标题');
  });
}
