import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:planstar_desktop_app/bootstrap/bootstrap.dart';
import 'package:planstar_desktop_app/features/auth/presentation/login_page.dart';
import 'package:planstar_desktop_app/features/catalog/presentation/project_detail_page.dart';
import 'package:planstar_desktop_app/features/desktop/application/desktop_controller.dart';
import 'package:planstar_desktop_app/features/project_idea/presentation/project_idea_detail_page.dart';
import 'package:planstar_desktop_app/features/settings/application/settings_controller.dart';
import 'package:planstar_desktop_app/features/settings/domain/app_settings.dart';
import 'package:planstar_desktop_app/features/settings/infrastructure/settings_repository.dart';
import 'package:planstar_desktop_app/infrastructure/data_hub.dart';

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}

Future<void> main([List<String> args = const <String>[]]) async {
  if (args.isNotEmpty && args.first == 'multi_window') {
    await AppBootstrap.run(args);
    return;
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live catalog, ideas, and guest login work in the desktop shell',
    (WidgetTester tester) async {
      await AppBootstrap.run(const <String>[]);
      await _waitFor(tester, find.text('日历'));
      final container = ProviderScope.containerOf(
        tester.element(find.text('日历').first),
      );
      for (var attempt = 0; attempt < 80; attempt++) {
        if (container.read(desktopControllerProvider).widgetActive) break;
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(container.read(desktopControllerProvider).widgetActive, isTrue);
      final windows = await WindowController.getAll();
      final desktopWindows = windows
          .where((WindowController window) {
            if (window.arguments.trim().isEmpty) return false;
            final arguments =
                jsonDecode(window.arguments) as Map<String, Object?>;
            return arguments['kind'] == 'desktop';
          })
          .toList(growable: false);
      expect(desktopWindows, hasLength(1));

      await tester.tap(find.text('企划库'));
      await _waitFor(
        tester,
        find.byKey(const ValueKey<String>('project-card-9001')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('project-card-9001')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey<String>('project-detail-9001')),
      );
      expect(find.byType(ProjectDetailPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('早期共建者'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('早期共建者'), findsOneWidget);
      expect(find.text('开发者版'), findsOneWidget);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('企划'));
      await _waitFor(tester, find.byKey(const ValueKey<String>('idea-card-1')));
      await tester.tap(find.byKey(const ValueKey<String>('idea-card-1')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey<String>('idea-detail-1')),
      );
      expect(find.byType(ProjectIdeaDetailPage), findsOneWidget);
      expect(find.textContaining('玩家接手一间开在老街尽头的深夜食堂'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('idea-support')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth.phone')),
        '123',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth.code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey<String>('auth.submit')));
      await tester.pump();
      expect(find.text('请输入有效的 11 位手机号'), findsOneWidget);

      GoRouter.of(tester.element(find.byType(LoginPage))).go('/calendar');
      await tester.pumpAndSettle();
      expect(find.text('日历'), findsWidgets);

      final controller = container.read(settingsControllerProvider.notifier);
      final original = container.read(settingsControllerProvider);
      final changed = original.copyWith(
        maxRows: original.maxRows == AppSettings.defaults.maxRows ? 7 : 6,
      );
      final support = await getApplicationSupportDirectory();
      final settingsFile = File('${support.path}/$dataHubFileName');
      try {
        expect((await controller.update((_) => changed)).isSuccess, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final persisted =
            jsonDecode(await settingsFile.readAsString())
                as Map<String, Object?>;
        final entries = persisted['entries'] as Map<String, Object?>;
        final stored =
            jsonDecode(entries[LocalSettingsRepository.key]! as String)
                as Map<String, Object?>;
        expect(stored['maxRows'], changed.maxRows);
      } finally {
        expect((await controller.update((_) => original)).isSuccess, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final restored =
          jsonDecode(await settingsFile.readAsString()) as Map<String, Object?>;
      final restoredEntries = restored['entries'] as Map<String, Object?>;
      final restoredSettings =
          jsonDecode(restoredEntries[LocalSettingsRepository.key]! as String)
              as Map<String, Object?>;
      expect(restoredSettings['maxRows'], original.maxRows);
    },
  );
}
