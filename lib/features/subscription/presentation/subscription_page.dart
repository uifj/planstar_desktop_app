/// 订阅日历页：本地 / Google / Outlook / iCloud / CalDAV 订阅与同步。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/subscription_controller.dart';
import '../domain/subscription.dart';

final class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
                l10n.subscriptionHeading(state.items.length),
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
                label: Text(l10n.subscriptionSyncAll),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(l10n.subscriptionAdd),
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
              ? EmptyState(
                  icon: LucideIcons.rss,
                  title: l10n.subscriptionEmptyTitle,
                  hint: l10n.subscriptionEmptyHint,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = state.items[index];
                    final lastSyncAt = item.lastSyncAt;
                    final lastSync = lastSyncAt == null
                        ? l10n.subscriptionNeverSynced
                        : l10n.subscriptionLastSyncedAt(
                            DateKey(lastSyncAt).fullDate(l10n),
                            DateFormat.Hm(l10n.localeName).format(lastSyncAt),
                          );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppSectionCard(
                        title: item.name,
                        subtitle: l10n.subscriptionSummary(
                          item.source.localizedLabel(l10n),
                          item.events.length,
                          lastSync,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Semantics(
                              label: l10n.subscriptionEnabled,
                              toggled: item.enabled,
                              child: Switch(
                                value: item.enabled,
                                onChanged: (_) => controller.toggle(item.id),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.subscriptionDelete,
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
                              tooltip: l10n.subscriptionCopyLink,
                              icon: const Icon(LucideIcons.copy, size: 16),
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: item.shareLink),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => controller.refresh(item.id),
                              child: Text(l10n.subscriptionSync),
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
    final l10n = context.l10n;
    final nameController = TextEditingController();
    final linkController = TextEditingController();
    var source = SubscriptionSource.local;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AppDialogFrame(
          title: l10n.subscriptionCreateTitle,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonAdd),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.subscriptionName),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: linkController,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionShareLinkHint,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: l10n.subscriptionSource,
                child: DropdownButton<SubscriptionSource>(
                  value: source,
                  icon: const Icon(LucideIcons.chevronDown, size: 16),
                  isExpanded: true,
                  items: SubscriptionSource.values
                      .map(
                        (SubscriptionSource s) =>
                            DropdownMenuItem<SubscriptionSource>(
                              value: s,
                              child: Text(s.localizedLabel(l10n)),
                            ),
                      )
                      .toList(),
                  onChanged: (SubscriptionSource? v) =>
                      setState(() => source = v ?? source),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || nameController.text.trim().isEmpty) return;
    await ref
        .read(subscriptionControllerProvider.notifier)
        .create(
          name: nameController.text.trim(),
          shareLink: linkController.text.trim(),
          source: source,
        );
    nameController.dispose();
    linkController.dispose();
  }
}
