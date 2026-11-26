/// 账号 / 同步控制器：订阅领域事件标记脏数据，手动 / 自动同步。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../l10n/l10n.dart';
import '../../../core/app_events.dart';
import '../domain/sync_models.dart';
import '../infrastructure/sync_remote_data_source.dart';

final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>(
  (Ref ref) => SyncRemoteDataSource(
    api: ref.watch(apiClientProvider),
    endpoint:
        ref
            .watch(appConfigProvider)
            .section('cloud')
            .getString('syncEndpoint') ??
        'sync/',
  ),
);

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

final class SyncController extends Notifier<SyncState> {
  String Function(AppLocalizations)? _localizedFailureMessage;
  String Function(AppLocalizations)? _localizedSuccessMessage;

  AppLocalizations get _l10n =>
      ref.read(appLocalizationScopeProvider).localizations;
  @override
  SyncState build() {
    // 仅由应用根 ref.read，需保活以持续统计脏数据并接收领域事件。
    ref.keepAlive();
    final localizationScope = ref.read(appLocalizationScopeProvider);
    localizationScope.addListener(_onLocaleChanged);
    ref.onDispose(() => localizationScope.removeListener(_onLocaleChanged));
    Future.microtask(_restore);
    final bus = ref.read(domainEventBusProvider);
    bus.on<CalendarEventCreated>(_onDirty);
    bus.on<CalendarEventChanged>(_onDirty);
    bus.on<CalendarEventRemoved>(_onDirty);
    bus.on<DayCellChanged>(_onDirty);
    bus.on<NoteChanged>(_onDirty);
    bus.on<CountdownChanged>(_onDirty);
    bus.on<CrossEngineDataChanged>(_onDirty);
    return SyncState.initial;
  }

  void _onLocaleChanged() {
    final label = _localizedFailureMessage ?? _localizedSuccessMessage;
    if (label != null &&
        (state.status == SyncStatus.failure ||
            state.status == SyncStatus.success)) {
      state = state.copyWith(message: label(_l10n));
    }
  }

  void _onDirty(DomainEvent event) {
    state = state.copyWith(dirtyCount: state.dirtyCount + 1);
  }

  Future<void> _restore() async {
    final store = ref.read(appStoreProvider);
    final raw = await store.preferences.readJson('planstar.sync.account.v1');
    if (raw != null) {
      state = state.copyWith(account: Account.fromJson(raw));
    }
    final auto = await store.preferences.readBool('planstar.sync.auto.v1');
    if (auto != null) state = state.copyWith(autoSync: auto);
  }

  Future<void> login({
    required String email,
    required String password,
    bool autoLogin = false,
  }) async {
    state = state.copyWith(status: SyncStatus.syncing, clearMessage: true);
    _localizedFailureMessage = null;
    _localizedSuccessMessage = null;
    final result = await ref
        .read(syncRemoteDataSourceProvider)
        .login(email, password);
    switch (result) {
      case Success<Account>(:final Account data):
        _localizedFailureMessage = null;
        _localizedSuccessMessage = (AppLocalizations l10n) =>
            l10n.syncLoginSuccess;
        final account = data.copyWith(autoLogin: autoLogin);
        state = state.copyWith(
          account: account,
          status: SyncStatus.success,
          message: _localizedSuccessMessage!(_l10n),
        );
        await ref
            .read(appStoreProvider)
            .preferences
            .writeJson('planstar.sync.account.v1', account.toJson());
        await ref
            .read(appStoreProvider)
            .secure
            .write('planstar.token', password);
      case Fail<Account>(:final Failure failure):
        // 离线时允许本地账号，保持旧版「登录后可以同步和备份」的降级体验。
        _localizedFailureMessage = (AppLocalizations l10n) =>
            l10n.syncLocalAccount(failureLabel(failure, l10n));
        final account = Account(
          id: email,
          email: email,
          displayName: email.split('@').first,
          autoLogin: autoLogin,
        );
        state = state.copyWith(
          account: account,
          status: SyncStatus.failure,
          message: _localizedFailureMessage!(_l10n),
        );
    }
  }

  Future<void> logout() async {
    _localizedFailureMessage = null;
    _localizedSuccessMessage = null;
    await ref.read(appStoreProvider).onLogout();
    await ref
        .read(appStoreProvider)
        .preferences
        .delete('planstar.sync.account.v1');
    state = SyncState.initial;
  }

  Future<void> syncNow() async {
    if (!state.account.isLoggedIn) {
      _localizedFailureMessage = (AppLocalizations l10n) =>
          l10n.syncLoginRequired;
      state = state.copyWith(
        status: SyncStatus.failure,
        message: _localizedFailureMessage!(_l10n),
      );
      return;
    }
    state = state.copyWith(status: SyncStatus.syncing, clearMessage: true);
    _localizedFailureMessage = null;
    _localizedSuccessMessage = null;
    final result = await ref
        .read(syncRemoteDataSourceProvider)
        .sync(<String, Object?>{
          'accountId': state.account.id,
          'dirty': state.dirtyCount,
          'since': state.lastSyncAt?.toIso8601String(),
        });
    switch (result) {
      case Success<SyncSummary>(:final SyncSummary data):
        _localizedFailureMessage = null;
        _localizedSuccessMessage = (AppLocalizations l10n) =>
            l10n.syncSummary(data.uploaded, data.downloaded);
        state = state.copyWith(
          status: SyncStatus.success,
          uploaded: data.uploaded,
          downloaded: data.downloaded,
          lastSyncAt: data.syncedAt,
          dirtyCount: 0,
          message: _localizedSuccessMessage!(_l10n),
        );
      case Fail<SyncSummary>(:final Failure failure):
        _localizedFailureMessage = (AppLocalizations l10n) =>
            l10n.syncFailed(failureLabel(failure, l10n));
        state = state.copyWith(
          status: SyncStatus.failure,
          message: _localizedFailureMessage!(_l10n),
        );
    }
  }

  Future<void> setAutoSync(bool enabled) async {
    state = state.copyWith(autoSync: enabled);
    await ref
        .read(appStoreProvider)
        .preferences
        .writeBool('planstar.sync.auto.v1', enabled);
  }
}
