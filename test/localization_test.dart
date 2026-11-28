import 'dart:convert';

import 'package:core/domain.dart';
import 'package:core/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/calendar/domain/calendar_event.dart';
import 'package:planstar_desktop_app/features/calendar/domain/recurrence.dart';
import 'package:planstar_desktop_app/features/countdown/domain/countdown.dart';
import 'package:planstar_desktop_app/features/notes/application/notes_controller.dart';
import 'package:planstar_desktop_app/features/notes/domain/note.dart';
import 'package:planstar_desktop_app/features/timetable/domain/timetable.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';
import 'package:planstar_desktop_app/shared/widgets/common.dart';

void _ignoreColor(EventColor _) {}

void main() {
  setUpAll(initializeDateFormatting);

  test('legacy and regional language codes map to supported locales', () {
    expect(localeForLanguage(null), const Locale('zh'));
    expect(localeForLanguage('zh_CN'), const Locale('zh'));
    expect(localeForLanguage('zh_TW'), const Locale('zh'));
    expect(localeForLanguage('en'), const Locale('en'));
    expect(localeForLanguage('en_US'), const Locale('en'));
    expect(localeForLanguage('en_GB'), const Locale('en'));
  });

  test('localization scope switches generated resources and notifies', () {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    var notifications = 0;
    scope.addListener(() => notifications++);

    expect(scope.localizations.appTitle, '企划星 · 桌面日历清单');
    scope.setLanguage('en_US');
    expect(scope.value, const Locale('en'));
    expect(
      scope.localizations.appTitle,
      'Planstar · Desktop Calendar & Checklist',
    );
    expect(notifications, 1);

    scope.setLanguage('zh');
    expect(scope.localizations.appTitle, '企划星 · 桌面日历清单');
    expect(notifications, 2);
  });

  test('generated delegate loads both locales with plural resources', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(zh.calendarEventTypeTask, '重复任务');
    expect(en.calendarEventTypeTask, 'Recurring task');
    expect(zh.accountPendingChanges(0), '没有待同步变更');
    expect(en.accountPendingChanges(0), 'No pending changes');
    expect(en.accountPendingChanges(2), '2 pending changes');
    expect(en.languageChinese, 'Chinese (Simplified)');
  });

  test('domain labels and dates use the active language', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final date = DateKey(DateTime(2026, 11, 26));

    expect(CalendarEventType.reminder.localizedLabel(en), 'Reminder');
    expect(RecurrenceKind.daily.localizedLabel(en), 'Repeat daily');
    expect(date.fullDate(en), 'November 26, 2026');
    expect(CalendarEventType.reminder.name, 'reminder');
  });

  test('countdown status uses ICU plural resources', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final item = CountdownItem.create(
      id: 'countdown-1',
      title: 'Launch',
      type: CountdownType.custom,
      targetDate: DateKey(DateTime(2026, 11, 30)),
      occurredAt: DateTime(2026, 11, 26),
    );

    expect(
      item.localizedDisplayText(en, DateKey(DateTime(2026, 11, 26))),
      '4 days remaining',
    );
    expect(
      item.localizedDisplayText(en, DateKey(DateTime(2026, 11, 30))),
      'Today',
    );
    expect(
      item.localizedDisplayText(en, DateKey(DateTime(2026, 12, 2))),
      'Expired 2 days ago',
    );
  });

  test('legacy defaults and color labels preserve user data', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final date = DateKey(DateTime(2026, 11, 26));
    final legacy = Timetable.create(
      id: 'legacy',
      name: '新建课程表',
      startDate: date,
    );
    final custom = Timetable.create(
      id: 'custom',
      name: 'My timetable',
      startDate: date,
    );

    expect(legacy.localizedName(en), 'New timetable');
    expect(custom.localizedName(en), 'My timetable');
    final emptyNote = Note.create(
      id: 'empty-note',
      title: '',
      occurredAt: DateTime(2026, 11, 26),
    );
    final legacyNote = Note.create(
      id: 'legacy-note',
      occurredAt: DateTime(2026, 11, 26),
      title: '新建便签',
    );
    final customNote = Note.create(
      id: 'custom-note',
      occurredAt: DateTime(2026, 11, 26),
      title: 'My note',
    );
    expect(emptyNote.localizedTitle(en), 'New note');
    expect(legacyNote.localizedTitle(en), 'New note');
    expect(customNote.localizedTitle(en), 'My note');
    expect(
      const EventColor(0xFFE54545).localizedLabel(en, purpose: 'Cell color'),
      'Cell color #E54545',
    );
    expect(EventColor.transparent.localizedLabel(en), 'Transparent');
  });

  test(
    'new notes persist an empty title and localize only for display',
    () async {
      final scope = AppLocalizationScope();
      addTearDown(scope.dispose);
      final store = MemoryKeyValueStore();
      final container = ProviderContainer(
        overrides: [
          appLocalizationScopeProvider.overrideWithValue(scope),
          keyValueStoreProvider.overrideWithValue(store),
          domainEventBusProvider.overrideWithValue(DomainEventBus()),
        ],
      );
      addTearDown(container.dispose);

      final note = await container
          .read(notesControllerProvider.notifier)
          .create();
      expect(note, isNotNull);
      expect(note!.title, isEmpty);
      expect(note.localizedTitle(scope.localizations), '新建便签');

      final persisted =
          jsonDecode((await store.read('planstar.notes.v1'))!) as List;
      expect((persisted.single as Map<String, Object?>)['title'], isEmpty);
      scope.setLanguage('en');
      expect(note.localizedTitle(scope.localizations), 'New note');
      expect(note.title, isEmpty);
    },
  );

  testWidgets('color swatches expose localized semantic labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: supportedLocales,
          home: const Scaffold(
            body: ColorSwatchPicker(
              selected: EventColor.transparent,
              onSelected: _ignoreColor,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Transparent'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Text color / cell color #E54545'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('MaterialApp follows localization scope changes', (tester) async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
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
          home: Builder(builder: (context) => Text(context.l10n.appTitle)),
        ),
      ),
    );

    expect(find.text('企划星 · 桌面日历清单'), findsOneWidget);
    scope.setLanguage('en');
    await tester.pumpAndSettle();
    expect(
      find.text('Planstar · Desktop Calendar & Checklist'),
      findsOneWidget,
    );
  });
}
