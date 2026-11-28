import 'dart:io';

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/features/auth/application/auth_providers.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_models.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_repository.dart';
import 'package:planstar_desktop_app/features/auth/presentation/login_page.dart';
import 'package:planstar_desktop_app/features/sync/presentation/account_page.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

final class _AuthRepository implements AuthRepository {
  static const user = AuthUser(userId: 42, userName: '集成测试用户');

  int loginCalls = 0;
  int logoutCalls = 0;
  AuthSession? session;

  @override
  Future<Result<SendCodeOutcome>> sendLoginCode(
    String phone, {
    String? captcha,
  }) async => const Success<SendCodeOutcome>(SendCodeOutcome());

  @override
  Future<Result<AuthSession>> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  }) async {
    loginCalls++;
    session = AuthSession(user: user, token: 'integration-token');
    return Success<AuthSession>(session!);
  }

  @override
  Future<Result<AuthSession>> loginWithPassword(
    String phone,
    String password, {
    String? captcha,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<int>>> fetchCaptchaImage() async =>
      throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<void> logout() async {
    logoutCalls++;
    session = null;
  }

  @override
  Future<Result<AuthUser>> refreshProfile() async =>
      const Success<AuthUser>(user);

  @override
  Future<Result<SignInResult>> fetchSignInStatus() async =>
      const Success<SignInResult>(
        SignInResult(
          signed: false,
          todayReward: 0,
          balance: Money.zero(),
          alreadySigned: false,
        ),
      );

  @override
  Future<Result<SignInResult>> signIn() async => throw UnimplementedError();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeDateFormatting);

  testWidgets('guest account opens login and restores profile after logout', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository();
    final localizationScope = AppLocalizationScope();
    final router = GoRouter(
      initialLocation: '/account',
      routes: <RouteBase>[
        GoRoute(
          path: '/account',
          builder: (_, _) => const Scaffold(body: AccountPage()),
        ),
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(localizationScope),
        authRepositoryProvider.overrideWithValue(repository),
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secureStoreProvider.overrideWithValue(MemorySecureStore()),
        domainEventBusProvider.overrideWithValue(DomainEventBus()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    addTearDown(localizationScope.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: localizationScope.value,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedLocales,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = localizationScope.localizations;
    expect(find.text(l10n.accountLoginOrRegister), findsOneWidget);
    await tester.tap(find.text(l10n.accountLoginOrRegister));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('auth.phone')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('auth.code')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('auth.agreement')),
      findsOneWidget,
    );
    await _holdForCapture('LOGIN');

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.phone')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.code')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth.agreement')));
    await tester.tap(find.byKey(const ValueKey<String>('auth.submit')));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(find.text(_AuthRepository.user.displayName), findsOneWidget);
    expect(find.text(l10n.accountCloudSyncTitle), findsOneWidget);
    await _holdForCapture('ACCOUNT');

    await tester.tap(find.text(l10n.accountLogout));
    await tester.pumpAndSettle();
    expect(repository.logoutCalls, 1);
    expect(find.text(l10n.accountLoginOrRegister), findsOneWidget);
  });
}

Future<void> _holdForCapture(String name) async {
  if (!Platform.environment.containsKey('PLANSTAR_CAPTURE_DIR')) return;
  debugPrint('CAPTURE_$name');
  await Future<void>.delayed(const Duration(seconds: 2));
}
