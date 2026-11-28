/// 账号 / 同步控制器：订阅领域事件标记脏数据，手动 / 自动同步。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../l10n/l10n.dart';
import '../../../core/app_events.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/auth_state.dart';
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
  int _syncGeneration = 0;
  bool _syncing = false;

  AppLocalizations get _l10n =>
      ref.read(appLocalizationScopeProvider).localizations;
  @override
  SyncState build() {
    // 仅由应用根 ref.read，需保活以持续统计脏数据并接收领域事件。
    ref.keepAlive();
    ref.listen<int?>(
      authControllerProvider.select(
        (AuthState auth) => auth.isLoggedIn ? auth.user?.userId : null,
      ),
      (int? previous, int? next) {
        if (previous == next) return;
        _syncGeneration++;
        _syncing = false;
        _localizedFailureMessage = null;
        _localizedSuccessMessage = null;
        state = SyncState(
          autoSync: state.autoSync,
          dirtyCount: state.dirtyCount,
        );
      },
    );
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
    final auto = await ref
        .read(appStoreProvider)
        .preferences
        .readBool('planstar.sync.auto.v1');
    if (auto != null) state = state.copyWith(autoSync: auto);
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn || auth.user == null) {
      _syncGeneration++;
      _localizedFailureMessage = (AppLocalizations l10n) =>
          l10n.syncLoginRequired;
      _localizedSuccessMessage = null;
      state = state.copyWith(
        status: SyncStatus.failure,
        message: _localizedFailureMessage!(_l10n),
      );
      return;
    }
    final generation = ++_syncGeneration;
    final userId = auth.user!.userId;
    final dirtyCount = state.dirtyCount;
    _syncing = true;
    state = state.copyWith(status: SyncStatus.syncing, clearMessage: true);
    _localizedFailureMessage = null;
    _localizedSuccessMessage = null;
    try {
      final result = await ref
          .read(syncRemoteDataSourceProvider)
          .sync(<String, Object?>{
            'accountId': userId.toString(),
            'dirty': dirtyCount,
            'since': state.lastSyncAt?.toIso8601String(),
          });
      if (!_isCurrent(generation, userId)) return;
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
            dirtyCount: state.dirtyCount > dirtyCount
                ? state.dirtyCount - dirtyCount
                : 0,
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
    } finally {
      if (generation == _syncGeneration) _syncing = false;
    }
  }

  bool _isCurrent(int generation, int userId) {
    final auth = ref.read(authControllerProvider);
    return generation == _syncGeneration &&
        auth.isLoggedIn &&
        auth.user?.userId == userId;
  }

  Future<void> setAutoSync(bool enabled) async {
    state = state.copyWith(autoSync: enabled);
    await ref
        .read(appStoreProvider)
        .preferences
        .writeBool('planstar.sync.auto.v1', enabled);
  }
}
