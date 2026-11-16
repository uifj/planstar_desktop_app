/// 订阅日历页：本地 / Google / Outlook / iCloud / CalDAV 订阅与同步。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/common.dart';
import '../application/subscription_controller.dart';
import '../domain/subscription.dart';

final class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Text(
                '订阅日历（${state.items.length}）',
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => controller.refresh('', all: true),
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('同步全部'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('添加订阅'),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              state.error!,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: context.appColors.error,
              ),
            ),
          ),
        Expanded(
          child: state.items.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.rss,
                  title: '暂无订阅日历',
                  hint: '支持本地订阅与 Google / Outlook / iCloud / CalDAV',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = state.items[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppSectionCard(
                        title: item.name,
                        subtitle:
                            '${item.source.label} · ${item.events.length} 条推送 · '
                            '${item.lastSyncAt == null ? '尚未同步' : item.lastSyncAt!.toIso8601String().substring(0, 16)}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Switch(
                              value: item.enabled,
                              onChanged: (_) => controller.toggle(item.id),
                            ),
                            IconButton(
                              icon: Icon(
                                LucideIcons.trash2,
                                size: 16,
                                color: context.appColors.error,
                              ),
                              onPressed: () => controller.remove(item.id),
                            ),
                          ],
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.shareLink,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTypography.caption,
                                  color: context.appColors.textTertiary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '复制分享链接',
                              icon: const Icon(LucideIcons.copy, size: 16),
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: item.shareLink),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  controller.refresh(item.id),
                              child: const Text('同步'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final linkController = TextEditingController();
    var source = SubscriptionSource.local;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            AppDialogFrame(
          title: '添加订阅日历',
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('添加'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '订阅名称'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(
                  labelText: '分享链接（留空则生成本地订阅）',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButton<SubscriptionSource>(
                value: source,
                icon: const Icon(LucideIcons.chevronDown, size: 16),
                isExpanded: true,
                items: SubscriptionSource.values
                    .map(
                      (SubscriptionSource s) =>
                          DropdownMenuItem<SubscriptionSource>(
                        value: s,
                        child: Text(s.label),
                      ),
                    )
                    .toList(),
                onChanged: (SubscriptionSource? v) =>
                    setState(() => source = v ?? source),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || nameController.text.trim().isEmpty) return;
    await ref.read(subscriptionControllerProvider.notifier).create(
          name: nameController.text.trim(),
          shareLink: linkController.text.trim(),
          source: source,
        );
    nameController.dispose();
    linkController.dispose();
  }
}
