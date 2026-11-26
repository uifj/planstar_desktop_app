/// 账号 / 云同步页：登录、自动登录、VIP、手动同步、同步统计。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/sync_controller.dart';
import '../domain/sync_models.dart';

final class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    final colors = context.appColors;
    final l10n = context.l10n;
    final lastSyncAt = state.lastSyncAt;
    final lastSyncLabel = lastSyncAt == null
        ? l10n.accountNeverSynced
        : DateFormat.yMMMd(l10n.localeName).add_Hms().format(lastSyncAt);
    final emailController = TextEditingController(text: state.account.email);
    final passwordController = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        AppSectionCard(
          title: l10n.accountTitle,
          subtitle: l10n.accountSubtitle,
          trailing: state.account.isVip
              ? AppChip(label: l10n.accountVip)
              : null,
          child: state.account.isLoggedIn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.accountIdentity(
                        state.account.displayName,
                        state.account.email,
                      ),
                      style: TextStyle(
                        fontSize: AppTypography.subtitle,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: <Widget>[
                        if (state.account.autoLogin)
                          AppChip(label: l10n.accountAutoLogin),
                        if (state.account.readOnly)
                          AppChip(label: l10n.accountReadOnlyMember),
                        if (state.account.teamAccount)
                          AppChip(label: l10n.accountTeamAccount),
                        OutlinedButton(
                          onPressed: controller.logout,
                          child: Text(l10n.accountLogout),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: l10n.accountEmailOrPhone,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.accountPassword,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => controller.login(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        ),
                        child: Text(l10n.accountLoginOrRegister),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
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
              Text(
                '${l10n.accountUploadedCount(state.uploaded)} / '
                '${l10n.accountDownloadedCount(state.downloaded)}',
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
                onChanged: (bool v) => controller.setAutoSync(v),
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
        ),
      ],
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
