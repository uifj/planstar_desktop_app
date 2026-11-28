import 'dart:async';

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/app_events.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/features/settings/application/settings_controller.dart';
import 'package:planstar_desktop_app/features/settings/domain/app_settings.dart';
import 'package:planstar_desktop_app/features/settings/infrastructure/settings_repository.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

final class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 11, 27);
}

final class _DelayedStore implements KeyValueStore {
  _DelayedStore(this._inner);

  final KeyValueStore _inner;
  final List<String> writes = <String>[];
  bool failNextWrite = false;
  int activeWrites = 0;
  int maxActiveWrites = 0;

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) async {
    activeWrites++;
    if (activeWrites > maxActiveWrites) maxActiveWrites = activeWrites;
    writes.add(key);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (failNextWrite) {
        failNextWrite = false;
        throw StateError('disk unavailable');
      }
      await _inner.write(key, value);
    } finally {
      activeWrites--;
    }
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> clear() => _inner.clear();

  @override
  Future<Set<String>> keys() => _inner.keys();
}

void main() {
  group('AppSettings 值对象语义', () {
    test('内容相等的设置对象 hashCode 相等且 Set 不重复', () {
      final a = AppSettings.defaults;
      final b = AppSettings.defaults.copyWith();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(<AppSettings>{a, b}, hasLength(1));
    });

    test('集合字段按内容计算相等与 hashCode', () {
      final a = AppSettings.defaults.copyWith(restDays: <int>[6, 7]);
      final b = AppSettings.defaults.copyWith(restDays: <int>[6, 7]);
      final c = AppSettings.defaults.copyWith(restDays: <int>[1, 2]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  test(
    'invalid fields fall back independently without losing valid fields',
    () {
      final settings = AppSettings.fromJson(<String, Object?>{
        'showGlassEffect': 'false',
        'maxRows': <Object?>[],
        'cellGap': double.nan,
        'restDays': <Object?>[1, 'bad', 7.0],
        'language': 42,
        'themeMode': 'dark',
        'desktopWidgetEnabled': false,
      });

      expect(settings.showGlassEffect, isTrue);
      expect(settings.maxRows, 6);
      expect(settings.cellGap, 2);
      expect(settings.restDays, <int>[1, 7]);
      expect(settings.language, 'zh_CN');
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.desktopWidgetEnabled, isFalse);
    },
  );

  test('legacy settings migrate away from wallpaper rendering', () async {
    final store = MemoryKeyValueStore(<String, String>{
      LocalSettingsRepository.key:
          '{"wallpaperAutoRender":true,"desktopEmbedded":true}',
    });
    final repository = LocalSettingsRepository(
      store: store,
      bus: DomainEventBus(),
      clock: _Clock(),
    );

    final result = await repository.load();
    expect(result, isA<Success<AppSettings>>());
    final settings = (result as Success<AppSettings>).data;
    expect(settings.wallpaperAutoRender, isFalse);
    expect(settings.desktopWidgetEnabled, isTrue);
    await Future<void>.delayed(Duration.zero);
    final persisted = await store.readJson(LocalSettingsRepository.key);
    expect(persisted?['desktopWidgetEnabled'], isTrue);
    expect(persisted?['wallpaperAutoRender'], isFalse);
  });

  test(
    'rapid saves are serialized and last write wins after restart',
    () async {
      final memory = MemoryKeyValueStore();
      final store = _DelayedStore(memory);
      final repository = LocalSettingsRepository(
        store: store,
        bus: DomainEventBus(),
        clock: _Clock(),
      );

      final saves = <Future<Result<void>>>[
        for (var rows = 1; rows <= 10; rows++)
          repository.save(AppSettings.defaults.copyWith(maxRows: rows)),
      ];
      expect(
        (await Future.wait(saves)).every((Result<void> r) => r.isSuccess),
        isTrue,
      );
      expect(store.maxActiveWrites, 1);

      final restarted = LocalSettingsRepository(
        store: memory,
        bus: DomainEventBus(),
        clock: _Clock(),
      );
      final loaded = await restarted.load();
      expect(loaded, isA<Success<AppSettings>>());
      expect((loaded as Success<AppSettings>).data.maxRows, 10);
    },
  );

  test('failed writes do not block the next queued save', () async {
    final store = _DelayedStore(MemoryKeyValueStore());
    final repository = LocalSettingsRepository(
      store: store,
      bus: DomainEventBus(),
      clock: _Clock(),
    );
    store.failNextWrite = true;

    final first = await repository.save(
      AppSettings.defaults.copyWith(maxRows: 3),
    );
    final second = await repository.save(
      AppSettings.defaults.copyWith(maxRows: 8),
    );

    expect(first, isA<Fail<void>>());
    expect(second, isA<Success<void>>());
    expect(await store.readJson(LocalSettingsRepository.key), isNotNull);
  });

  test('successful saves publish settings changes', () async {
    final bus = DomainEventBus();
    final repository = LocalSettingsRepository(
      store: MemoryKeyValueStore(),
      bus: bus,
      clock: _Clock(),
    );
    final event = Completer<SettingsChanged>();
    final unsubscribe = bus.on<SettingsChanged>((SettingsChanged change) async {
      if (!event.isCompleted) event.complete(change);
    });
    addTearDown(unsubscribe);

    await repository.save(AppSettings.defaults);
    expect((await event.future).aggregateId, LocalSettingsRepository.key);
  });

  test('controller returns settings save failures to the caller', () async {
    final repository = _FailingSettingsRepository();
    final localization = AppLocalizationScope();
    addTearDown(localization.dispose);
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        appLocalizationScopeProvider.overrideWithValue(localization),
      ],
    );
    addTearDown(container.dispose);
    container.read(settingsControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final result = await container
        .read(settingsControllerProvider.notifier)
        .update((AppSettings current) => current.copyWith(maxRows: 7));

    expect(result, isA<Fail<void>>());
    expect(container.read(settingsControllerProvider).maxRows, 7);
  });

  test(
    'an update made before deferred startup load waits for stored settings',
    () async {
      final load = Completer<Result<AppSettings>>();
      final repository = _DelayedSettingsRepository(load.future);
      final localization = AppLocalizationScope();
      addTearDown(localization.dispose);
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          appLocalizationScopeProvider.overrideWithValue(localization),
        ],
      );
      addTearDown(container.dispose);

      container.read(settingsControllerProvider);
      final save = container
          .read(settingsControllerProvider.notifier)
          .update((AppSettings current) => current.copyWith(maxRows: 9));
      load.complete(
        Success<AppSettings>(AppSettings.defaults.copyWith(maxRows: 3)),
      );
      await save;
      await Future<void>.delayed(Duration.zero);

      expect(container.read(settingsControllerProvider).maxRows, 9);
      expect(repository.saved.single.maxRows, 9);
    },
  );

  test(
    'an update made after startup load begins still waits for stored settings',
    () async {
      final load = Completer<Result<AppSettings>>();
      final repository = _DelayedSettingsRepository(load.future);
      final localization = AppLocalizationScope();
      addTearDown(localization.dispose);
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          appLocalizationScopeProvider.overrideWithValue(localization),
        ],
      );
      addTearDown(container.dispose);

      container.read(settingsControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final save = container
          .read(settingsControllerProvider.notifier)
          .update((AppSettings current) => current.copyWith(maxRows: 9));
      await Future<void>.delayed(Duration.zero);
      expect(repository.saved, isEmpty);

      load.complete(
        Success<AppSettings>(
          AppSettings.defaults.copyWith(maxRows: 3, showLunar: false),
        ),
      );
      await save;

      final state = container.read(settingsControllerProvider);
      expect(state.maxRows, 9);
      expect(state.showLunar, isFalse);
      expect(repository.saved.single.maxRows, 9);
      expect(repository.saved.single.showLunar, isFalse);
    },
  );
}

final class _FailingSettingsRepository implements SettingsRepository {
  @override
  Future<Result<AppSettings>> load() async =>
      const Success<AppSettings>(AppSettings.defaults);

  @override
  Future<Result<void>> save(AppSettings settings) async => const Fail<void>(
    Failure(
      code: 'SETTINGS_WRITE_FAILED',
      message: 'disk unavailable',
      type: FailureType.data,
    ),
  );
}

final class _DelayedSettingsRepository implements SettingsRepository {
  _DelayedSettingsRepository(this.loadResult);

  final Future<Result<AppSettings>> loadResult;
  final List<AppSettings> saved = <AppSettings>[];

  @override
  Future<Result<AppSettings>> load() => loadResult;

  @override
  Future<Result<void>> save(AppSettings settings) async {
    saved.add(settings);
    return const Success<void>(null);
  }
}
