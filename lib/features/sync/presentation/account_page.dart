/// 账号 / 云同步页：登录、自动登录、VIP、手动同步、同步统计。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final emailController = TextEditingController(text: state.account.email);
    final passwordController = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        AppSectionCard(
          title: '账号',
          subtitle: '登录后可以同步和备份日历清单',
          trailing: state.account.isVip
              ? const AppChip(label: 'VIP')
              : null,
          child: state.account.isLoggedIn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${state.account.displayName}（${state.account.email}）',
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
                          const AppChip(label: '自动登录'),
                        if (state.account.readOnly)
                          const AppChip(label: '只读成员'),
                        if (state.account.teamAccount)
                          const AppChip(label: '团队账号'),
                        OutlinedButton(
                          onPressed: controller.logout,
                          child: const Text('退出登录'),
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
                      decoration: const InputDecoration(
                        labelText: '邮箱 / 手机号',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
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
                        child: const Text('登录 / 注册'),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: '云同步',
          subtitle: '记录变更 → 手动 / 自动同步 → 状态回写',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppChip(
                    label: _statusLabel(state.status),
                    color: state.status == SyncStatus.failure
                        ? colors.error
                        : colors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '待同步变更 ${state.dirtyCount} 条',
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '上次同步：${state.lastSyncAt == null ? '从未同步' : state.lastSyncAt!.toIso8601String().substring(0, 19)}',
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.textTertiary,
                ),
              ),
              Text(
                '上传 ${state.uploaded} 条 / 下载 ${state.downloaded} 条',
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
                title: const Text('每个整点自动同步'),
                value: state.autoSync,
                onChanged: (bool v) => controller.setAutoSync(v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: controller.syncNow,
                  icon: const Icon(LucideIcons.cloudUpload, size: 16),
                  label: const Text('手动同步'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(SyncStatus status) => switch (status) {
        SyncStatus.idle => '空闲',
        SyncStatus.syncing => '同步中',
        SyncStatus.success => '同步成功',
        SyncStatus.failure => '同步失败',
      };
}
