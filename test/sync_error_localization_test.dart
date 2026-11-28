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
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/app_events.dart';
import 'package:planstar_desktop_app/features/auth/application/auth_providers.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_models.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_repository.dart';
import 'package:planstar_desktop_app/features/sync/application/sync_controller.dart';
import 'package:planstar_desktop_app/features/sync/domain/sync_models.dart';
import 'package:planstar_desktop_app/features/sync/infrastructure/sync_remote_data_source.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

final class _SyncAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'uploaded': 2,
        'downloaded': 3,
        'syncedAt': '2026-11-26T12:00:00Z',
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _ControlledSyncAdapter implements HttpClientAdapter {
  final Completer<void> started = Completer<void>();
  final List<Completer<ResponseBody>> responses = <Completer<ResponseBody>>[];
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests++;
    if (!started.isCompleted) started.complete();
    final response = Completer<ResponseBody>();
    responses.add(response);
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _syncResponse() => ResponseBody.fromString(
  jsonEncode(<String, Object?>{
    'uploaded': 2,
    'downloaded': 3,
    'syncedAt': '2026-11-26T12:00:00Z',
  }),
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
  },
);

final class _AuthRepository implements AuthRepository {
  _AuthRepository({this.session});

  AuthSession? session;

  @override
  Future<Result<SendCodeOutcome>> sendLoginCode(
    String phone, {
    String? captcha,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthSession>> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  }) async => throw UnimplementedError();

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

void main() {
  test('sync errors are recomputed when the locale changes', () async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(scope),
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secureStoreProvider.overrideWithValue(MemorySecureStore()),
        domainEventBusProvider.overrideWithValue(DomainEventBus()),
        authRepositoryProvider.overrideWithValue(_AuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(syncControllerProvider.notifier);

    await controller.syncNow();
    final zh = scope.localizations;
    expect(container.read(syncControllerProvider).status, SyncStatus.failure);
    expect(
      container.read(syncControllerProvider).message,
      zh.syncLoginRequired,
    );

    scope.setLanguage('en');
    final en = scope.localizations;
    expect(container.read(syncControllerProvider).status, SyncStatus.failure);
    expect(
      container.read(syncControllerProvider).message,
      en.syncLoginRequired,
    );

    scope.setLanguage('zh');
    expect(
      container.read(syncControllerProvider).message,
      zh.syncLoginRequired,
    );
  });

  test(
    'sync success messages are recomputed when the locale changes',
    () async {
      final scope = AppLocalizationScope();
      addTearDown(scope.dispose);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test'));
      dio.httpClientAdapter = _SyncAdapter();
      final remote = SyncRemoteDataSource(
        api: ApiClient(dio),
        endpoint: 'sync/',
      );
      final container = ProviderContainer(
        overrides: [
          appLocalizationScopeProvider.overrideWithValue(scope),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
          domainEventBusProvider.overrideWithValue(DomainEventBus()),
          syncRemoteDataSourceProvider.overrideWithValue(remote),
          authRepositoryProvider.overrideWithValue(
            _AuthRepository(
              session: AuthSession(
                user: AuthUser(userId: 1, userName: 'User'),
                token: 'session-token',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(syncControllerProvider.notifier);

      await controller.syncNow();
      expect(container.read(syncControllerProvider).status, SyncStatus.success);
      expect(
        container.read(syncControllerProvider).message,
        scope.localizations.syncSummary(2, 3),
      );
      scope.setLanguage('en');
      expect(
        container.read(syncControllerProvider).message,
        scope.localizations.syncSummary(2, 3),
      );
      scope.setLanguage('zh');
      expect(
        container.read(syncControllerProvider).message,
        scope.localizations.syncSummary(2, 3),
      );
    },
  );

  test(
    'sync ignores concurrent calls and preserves changes made during upload',
    () async {
      final adapter = _ControlledSyncAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test'));
      dio.httpClientAdapter = adapter;
      final bus = DomainEventBus();
      final container = ProviderContainer(
        overrides: [
          appLocalizationScopeProvider.overrideWithValue(
            AppLocalizationScope(),
          ),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
          domainEventBusProvider.overrideWithValue(bus),
          syncRemoteDataSourceProvider.overrideWithValue(
            SyncRemoteDataSource(api: ApiClient(dio), endpoint: 'sync/'),
          ),
          authRepositoryProvider.overrideWithValue(
            _AuthRepository(
              session: AuthSession(
                user: AuthUser(userId: 1, userName: 'User'),
                token: 'session-token',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(syncControllerProvider.notifier);

      final first = controller.syncNow();
      await adapter.started.future;
      await controller.syncNow();
      expect(adapter.requests, 1);
      await bus.dispatch(<DomainEvent>[
        CountdownChanged(
          aggregateId: 'countdown-1',
          occurredAt: DateTime(2026, 11, 26),
        ),
      ]);
      adapter.responses.single.complete(_syncResponse());
      await first;

      final state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.success);
      expect(state.dirtyCount, 1);
    },
  );

  test('a stale sync response cannot overwrite a newer account', () async {
    final adapter = _ControlledSyncAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test'));
    dio.httpClientAdapter = adapter;
    final bus = DomainEventBus();
    final repository = _AuthRepository(
      session: AuthSession(
        user: AuthUser(userId: 1, userName: 'First'),
        token: 'session-a',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(AppLocalizationScope()),
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secureStoreProvider.overrideWithValue(MemorySecureStore()),
        domainEventBusProvider.overrideWithValue(bus),
        syncRemoteDataSourceProvider.overrideWithValue(
          SyncRemoteDataSource(api: ApiClient(dio), endpoint: 'sync/'),
        ),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(syncControllerProvider.notifier);

    final staleSync = controller.syncNow();
    await adapter.started.future;
    await bus.dispatch(<DomainEvent>[
      CountdownChanged(
        aggregateId: 'countdown-1',
        occurredAt: DateTime(2026, 11, 26),
      ),
    ]);
    repository.session = AuthSession(
      user: AuthUser(userId: 2, userName: 'Second'),
      token: 'session-b',
    );
    container.invalidate(authControllerProvider);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(syncControllerProvider).status, SyncStatus.idle);

    adapter.responses.single.complete(_syncResponse());
    await staleSync;

    final state = container.read(syncControllerProvider);
    expect(state.status, SyncStatus.idle);
    expect(state.lastSyncAt, isNull);
    expect(state.dirtyCount, 1);
  });
}
