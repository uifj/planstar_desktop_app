import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/domain.dart';
import 'package:core/network.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/features/auth/application/auth_providers.dart';
import 'package:planstar_desktop_app/features/auth/application/auth_state.dart';
import 'package:planstar_desktop_app/features/auth/data/auth_session_store.dart';
import 'package:planstar_desktop_app/features/auth/data/planstar_account_api.dart';
import 'package:planstar_desktop_app/features/auth/data/remote_auth_repository.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_models.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_repository.dart';
import 'package:planstar_desktop_app/features/auth/network/planstar_network_interceptor.dart';
import 'package:planstar_desktop_app/features/auth/network/planstar_request_context.dart';

final class _Reply {
  const _Reply(this.data, {this.status = 200, this.headers = const <String>[]});

  final Object? data;
  final int status;
  final List<String> headers;
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.replies);

  final List<_Reply> replies;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) {
        bodies.add(
          (jsonDecode(utf8.decode(bytes)) as Map).map(
            (Object? key, Object? value) =>
                MapEntry<String, Object?>('$key', value),
          ),
        );
      }
    }
    if (replies.isEmpty) {
      throw StateError('missing response for ${options.path}');
    }
    final reply = replies.removeAt(0);
    return reply.data is Uint8List
        ? ResponseBody.fromBytes(
            reply.data as Uint8List,
            reply.status,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['image/png'],
              if (reply.headers.isNotEmpty) 'set-cookie': reply.headers,
            },
          )
        : ResponseBody.fromString(
            reply.data is String
                ? reply.data as String
                : jsonEncode(reply.data),
            reply.status,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[
                reply.data is String
                    ? 'text/plain; charset=utf-8'
                    : 'application/json; charset=utf-8',
              ],
              if (reply.headers.isNotEmpty) 'set-cookie': reply.headers,
            },
          );
  }

  @override
  void close({bool force = false}) {}
}

final class _Fixture {
  _Fixture(List<_Reply> replies) {
    adapter = _Adapter(replies);
    dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test/'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      PlanstarNetworkInterceptor(context: context, userAgent: 'PlanstarTest/1'),
    );
    store = AuthSessionStore(
      store: AppStore(preferences: preferences, secure: secure),
      context: context,
      idGenerator: SequentialIdGenerator(prefix: 'test-device-'),
    );
    repository = RemoteAuthRepository(
      api: PlanstarAccountApi(client: ApiClient(dio)),
      store: store,
      context: context,
    );
  }

  late final _Adapter adapter;
  late final Dio dio;
  late final AuthSessionStore store;
  late final RemoteAuthRepository repository;
  final context = PlanstarRequestContext();
  final preferences = MemoryKeyValueStore();
  final secure = MemorySecureStore();
}

const _user = <String, Object?>{
  'userId': 42,
  'nickname': '测试用户',
  'mobile': '13800138000',
  'level': 3,
};

void main() {
  test(
    'captcha, send-code, login, profile and sign-in use reference contracts',
    () async {
      final fixture = _Fixture(<_Reply>[
        _Reply(
          Uint8List.fromList(<int>[137, 80, 78, 71]),
          headers: const <String>['psCaptcha=captcha-token; Path=/; HttpOnly'],
        ),
        const _Reply(<String, Object?>{'success': true, 'needCaptcha': false}),
        _Reply(
          <String, Object?>{
            'needCaptcha': false,
            'newUser': true,
            'user': _user,
          },
          headers: const <String>['psSession=session-token; Path=/; HttpOnly'],
        ),
        const _Reply(_user),
        const _Reply(<String, Object?>{
          'signed': true,
          'todayReward': 5,
          'balance': 120,
          'alreadySigned': true,
        }),
        const _Reply(<String, Object?>{
          'signed': true,
          'todayReward': 5,
          'balance': 120,
          'alreadySigned': false,
          'signedAt': '2026-11-27T08:00:00Z',
        }),
      ]);
      final repository = fixture.repository;

      expect((await repository.fetchCaptchaImage()).requireData, <int>[
        137,
        80,
        78,
        71,
      ]);
      expect(fixture.context.psCaptcha, 'captcha-token');
      expect(
        (await repository.sendLoginCode(
          '13800138000',
          captcha: 'ABCD',
        )).isSuccess,
        isTrue,
      );
      expect(fixture.context.psCaptcha, isNull);

      final login = await repository.loginWithCode(
        '13800138000',
        '123456',
        captcha: 'ABCD',
      );
      expect(login.isSuccess, isTrue);
      expect(login.requireData.isNewUser, isTrue);
      expect(login.requireData.user.displayName, '测试用户');
      expect(login.requireData.token, 'session-token');
      expect(
        await fixture.secure.read(AuthSessionStore.tokenKey),
        'session-token',
      );
      expect(await fixture.preferences.read(AuthSessionStore.tokenKey), isNull);
      expect(
        (await fixture.preferences.readJson(
          AuthSessionStore.profileKey,
        ))?['userId'],
        42,
      );
      final storedProfile = await fixture.preferences.read(
        AuthSessionStore.profileKey,
      );
      expect(storedProfile, isNot(contains('13800138000')));
      expect(storedProfile, contains('138****8000'));

      final sendRequest = fixture.adapter.requests[1];
      expect(sendRequest.path, PlanstarAccountApi.sendLoginCodePath);
      expect(fixture.adapter.bodies[0], <String, Object?>{
        'ua': '13800138000',
        'captcha': 'ABCD',
      });
      expect(sendRequest.headers['Cookie'], 'psCaptcha=captcha-token');
      expect(sendRequest.headers['User-Agent'], 'PlanstarTest/1');

      final loginRequest = fixture.adapter.requests[2];
      expect(loginRequest.path, PlanstarAccountApi.loginPath);
      expect(fixture.adapter.bodies[1], <String, Object?>{
        'ua': '13800138000',
        'ct': 11,
        'code': '123456',
        'captcha': 'ABCD',
      });
      expect(
        loginRequest.headers['Cookie'],
        isNot(contains('psSession=session-token')),
      );

      expect((await repository.refreshProfile()).requireData.userId, 42);
      final status = await repository.fetchSignInStatus();
      expect(status.requireData.alreadySigned, isTrue);
      expect(status.requireData.balance.minorUnits, 120);
      final checkIn = await repository.signIn();
      expect(checkIn.requireData.signed, isTrue);
      expect(checkIn.requireData.todayReward, 5);
      expect(fixture.adapter.requests[3].path, PlanstarAccountApi.profilePath);
      expect(fixture.adapter.requests[4].path, PlanstarAccountApi.signInPath);
      expect(fixture.adapter.requests[4].method, 'GET');
      expect(fixture.adapter.requests[5].path, PlanstarAccountApi.signInPath);
      expect(fixture.adapter.requests[5].method, 'POST');
      expect(
        fixture.adapter.requests[5].headers['Cookie'],
        contains('psSession=session-token'),
      );

      final restoredStore = AuthSessionStore(
        store: AppStore(
          preferences: fixture.preferences,
          secure: fixture.secure,
        ),
        context: PlanstarRequestContext(),
        idGenerator: SequentialIdGenerator(prefix: 'restarted-device-'),
      );
      expect((await restoredStore.read())?.user.userId, 42);
      expect((await restoredStore.read())?.user.maskedMobile, '138****8000');
    },
  );

  test('legacy profiles are migrated to masked mobile storage', () async {
    final preferences = MemoryKeyValueStore(<String, String>{
      AuthSessionStore.profileKey: jsonEncode(<String, Object?>{
        'userId': 42,
        'mobileNo': '13800138000',
      }),
    });
    final secure = MemorySecureStore(<String, String>{
      AuthSessionStore.tokenKey: 'session-token',
    });
    final store = AuthSessionStore(
      store: AppStore(preferences: preferences, secure: secure),
      context: PlanstarRequestContext(),
      idGenerator: SequentialIdGenerator(),
    );

    final restored = await store.read();

    expect(restored?.user.maskedMobile, '138****8000');
    final storedProfile = await preferences.read(AuthSessionStore.profileKey);
    expect(storedProfile, isNot(contains('13800138000')));
    expect(storedProfile, contains('138****8000'));
  });

  test('password login sends pw and never persists the password', () async {
    final fixture = _Fixture(<_Reply>[
      _Reply(
        <String, Object?>{
          'needCaptcha': false,
          'newUser': false,
          'user': _user,
        },
        headers: const <String>['psSession=password-session; Path=/'],
      ),
    ]);

    expect(
      (await fixture.repository.loginWithPassword(
        '13800138000',
        'secret123',
      )).isSuccess,
      isTrue,
    );
    expect(fixture.adapter.bodies.single, <String, Object?>{
      'ua': '13800138000',
      'ct': 11,
      'pw': 'secret123',
    });
    for (final key in await fixture.preferences.keys()) {
      expect(await fixture.preferences.read(key), isNot(contains('secret123')));
    }
  });

  test(
    'captcha and account-lock business failures retain server messages',
    () async {
      final captchaFixture = _Fixture(<_Reply>[
        const _Reply(<String, Object?>{
          'success': false,
          'needCaptcha': true,
          'errorMsg': '请输入图形验证码',
        }),
      ]);
      final captcha = await captchaFixture.repository.sendLoginCode(
        '13800138000',
      );
      expect(captcha.failure?.code, 'AUTH_NEEDS_CAPTCHA');
      expect(captcha.failure?.message, '请输入图形验证码');

      final lockedFixture = _Fixture(<_Reply>[
        const _Reply('账号已锁定，请稍后再试', status: 500),
      ]);
      final locked = await lockedFixture.repository.loginWithPassword(
        '13800138000',
        'secret123',
      );
      expect(locked.failure?.code, 'AUTH_ACCOUNT_LOCKED');
      expect(locked.failure?.message, '账号已锁定，请稍后再试');
    },
  );

  test(
    '401 invokes logout hook and failed login consumes captcha cookie',
    () async {
      var unauthorizedCalls = 0;
      final fixture = _Fixture(<_Reply>[
        const _Reply(<String, Object?>{}, status: 401),
        const _Reply(<String, Object?>{}, status: 500),
      ]);
      fixture.context
        ..psSession = 'old-session'
        ..psCaptcha = 'captcha-token'
        ..onUnauthorized = () => unauthorizedCalls++;

      await fixture.repository.refreshProfile();
      expect(unauthorizedCalls, 1);
      await fixture.repository.loginWithCode('13800138000', '123456');
      expect(fixture.context.psCaptcha, isNull);
    },
  );

  test('a stale 401 cannot overwrite or log out a newer session', () async {
    final response = Completer<ResponseBody>();
    final adapter = _PendingAdapter(response.future);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test/'));
    dio.httpClientAdapter = adapter;
    final context = PlanstarRequestContext(psSession: 'account-a');
    var unauthorizedCalls = 0;
    context.onUnauthorized = () => unauthorizedCalls++;
    dio.interceptors.add(
      PlanstarNetworkInterceptor(context: context, userAgent: 'PlanstarTest/1'),
    );

    final pending = dio.get<dynamic>('v1/user');
    await adapter.started.future;
    context.psSession = 'account-b';
    response.complete(
      ResponseBody.fromString(
        '{}',
        401,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
          'set-cookie': <String>['psSession=account-a; Path=/'],
        },
      ),
    );
    await expectLater(pending, throwsA(isA<DioException>()));

    expect(unauthorizedCalls, 0);
    expect(context.psSession, 'account-b');
  });

  test('server diagnostic bodies are not exposed as auth messages', () async {
    final fixture = _Fixture(<_Reply>[
      _Reply('<html><body>internal stack trace</body></html>', status: 502),
      _Reply('database password=secret; host=internal', status: 503),
      _Reply(<String, Object?>{'message': 'internal stack trace'}, status: 500),
    ]);

    for (var i = 0; i < 3; i++) {
      final result = await fixture.repository.loginWithPassword(
        '13800138000',
        'secret123',
      );
      expect(result.failure?.message, 'SERVER_ERROR');
      expect(result.failure?.message, isNot(contains('secret')));
      expect(result.failure?.message, isNot(contains('stack trace')));
    }
  });

  test(
    'a partial session write discards the unpaired token and profile',
    () async {
      final preferences = _FailingProfilePreferences();
      final secure = MemorySecureStore();
      final context = PlanstarRequestContext();
      final store = AuthSessionStore(
        store: AppStore(preferences: preferences, secure: secure),
        context: context,
        idGenerator: SequentialIdGenerator(),
      );
      final oldSession = const AuthSession(
        user: AuthUser(userId: 42),
        token: 'account-a',
      );
      await store.write(oldSession);
      preferences.failNextProfileWrite();

      await expectLater(
        store.write(
          const AuthSession(user: AuthUser(userId: 43), token: 'account-b'),
        ),
        throwsStateError,
      );

      expect(context.psSession, isNull);
      expect(await secure.read(AuthSessionStore.tokenKey), isNull);
      expect(await preferences.readJson(AuthSessionStore.profileKey), isNull);
      expect(await store.read(), isNull);
    },
  );

  test(
    'logout clears session and profile but preserves device configuration',
    () async {
      final fixture = _Fixture(<_Reply>[]);
      await fixture.store.write(
        const AuthSession(user: AuthUser(userId: 42), token: 'session-token'),
      );
      await fixture.preferences.write(AuthSessionStore.deviceIdKey, 'device-1');
      await fixture.preferences.write('planstar.token', 'legacy-password');
      await fixture.preferences.write(
        'planstar.sync.account.v1',
        jsonEncode(<String, Object?>{'userId': 42}),
      );
      fixture.context.psCaptcha = 'captcha-token';

      await fixture.store.clear();
      expect(fixture.context.psSession, isNull);
      expect(fixture.context.psCaptcha, isNull);
      expect(await fixture.secure.read(AuthSessionStore.tokenKey), isNull);
      expect(
        await fixture.preferences.readJson(AuthSessionStore.profileKey),
        isNull,
      );
      expect(
        await fixture.preferences.read(AuthSessionStore.deviceIdKey),
        'device-1',
      );
      expect(await fixture.preferences.read('planstar.token'), isNull);
      expect(
        await fixture.preferences.read('planstar.sync.account.v1'),
        isNull,
      );
      expect(await fixture.store.read(), isNull);
    },
  );

  test('a delayed login cannot restore a session after logout', () async {
    final fixture = _Fixture(<_Reply>[]);
    final response = Completer<ResponseBody>();
    final adapter = _PendingAdapter(response.future);
    fixture.dio.httpClientAdapter = adapter;

    final login = fixture.repository.loginWithCode('13800138000', '123456');
    await adapter.started.future;
    await fixture.store.clear();
    response.complete(
      ResponseBody.fromString(
        jsonEncode(<String, Object?>{
          'needCaptcha': false,
          'newUser': false,
          'user': _user,
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
          'set-cookie': <String>['psSession=stale-session; Path=/; HttpOnly'],
        },
      ),
    );

    expect((await login).isFailure, isTrue);
    expect(await fixture.secure.read(AuthSessionStore.tokenKey), isNull);
    expect(
      await fixture.preferences.readJson(AuthSessionStore.profileKey),
      isNull,
    );
    expect(fixture.context.psSession, isNull);
  });

  test('a delayed profile cannot overwrite a newer account session', () async {
    final fixture = _Fixture(<_Reply>[]);
    await fixture.store.write(
      const AuthSession(user: AuthUser(userId: 42), token: 'account-a'),
    );
    final response = Completer<ResponseBody>();
    final adapter = _PendingAdapter(response.future);
    fixture.dio.httpClientAdapter = adapter;

    final refresh = fixture.repository.refreshProfile();
    await adapter.started.future;
    await fixture.store.clear();
    await fixture.store.write(
      const AuthSession(user: AuthUser(userId: 43), token: 'account-b'),
    );
    response.complete(
      ResponseBody.fromString(
        jsonEncode(<String, Object?>{..._user, 'userId': 42}),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      ),
    );

    expect((await refresh).isFailure, isTrue);
    expect(
      (await fixture.preferences.readJson(
        AuthSessionStore.profileKey,
      ))?['userId'],
      43,
    );
    expect(fixture.context.psSession, 'account-b');
  });

  test('a delayed restore cannot resurrect a logged-out session', () async {
    final preferences = _DelayedProfilePreferences();
    final secure = MemorySecureStore(<String, String>{
      AuthSessionStore.tokenKey: 'account-a',
    });
    final context = PlanstarRequestContext();
    final store = AuthSessionStore(
      store: AppStore(preferences: preferences, secure: secure),
      context: context,
      idGenerator: SequentialIdGenerator(),
    );
    await preferences.inner.write(
      AuthSessionStore.profileKey,
      jsonEncode(const AuthUser(userId: 42).toJson()),
    );

    final restoring = store.read();
    await preferences.started.future;
    final logout = store.clear();
    preferences.release.complete(
      jsonEncode(const AuthUser(userId: 42).toJson()),
    );

    expect(await restoring, isNull);
    await logout;
    expect(context.psSession, isNull);
    expect(await secure.read(AuthSessionStore.tokenKey), isNull);
  });

  test('a fresh device id is persisted and reused after restart', () async {
    final preferences = MemoryKeyValueStore();
    final secure = MemorySecureStore();
    final context = PlanstarRequestContext();
    final first = AuthSessionStore(
      store: AppStore(preferences: preferences, secure: secure),
      context: context,
      idGenerator: SequentialIdGenerator(prefix: 'first-device-'),
    );

    expect(await first.read(), isNull);
    final deviceId = context.dvid;
    expect(deviceId, isNotNull);
    expect(deviceId, isNotEmpty);
    expect(await preferences.read(AuthSessionStore.deviceIdKey), deviceId);

    final restartedContext = PlanstarRequestContext();
    final restarted = AuthSessionStore(
      store: AppStore(preferences: preferences, secure: secure),
      context: restartedContext,
      idGenerator: SequentialIdGenerator(prefix: 'second-device-'),
    );
    expect(await restarted.read(), isNull);
    expect(restartedContext.dvid, deviceId);
    expect(
      await preferences.read(AuthSessionStore.deviceIdKey),
      isNot(startsWith('second-device-')),
    );
  });

  test('missing token or corrupt profile cannot restore a session', () async {
    final preferences = MemoryKeyValueStore(<String, String>{
      AuthSessionStore.profileKey: '{broken',
    });
    final secure = MemorySecureStore(<String, String>{
      AuthSessionStore.tokenKey: 'session-token',
    });
    final store = AuthSessionStore(
      store: AppStore(preferences: preferences, secure: secure),
      context: PlanstarRequestContext(),
      idGenerator: SequentialIdGenerator(),
    );
    expect(await store.read(), isNull);

    await preferences.write(
      AuthSessionStore.profileKey,
      jsonEncode(const AuthUser(userId: 42).toJson()),
    );
    await secure.delete(AuthSessionStore.tokenKey);
    expect(await store.read(), isNull);
  });

  test(
    'a failed secure delete prevents restoring the logged-out session',
    () async {
      final preferences = MemoryKeyValueStore();
      final secure = _FailingDeleteSecureStore();
      final context = PlanstarRequestContext();
      final store = AuthSessionStore(
        store: AppStore(preferences: preferences, secure: secure),
        context: context,
        idGenerator: SequentialIdGenerator(),
      );
      const session = AuthSession(user: AuthUser(userId: 42), token: 'token');

      await store.write(session);
      expect(await store.read(), isNotNull);
      await store.clear();

      expect(context.psSession, isNull);
      expect(await preferences.read(AuthSessionStore.loggedOutKey), 'true');
      expect(await secure.read(AuthSessionStore.tokenKey), 'token');
      expect(await store.read(), isNull);

      await store.write(session);
      expect(await preferences.read(AuthSessionStore.loggedOutKey), isNull);
      final restored = await store.read();
      expect(restored?.token, session.token);
      expect(restored?.user.userId, session.user.userId);
    },
  );

  controllerTests();
}

final class _PendingAdapter implements HttpClientAdapter {
  _PendingAdapter(this.response);

  final Future<ResponseBody> response;
  final Completer<void> started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (!started.isCompleted) started.complete();
    return response;
  }

  @override
  void close({bool force = false}) {}
}

final class _DelayedProfilePreferences implements KeyValueStore {
  _DelayedProfilePreferences();

  final MemoryKeyValueStore inner = MemoryKeyValueStore();
  final Completer<void> started = Completer<void>();
  final Completer<String> release = Completer<String>();

  @override
  Future<String?> read(String key) async {
    final value = await inner.read(key);
    if (key == AuthSessionStore.profileKey && value != null) {
      if (!started.isCompleted) started.complete();
      return release.future;
    }
    return value;
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> clear() => inner.clear();

  @override
  Future<Set<String>> keys() => inner.keys();
}

final class _FailingProfilePreferences implements KeyValueStore {
  final MemoryKeyValueStore _inner = MemoryKeyValueStore();
  bool _failProfileWrite = false;

  void failNextProfileWrite() => _failProfileWrite = true;

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) {
    if (_failProfileWrite && key == AuthSessionStore.profileKey) {
      _failProfileWrite = false;
      throw StateError('profile storage unavailable');
    }
    return _inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> clear() => _inner.clear();

  @override
  Future<Set<String>> keys() => _inner.keys();
}

final class _FailingDeleteSecureStore implements SecureStore {
  final MemorySecureStore _inner = MemorySecureStore();

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) => _inner.write(key, value);

  @override
  Future<void> delete(String key) => throw StateError('keychain unavailable');

  @override
  Future<void> clear() => _inner.clear();

  @override
  Future<Set<String>> keys() => _inner.keys();
}

final class _ControlledRepository implements AuthRepository {
  final loginCompleter = Completer<Result<AuthSession>>();
  final sendCompleter = Completer<Result<SendCodeOutcome>>();
  Completer<AuthSession?>? restoreCompleter;
  Completer<Result<AuthUser>>? profileCompleter;
  Completer<Result<SignInResult>>? signInStatusCompleter;
  Completer<Result<SignInResult>>? nextSignInStatusCompleter;
  Completer<Result<SignInResult>>? signInCompleter;
  int loginCalls = 0;
  int sendCalls = 0;
  int logoutCalls = 0;
  int restoreCalls = 0;
  int signInStatusCalls = 0;
  Object? logoutError;
  AuthSession? restoredSession;

  @override
  Future<Result<AuthSession>> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  }) {
    loginCalls++;
    return loginCompleter.future;
  }

  @override
  Future<Result<AuthSession>> loginWithPassword(
    String phone,
    String password, {
    String? captcha,
  }) => throw UnimplementedError();

  @override
  Future<Result<SendCodeOutcome>> sendLoginCode(
    String phone, {
    String? captcha,
  }) {
    sendCalls++;
    return sendCompleter.future;
  }

  @override
  Future<Result<List<int>>> fetchCaptchaImage() async =>
      throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() {
    restoreCalls++;
    return restoreCompleter?.future ??
        Future<AuthSession?>.value(restoredSession);
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutError case final Object error) throw error;
  }

  @override
  Future<Result<AuthUser>> refreshProfile() =>
      profileCompleter?.future ??
      Future<Result<AuthUser>>.value(
        const Fail<AuthUser>(
          Failure(
            code: 'PROFILE_UNAVAILABLE',
            message: 'unavailable',
            type: FailureType.server,
          ),
        ),
      );

  @override
  Future<Result<SignInResult>> fetchSignInStatus() {
    signInStatusCalls++;
    if (signInStatusCalls == 1 && signInStatusCompleter != null) {
      return signInStatusCompleter!.future;
    }
    if (signInStatusCalls == 2 && nextSignInStatusCompleter != null) {
      return nextSignInStatusCompleter!.future;
    }
    return Future<Result<SignInResult>>.value(
      const Success<SignInResult>(
        SignInResult(
          signed: false,
          todayReward: 0,
          balance: Money.zero(),
          alreadySigned: false,
        ),
      ),
    );
  }

  @override
  Future<Result<SignInResult>> signIn() =>
      signInCompleter?.future ??
      Future<Result<SignInResult>>.value(
        const Fail<SignInResult>(
          Failure(
            code: 'SIGN_IN_UNAVAILABLE',
            message: 'unavailable',
            type: FailureType.server,
          ),
        ),
      );
}

void controllerTests() {
  test(
    'controller prevents duplicate sends/logins and runs cooldown',
    () async {
      final repository = _ControlledRepository();
      final context = PlanstarRequestContext();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          planstarRequestContextProvider.overrideWithValue(context),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(authControllerProvider.notifier);

      final firstSend = controller.sendCode('13800138000');
      await controller.sendCode('13800138000');
      expect(repository.sendCalls, 1);
      repository.sendCompleter.complete(
        const Success<SendCodeOutcome>(SendCodeOutcome(cooldownSeconds: 1)),
      );
      expect(await firstSend, isNull);
      expect(container.read(authControllerProvider).cooldownSeconds, 1);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(container.read(authControllerProvider).cooldownSeconds, 0);

      final firstLogin = controller.loginWithCode('13800138000', '123456');
      await controller.loginWithCode('13800138000', '123456');
      expect(repository.loginCalls, 1);
      repository.loginCompleter.complete(
        const Success<AuthSession>(
          AuthSession(
            user: AuthUser(userId: 42),
            token: 'token',
            isNewUser: true,
          ),
        ),
      );
      expect(await firstLogin, isNull);
      expect(container.read(authControllerProvider).isLoggedIn, isTrue);
      expect(container.read(authControllerProvider).isNewUser, isTrue);
    },
  );

  test('a delayed restore cannot overwrite logout', () async {
    final repository = _ControlledRepository()
      ..restoreCompleter = Completer<AuthSession?>();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final controller = container.read(authControllerProvider.notifier);
    await controller.logout();
    repository.restoreCompleter!.complete(
      const AuthSession(user: AuthUser(userId: 42), token: 'account-a'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authControllerProvider).status, AuthStatus.guest);
  });

  test('a delayed login cannot overwrite logout', () async {
    final repository = _ControlledRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final controller = container.read(authControllerProvider.notifier);
    final login = controller.loginWithCode('13800138000', '123456');
    await controller.logout();
    repository.loginCompleter.complete(
      const Success<AuthSession>(
        AuthSession(user: AuthUser(userId: 42), token: 'account-a'),
      ),
    );
    await login;

    expect(container.read(authControllerProvider).status, AuthStatus.guest);
  });

  test('a delayed profile cannot overwrite a newer account', () async {
    final repository = _ControlledRepository()
      ..restoredSession = const AuthSession(
        user: AuthUser(userId: 42),
        token: 'account-a',
      )
      ..profileCompleter = Completer<Result<AuthUser>>();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(authControllerProvider.notifier);

    final refresh = controller.refreshProfile();
    await controller.logout();
    final login = controller.loginWithCode('13800138000', '123456');
    repository.loginCompleter.complete(
      const Success<AuthSession>(
        AuthSession(user: AuthUser(userId: 43), token: 'account-b'),
      ),
    );
    await login;
    repository.profileCompleter!.complete(
      const Success<AuthUser>(AuthUser(userId: 42)),
    );
    await refresh;

    final state = container.read(authControllerProvider);
    expect(state.user?.userId, 43);
    expect(state.refreshingProfile, isFalse);
  });

  test('a delayed sign-in status cannot leak across accounts', () async {
    final repository = _ControlledRepository()
      ..restoredSession = const AuthSession(
        user: AuthUser(userId: 42),
        token: 'account-a',
      )
      ..signInStatusCompleter = Completer<Result<SignInResult>>()
      ..nextSignInStatusCompleter = Completer<Result<SignInResult>>();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(authControllerProvider.notifier);

    await controller.logout();
    final login = controller.loginWithCode('13800138000', '123456');
    repository.loginCompleter.complete(
      const Success<AuthSession>(
        AuthSession(user: AuthUser(userId: 43), token: 'account-b'),
      ),
    );
    await login;
    repository.signInStatusCompleter!.complete(
      Success<SignInResult>(
        SignInResult(
          signed: true,
          todayReward: 5,
          balance: Money.fromMinorUnits(500),
          alreadySigned: true,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authControllerProvider).signInResult, isNull);

    repository.nextSignInStatusCompleter!.complete(
      Success<SignInResult>(
        SignInResult(
          signed: false,
          todayReward: 0,
          balance: Money.fromMinorUnits(900),
          alreadySigned: false,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authControllerProvider).signInResult?.balance.minorUnits,
      900,
    );
  });

  test('401 logs out only an authenticated user', () async {
    final repository = _ControlledRepository()
      ..restoredSession = const AuthSession(
        user: AuthUser(userId: 42),
        token: 'token',
      );
    final context = PlanstarRequestContext();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        planstarRequestContextProvider.overrideWithValue(context),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );

    context.onUnauthorized?.call();
    await Future<void>.delayed(Duration.zero);
    expect(repository.logoutCalls, 1);
    expect(container.read(authControllerProvider).status, AuthStatus.guest);
    context.onUnauthorized?.call();
    await Future<void>.delayed(Duration.zero);
    expect(repository.logoutCalls, 1);
  });

  test('internal auth error codes are not exposed as user messages', () {
    final failure = AuthFailure.fromFailure(
      const Failure(
        code: 'AUTH_MISSING_SESSION',
        message: 'AUTH_MISSING_SESSION',
        type: FailureType.data,
      ),
    );

    expect(failure.code, 'AUTH_MISSING_SESSION');
    expect(failure.message, isEmpty);
  });

  test(
    'logout reports storage failure while remaining in guest state',
    () async {
      final repository = _ControlledRepository()
        ..restoredSession = const AuthSession(
          user: AuthUser(userId: 42),
          token: 'token',
        )
        ..logoutError = StateError('keychain unavailable');
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);

      await container.read(authControllerProvider.notifier).logout();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.guest);
      expect(state.isLoggedIn, isFalse);
      expect(state.failure?.kind, AuthFailureKind.storage);
      expect(state.failure?.code, 'AUTH_LOGOUT_FAILED');
      expect(state.failure?.message, isEmpty);
    },
  );
}
