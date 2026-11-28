import 'dart:convert';

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/features/auth/application/auth_providers.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_models.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_repository.dart';
import 'package:planstar_desktop_app/features/auth/presentation/login_page.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

final class _AuthRepository implements AuthRepository {
  String? captcha;
  int loginCalls = 0;
  int passwordLoginCalls = 0;
  String? lastPhone;
  String? lastPassword;
  int sendCalls = 0;
  bool requireCaptcha = false;
  bool requireLoginCaptcha = false;
  Failure? loginFailure;
  bool newUser = false;

  @override
  Future<Result<SendCodeOutcome>> sendLoginCode(
    String phone, {
    String? captcha,
  }) async {
    sendCalls++;
    this.captcha = captcha;
    if (requireCaptcha && captcha == null) {
      return const Fail<SendCodeOutcome>(
        Failure(
          code: 'AUTH_NEEDS_CAPTCHA',
          message: '请输入图形验证码',
          type: FailureType.validation,
        ),
      );
    }
    return const Success<SendCodeOutcome>(SendCodeOutcome());
  }

  @override
  Future<Result<AuthSession>> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  }) async {
    loginCalls++;
    this.captcha = captcha;
    if (loginFailure != null) return Fail<AuthSession>(loginFailure!);
    if (requireLoginCaptcha && captcha == null) {
      return const Fail<AuthSession>(
        Failure(
          code: 'AUTH_NEEDS_CAPTCHA',
          message: '请输入图形验证码',
          type: FailureType.validation,
        ),
      );
    }
    return Success<AuthSession>(
      AuthSession(
        user: AuthUser(userId: 42, userName: '用户'),
        token: 'token',
        isNewUser: newUser,
      ),
    );
  }

  @override
  Future<Result<AuthSession>> loginWithPassword(
    String phone,
    String password, {
    String? captcha,
  }) async {
    passwordLoginCalls++;
    loginCalls++;
    lastPhone = phone;
    lastPassword = password;
    this.captcha = captcha;
    if (loginFailure != null) return Fail<AuthSession>(loginFailure!);
    if (requireLoginCaptcha && captcha == null) {
      return const Fail<AuthSession>(
        Failure(
          code: 'AUTH_NEEDS_CAPTCHA',
          message: '请输入图形验证码',
          type: FailureType.validation,
        ),
      );
    }
    return Success<AuthSession>(
      AuthSession(
        user: AuthUser(userId: 42, userName: '用户'),
        token: 'token',
        isNewUser: newUser,
      ),
    );
  }

  @override
  Future<Result<List<int>>> fetchCaptchaImage() async => Success<List<int>>(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<Result<AuthUser>> refreshProfile() async => throw UnimplementedError();

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

Future<ProviderContainer> _pumpLogin(
  WidgetTester tester,
  _AuthRepository repository,
) async {
  final scope = AppLocalizationScope();
  addTearDown(scope.dispose);
  final router = GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginPage(),
      ),
      GoRoute(
        path: '/account',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('account-destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      appLocalizationScopeProvider.overrideWithValue(scope),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: scope.value,
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
  return container;
}

void main() {
  testWidgets('phone validation and agreement gate login', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository();
    final container = await _pumpLogin(tester, repository);
    final l10n = container.read(appLocalizationScopeProvider).localizations;

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
    expect(find.text(l10n.authPhoneInvalid), findsOneWidget);
    expect(repository.loginCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.phone')),
      '13800138000',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth.submit')));
    await tester.pump();
    expect(find.text(l10n.authAgreementRequired), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('successful login navigates to account and welcomes new users', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository()..newUser = true;
    final container = await _pumpLogin(tester, repository);
    final l10n = container.read(appLocalizationScopeProvider).localizations;

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
    expect(find.text('account-destination'), findsOneWidget);
    expect(find.text(l10n.authNewUserWelcome), findsOneWidget);
  });

  testWidgets('send-code captcha retry uses the entered captcha', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository()..requireCaptcha = true;
    final container = await _pumpLogin(tester, repository);
    final l10n = container.read(appLocalizationScopeProvider).localizations;
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.phone')),
      '13800138000',
    );
    await tester.pump();

    await tester.tap(find.text(l10n.authSendCode));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'ABCD');
    await tester.tap(find.text(l10n.authCaptchaConfirm));
    await tester.pumpAndSettle();
    expect(repository.captcha, 'ABCD');
    expect(repository.sendCalls, 2);
    expect(find.text(l10n.authCodeSent), findsOneWidget);
    expect(find.text(l10n.authResendCode(60)), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets('cancelling send-code captcha does not report success', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository()..requireCaptcha = true;
    final container = await _pumpLogin(tester, repository);
    final l10n = container.read(appLocalizationScopeProvider).localizations;
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.phone')),
      '13800138000',
    );
    await tester.pump();

    await tester.tap(find.text(l10n.authSendCode));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.authCaptchaCancel));
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 1);
    expect(find.text(l10n.authCodeSent), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('cancelling login captcha keeps the user on login page', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository()..requireLoginCaptcha = true;
    final container = await _pumpLogin(tester, repository);
    final l10n = container.read(appLocalizationScopeProvider).localizations;
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
    await tester.tap(find.text(l10n.authCaptchaCancel));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(find.text('account-destination'), findsNothing);
    expect(find.byKey(const ValueKey<String>('auth.submit')), findsOneWidget);
  });

  testWidgets('login 401 shows the server credential error', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository()
      ..loginFailure = const Failure(
        code: 'AUTH_INVALID_CREDENTIAL',
        message: '验证码错误',
        type: FailureType.authentication,
        statusCode: 401,
      );
    final container = await _pumpLogin(tester, repository);
    final l10n = container.read(appLocalizationScopeProvider).localizations;
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

    expect(find.text('验证码错误'), findsOneWidget);
    expect(find.text(l10n.authSessionExpired), findsNothing);
    expect(find.text('account-destination'), findsNothing);
  });

  testWidgets('password mode validates and submits the password contract', (
    WidgetTester tester,
  ) async {
    final repository = _AuthRepository();
    final container = await _pumpLogin(tester, repository);
    final l10n = container.read(appLocalizationScopeProvider).localizations;

    await tester.tap(find.text(l10n.authSwitchToPassword));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth.password')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('auth.code')), findsNothing);
    expect(find.text(l10n.authSwitchToCode), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.phone')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.password')),
      'short',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth.agreement')));
    await tester.tap(find.byKey(const ValueKey<String>('auth.submit')));
    await tester.pump();
    expect(find.text(l10n.authPasswordInvalid), findsOneWidget);
    expect(repository.passwordLoginCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth.password')),
      'secret123',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth.submit')));
    await tester.pumpAndSettle();
    expect(repository.passwordLoginCalls, 1);
    expect(repository.lastPhone, '13800138000');
    expect(repository.lastPassword, 'secret123');
    expect(repository.captcha, isNull);
    expect(find.text('account-destination'), findsOneWidget);
  });
}
