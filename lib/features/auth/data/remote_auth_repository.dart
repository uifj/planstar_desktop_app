library;

import 'dart:convert';

import 'package:core/result.dart';
import 'package:dio/dio.dart';

import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import '../network/planstar_request_context.dart';
import 'auth_session_store.dart';
import 'planstar_account_api.dart';

final class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required PlanstarAccountApi api,
    required AuthSessionStore store,
    required PlanstarRequestContext context,
  }) : _api = api,
       _store = store,
       _context = context;

  final PlanstarAccountApi _api;
  final AuthSessionStore _store;
  final PlanstarRequestContext _context;

  @override
  Future<Result<SendCodeOutcome>> sendLoginCode(
    String phone, {
    String? captcha,
  }) async {
    final result = await _api.sendLoginCode(phone: phone, captcha: captcha);
    return result.fold(
      onFailure: (Failure failure) =>
          Fail<SendCodeOutcome>(_transportFailure(failure)),
      onSuccess: (SendCodeResponse response) {
        if (response.success) {
          return const Success<SendCodeOutcome>(SendCodeOutcome());
        }
        if (response.needCaptcha) {
          return Fail<SendCodeOutcome>(
            _failure(
              AuthFailureKind.needsCaptcha,
              response.errorMsg ?? 'AUTH_NEEDS_CAPTCHA',
              code: 'AUTH_NEEDS_CAPTCHA',
            ),
          );
        }
        return Fail<SendCodeOutcome>(
          _failure(
            AuthFailureKind.business,
            response.errorMsg ?? 'AUTH_SEND_CODE_FAILED',
            code: 'AUTH_BUSINESS',
          ),
        );
      },
    );
  }

  @override
  Future<Result<AuthSession>> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  }) => _login(phone: phone, code: code, captcha: captcha);

  @override
  Future<Result<AuthSession>> loginWithPassword(
    String phone,
    String password, {
    String? captcha,
  }) => _login(phone: phone, password: password, captcha: captcha);

  @override
  Future<Result<List<int>>> fetchCaptchaImage() async {
    final result = await _api.fetchCaptchaImage();
    return result.fold(
      onFailure: (Failure failure) =>
          Fail<List<int>>(_transportFailure(failure)),
      onSuccess: (List<int> bytes) => bytes.isEmpty
          ? Fail<List<int>>(
              _failure(
                AuthFailureKind.unknown,
                'AUTH_CAPTCHA_EMPTY',
                code: 'AUTH_CAPTCHA_EMPTY',
              ),
            )
          : Success<List<int>>(bytes),
    );
  }

  @override
  Future<AuthSession?> restoreSession() => _store.read();

  @override
  Future<void> logout() => _store.clear();

  @override
  Future<Result<AuthUser>> refreshProfile() async {
    final revision = _store.mutationRevision;
    final session = _context.psSession;
    if (session == null || session.isEmpty) {
      return Fail<AuthUser>(_sessionChangedFailure());
    }
    final result = await _api.fetchProfile();
    return result.fold(
      onFailure: (Failure failure) =>
          Fail<AuthUser>(_transportFailure(failure)),
      onSuccess: (AuthUser user) async {
        if (_store.mutationRevision != revision ||
            _context.psSession != session) {
          _restoreActiveContext();
          return Fail<AuthUser>(_sessionChangedFailure());
        }
        if (!user.isValid) {
          return Fail<AuthUser>(
            _failure(
              AuthFailureKind.unknown,
              'AUTH_NO_USER',
              code: 'AUTH_NO_USER',
            ),
          );
        }
        try {
          await _store.writeProfile(
            user,
            expectedSession: session,
            expectedRevision: revision,
          );
        } catch (_) {
          if (_store.mutationRevision != revision ||
              _context.psSession != session) {
            _restoreActiveContext();
            return Fail<AuthUser>(_sessionChangedFailure());
          }
          return Fail<AuthUser>(
            _failure(
              AuthFailureKind.storage,
              'AUTH_SESSION_WRITE_FAILED',
              code: 'AUTH_SESSION_WRITE_FAILED',
            ),
          );
        }
        return Success<AuthUser>(user);
      },
    );
  }

  @override
  Future<Result<SignInResult>> fetchSignInStatus() async {
    final result = await _api.fetchSignInStatus();
    return result.fold(
      onFailure: (Failure failure) =>
          Fail<SignInResult>(_transportFailure(failure)),
      onSuccess: (SignInResult data) => Success<SignInResult>(data),
    );
  }

  @override
  Future<Result<SignInResult>> signIn() async {
    final result = await _api.signIn();
    return result.fold(
      onFailure: (Failure failure) =>
          Fail<SignInResult>(_transportFailure(failure)),
      onSuccess: (SignInResult data) => Success<SignInResult>(data),
    );
  }

  Future<Result<AuthSession>> _login({
    required String phone,
    String? code,
    String? password,
    String? captcha,
  }) async {
    final revision = _store.mutationRevision;
    final result = await _api.login(
      phone: phone,
      code: code,
      password: password,
      captcha: captcha,
    );
    return result.fold(
      onFailure: (Failure failure) async =>
          Fail<AuthSession>(_transportFailure(failure)),
      onSuccess: (LoginResponse response) async {
        if (_store.mutationRevision != revision) {
          _restoreActiveContext();
          return Fail<AuthSession>(_sessionChangedFailure());
        }
        if (response.needCaptcha) {
          return Fail<AuthSession>(
            _failure(
              AuthFailureKind.needsCaptcha,
              'AUTH_NEEDS_CAPTCHA',
              code: 'AUTH_NEEDS_CAPTCHA',
            ),
          );
        }
        final user = response.user;
        if (user == null || !user.isValid) {
          return Fail<AuthSession>(
            _failure(
              AuthFailureKind.unknown,
              'AUTH_NO_USER',
              code: 'AUTH_NO_USER',
            ),
          );
        }
        final token = _context.psSession;
        if (token == null || token.isEmpty) {
          return Fail<AuthSession>(
            _failure(
              AuthFailureKind.unknown,
              'AUTH_MISSING_SESSION',
              code: 'AUTH_MISSING_SESSION',
            ),
          );
        }
        final session = AuthSession(
          user: user,
          token: token,
          isNewUser: response.newUser,
        );
        try {
          await _store.write(session);
        } catch (_) {
          return Fail<AuthSession>(
            _failure(
              AuthFailureKind.storage,
              'AUTH_SESSION_WRITE_FAILED',
              code: 'AUTH_SESSION_WRITE_FAILED',
            ),
          );
        }
        return Success<AuthSession>(session);
      },
    );
  }

  void _restoreActiveContext() {
    _context.psSession = _store.activeToken;
    if (_store.activeToken == null) _context.clearCaptcha();
  }

  Failure _sessionChangedFailure() => _failure(
    AuthFailureKind.unknown,
    'AUTH_SESSION_CHANGED',
    code: 'AUTH_SESSION_CHANGED',
  );

  Failure _transportFailure(Failure failure) {
    final rawMessage = _serverMessage(failure.cause);
    final message = rawMessage ?? failure.message;
    if (message.contains('锁定')) {
      return Failure(
        code: 'AUTH_ACCOUNT_LOCKED',
        message: message,
        type: FailureType.server,
        statusCode: failure.statusCode,
        cause: failure.cause,
      );
    }
    if (message.contains('图形验证码')) {
      return Failure(
        code: 'AUTH_NEEDS_CAPTCHA',
        message: message,
        type: FailureType.validation,
        statusCode: failure.statusCode,
        cause: failure.cause,
      );
    }
    return Failure(
      code: failure.code,
      message: message,
      type: failure.type,
      statusCode: failure.statusCode,
      cause: failure.cause,
      requestId: failure.requestId,
    );
  }

  static String? _serverMessage(Object? cause) {
    if (cause is! DioException || cause.response == null) return null;
    final response = cause.response!;
    final status = response.statusCode;
    if (status == 401 || status == 403) return null;
    final data = response.data;
    Object? payload = data;
    if (data is String && data.trim().startsWith('{')) {
      try {
        payload = jsonDecode(data);
      } on FormatException {
        payload = data;
      }
    }
    final raw = payload is Map
        ? payload['message'] ?? payload['errorMsg'] ?? payload['msg']
        : payload;
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty ||
        text.length > 300 ||
        text.startsWith('<') ||
        RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]').hasMatch(text)) {
      return null;
    }
    if (status != null && status >= 500) {
      return text.contains('锁定') || text.contains('图形验证码') ? text : null;
    }
    return text;
  }

  static Failure _failure(
    AuthFailureKind kind,
    String message, {
    String? code,
  }) => Failure(
    code: code ?? 'AUTH_BUSINESS',
    message: message,
    type: switch (kind) {
      AuthFailureKind.business => FailureType.server,
      AuthFailureKind.needsCaptcha => FailureType.validation,
      AuthFailureKind.accountLocked => FailureType.server,
      AuthFailureKind.network => FailureType.network,
      AuthFailureKind.timeout => FailureType.timeout,
      AuthFailureKind.unauthorized => FailureType.authentication,
      AuthFailureKind.storage || AuthFailureKind.unknown => FailureType.data,
    },
  );
}
