library;

import 'dart:async';

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_models.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

final class AuthController extends Notifier<AuthState> {
  Timer? _cooldownTimer;
  bool _disposed = false;
  int _generation = 0;
  String? _activeSession;

  @override
  AuthState build() {
    final context = ref.watch(planstarRequestContextProvider);
    context.onUnauthorized = _handleUnauthorized;
    ref.onDispose(() {
      _disposed = true;
      _cooldownTimer?.cancel();
      if (identical(context.onUnauthorized, _handleUnauthorized)) {
        context.onUnauthorized = null;
      }
    });
    unawaited(_restore());
    return const AuthState();
  }

  Future<AuthFailure?> sendCode(String phone, {String? captcha}) async {
    if (!state.canSendCode) return null;
    final generation = _generation;
    state = state.copyWith(sendingCode: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .sendLoginCode(phone, captcha: captcha);
    if (!_isCurrent(generation)) return null;
    return result.fold(
      onFailure: (Failure failure) => _fail(failure, sendingCode: true),
      onSuccess: (SendCodeOutcome outcome) {
        state = state.copyWith(
          sendingCode: false,
          cooldownSeconds: outcome.cooldownSeconds,
        );
        _startCooldown();
        return null;
      },
    );
  }

  Future<AuthFailure?> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  }) => _login(
    () => ref
        .read(authRepositoryProvider)
        .loginWithCode(phone, code, captcha: captcha),
  );

  Future<AuthFailure?> loginWithPassword(
    String phone,
    String password, {
    String? captcha,
  }) => _login(
    () => ref
        .read(authRepositoryProvider)
        .loginWithPassword(phone, password, captcha: captcha),
  );

  Future<Result<List<int>>> fetchCaptcha() async {
    final generation = _generation;
    final result = await ref.read(authRepositoryProvider).fetchCaptchaImage();
    final failure = result.failure;
    if (failure != null && _isCurrent(generation)) {
      state = state.copyWith(failure: AuthFailure.fromFailure(failure));
    }
    return result;
  }

  Future<AuthFailure?> refreshProfile() async {
    if (!state.isLoggedIn || state.refreshingProfile) return null;
    final generation = _generation;
    final session = _activeSession;
    state = state.copyWith(refreshingProfile: true, clearFailure: true);
    final result = await ref.read(authRepositoryProvider).refreshProfile();
    if (!_isCurrent(generation, session)) return null;
    return result.fold(
      onFailure: (Failure failure) => _fail(failure, refreshingProfile: true),
      onSuccess: (AuthUser user) {
        state = state.copyWith(user: user, refreshingProfile: false);
        return null;
      },
    );
  }

  Future<AuthFailure?> signIn() async {
    if (!state.isLoggedIn || state.signingIn) return null;
    final generation = _generation;
    final session = _activeSession;
    state = state.copyWith(signingIn: true, clearFailure: true);
    final result = await ref.read(authRepositoryProvider).signIn();
    if (!_isCurrent(generation, session)) return null;
    return result.fold(
      onFailure: (Failure failure) => _fail(failure, signingIn: true),
      onSuccess: (SignInResult data) {
        state = state.copyWith(signingIn: false, signInResult: data);
        return null;
      },
    );
  }

  Future<void> logout() async {
    final generation = ++_generation;
    _activeSession = null;
    _cooldownTimer?.cancel();
    state = const AuthState(status: AuthStatus.guest);
    Object? failure;
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (error) {
      failure = error;
    }
    if (!_isCurrent(generation)) return;
    if (failure != null) {
      state = state.copyWith(
        failure: const AuthFailure(
          kind: AuthFailureKind.storage,
          code: 'AUTH_LOGOUT_FAILED',
          message: '',
        ),
      );
    }
  }

  void clearFailure() {
    if (state.failure != null) state = state.copyWith(clearFailure: true);
  }

  Future<AuthFailure?> _login(
    Future<Result<AuthSession>> Function() run,
  ) async {
    if (state.loggingIn) return null;
    final generation = ++_generation;
    _activeSession = null;
    state = state.copyWith(loggingIn: true, clearFailure: true);
    final result = await run();
    if (!_isCurrent(generation)) return null;
    return result.fold(
      onFailure: (Failure failure) => _fail(failure, loggingIn: true),
      onSuccess: (AuthSession session) {
        _activeSession = session.token;
        state = AuthState(
          status: AuthStatus.authenticated,
          user: session.user,
          isNewUser: session.isNewUser,
        );
        unawaited(_restoreSignInStatus());
        return null;
      },
    );
  }

  Future<void> _restore() async {
    final generation = ++_generation;
    _activeSession = null;
    final session = await ref.read(authRepositoryProvider).restoreSession();
    if (!_isCurrent(generation)) return;
    _activeSession = session?.token;
    state = session == null
        ? const AuthState(status: AuthStatus.guest)
        : AuthState(status: AuthStatus.authenticated, user: session.user);
    if (session != null) unawaited(_restoreSignInStatus());
  }

  Future<void> _restoreSignInStatus() async {
    if (!state.isLoggedIn) return;
    final generation = _generation;
    final session = _activeSession;
    final result = await ref.read(authRepositoryProvider).fetchSignInStatus();
    if (!_isCurrent(generation, session)) return;
    if (result case Success<SignInResult>(:final SignInResult data)) {
      state = state.copyWith(signInResult: data);
    }
  }

  bool _isCurrent(int generation, [String? session]) =>
      !_disposed &&
      generation == _generation &&
      (session == null || session == _activeSession);

  AuthFailure _fail(
    Failure failure, {
    bool sendingCode = false,
    bool loggingIn = false,
    bool refreshingProfile = false,
    bool signingIn = false,
  }) {
    final authFailure = AuthFailure.fromFailure(failure);
    state = state.copyWith(
      sendingCode: sendingCode ? false : null,
      loggingIn: loggingIn ? false : null,
      refreshingProfile: refreshingProfile ? false : null,
      signingIn: signingIn ? false : null,
      failure: authFailure,
    );
    return authFailure;
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_disposed) return timer.cancel();
      final next = state.cooldownSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(cooldownSeconds: 0);
      } else {
        state = state.copyWith(cooldownSeconds: next);
      }
    });
  }

  void _handleUnauthorized() {
    if (!_disposed && state.isLoggedIn) unawaited(logout());
  }
}
