/// 账号页：真实企划星会话、个人资料、每日签到与本地云同步状态。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/application/auth_state.dart';
import '../application/sync_controller.dart';
import '../domain/sync_models.dart';

final class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final colors = context.appColors;
    final l10n = context.l10n;
    if (auth.isRestoring) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = auth.user;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        AppSectionCard(
          title: l10n.accountTitle,
          subtitle: l10n.accountSubtitle,
          child: user == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.authLoginPrompt,
                      style: TextStyle(
                        fontSize: AppTypography.body,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(LucideIcons.logIn, size: 16),
                      label: Text(l10n.accountLoginOrRegister),
                    ),
                  ],
                )
              : _Profile(
                  auth: auth,
                  onRefresh: () => _runAuthAction(
                    context,
                    ref.read(authControllerProvider.notifier).refreshProfile,
                    '',
                  ),
                  onSignIn: () => _runAuthAction(
                    context,
                    ref.read(authControllerProvider.notifier).signIn,
                    l10n.authSignedToday,
                  ),
                  onLogout: () => _runLogout(context, ref),
                ),
        ),
        if (user != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _CloudSync(state: ref.watch(syncControllerProvider)),
        ],
      ],
    );
  }

  Future<void> _runAuthAction(
    BuildContext context,
    Future<AuthFailure?> Function() action,
    String successMessage,
  ) async {
    final failure = await action();
    if (!context.mounted) return;
    if (failure != null) {
      _showFailure(context, failure);
    } else if (successMessage.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    }
  }

  Future<void> _runLogout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) return;
    final failure = ref.read(authControllerProvider).failure;
    if (failure != null) _showFailure(context, failure);
  }

  void _showFailure(BuildContext context, AuthFailure failure) {
    final message = switch (failure.kind) {
      AuthFailureKind.network => context.l10n.authNetworkError,
      AuthFailureKind.timeout => context.l10n.authTimeoutError,
      AuthFailureKind.storage => context.l10n.authStorageError,
      AuthFailureKind.unauthorized => context.l10n.authSessionExpired,
      _ =>
        failure.message.isNotEmpty
            ? failure.message
            : context.l10n.authUnknownError,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _Profile extends StatelessWidget {
  const _Profile({
    required this.auth,
    required this.onRefresh,
    required this.onSignIn,
    required this.onLogout,
  });

  final AuthState auth;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final user = auth.user!;
    final result = auth.signInResult;
    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : user.maskedMobile ?? l10n.authGuestName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.brandSubtle,
              child: Icon(LucideIcons.userRound, color: colors.brand),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: AppTypography.subtitle,
                      fontWeight: AppTypography.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (user.maskedMobile != null)
                    Text(
                      user.maskedMobile!,
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: colors.textTertiary,
                      ),
                    ),
                  if (user.levelLabel.isNotEmpty || user.level > 0)
                    Text(
                      user.levelLabel.isNotEmpty
                          ? user.levelLabel
                          : 'Lv.${user.level}',
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: colors.brand,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          user.bio?.isNotEmpty == true ? user.bio! : l10n.authProfileEmpty,
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.authUserId(user.userId),
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: auth.busy ? null : onRefresh,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(
                auth.refreshingProfile
                    ? l10n.authProfileRefreshing
                    : l10n.authRefreshProfile,
              ),
            ),
            FilledButton.icon(
              onPressed: auth.busy ? null : onSignIn,
              icon: const Icon(LucideIcons.calendarCheck, size: 16),
              label: Text(
                auth.signingIn ? l10n.authSigningIn : l10n.authSignIn,
              ),
            ),
            OutlinedButton.icon(
              onPressed: auth.busy ? null : onLogout,
              icon: const Icon(LucideIcons.logOut, size: 16),
              label: Text(l10n.accountLogout),
            ),
          ],
        ),
        if (result != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.bgSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.signed || result.alreadySigned
                      ? l10n.authSignedToday
                      : l10n.authSignIn,
                  style: TextStyle(
                    fontWeight: AppTypography.medium,
                    color: colors.textPrimary,
                  ),
                ),
                Text(l10n.authSignInReward(result.todayReward)),
                Text(
                  l10n.authWalletBalance(
                    result.balance.format(withSymbol: false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

final class _CloudSync extends ConsumerWidget {
  const _CloudSync({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(syncControllerProvider.notifier);
    final l10n = context.l10n;
    final colors = context.appColors;
    final lastSyncAt = state.lastSyncAt;
    final lastSyncLabel = lastSyncAt == null
        ? l10n.accountNeverSynced
        : DateFormat.yMMMd(l10n.localeName).add_Hms().format(lastSyncAt);
    return AppSectionCard(
      title: l10n.accountCloudSyncTitle,
      subtitle: l10n.accountCloudSyncSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppChip(
                label: _statusLabel(l10n, state.status),
                color: state.status == SyncStatus.failure
                    ? colors.error
                    : colors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.accountPendingChanges(state.dirtyCount),
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.accountLastSyncAt(lastSyncLabel),
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: colors.textTertiary,
            ),
          ),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                state.message!,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.brand,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.accountAutoSyncHourly),
            value: state.autoSync,
            onChanged: controller.setAutoSync,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: controller.syncNow,
              icon: const Icon(LucideIcons.cloudUpload, size: 16),
              label: Text(l10n.accountManualSync),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, SyncStatus status) =>
      switch (status) {
        SyncStatus.idle => l10n.accountStatusIdle,
        SyncStatus.syncing => l10n.accountStatusSyncing,
        SyncStatus.success => l10n.accountStatusSuccess,
        SyncStatus.failure => l10n.accountStatusFailure,
      };
}
