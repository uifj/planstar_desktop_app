import 'dart:convert';
import 'dart:typed_data';

import 'package:core/domain.dart';
import 'package:core/network.dart';
import 'package:core/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
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
    final data = options.path.endsWith('login')
        ? <String, Object?>{
            'id': 'account-1',
            'email': 'user@example.com',
            'displayName': 'User',
          }
        : <String, Object?>{
            'uploaded': 2,
            'downloaded': 3,
            'syncedAt': '2026-11-26T12:00:00Z',
          };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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
      ],
    );
    addTearDown(container.dispose);
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
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(syncControllerProvider.notifier);

      await controller.login(email: 'user@example.com', password: 'password');
      expect(container.read(syncControllerProvider).status, SyncStatus.success);
      expect(
        container.read(syncControllerProvider).message,
        scope.localizations.syncLoginSuccess,
      );
      scope.setLanguage('en');
      expect(
        container.read(syncControllerProvider).message,
        scope.localizations.syncLoginSuccess,
      );

      await controller.syncNow();
      expect(container.read(syncControllerProvider).status, SyncStatus.success);
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
}
