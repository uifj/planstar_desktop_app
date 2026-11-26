/// 历史记录页：内容留痕 / 搜索筛选 / 按日期分组 / 恢复到指定日期 / 清空。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/history_controller.dart';
import '../domain/history_entry.dart';
import 'history_localization.dart';

final class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

final class _HistoryPageState extends ConsumerState<HistoryPage> {
  final TextEditingController _search = TextEditingController();
  HistoryKind? _kindFilter;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() => _keyword = _search.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    // 内存筛选：历史条目规模有限，无需下推到仓储；保留全量 items 供导出等复用。
    final visible = state.items
        .where((HistoryEntry e) {
          if (_kindFilter != null && e.kind != _kindFilter) return false;
          if (_keyword.isEmpty) return true;
          final display = localizeHistoryEntry(e, l10n);
          return display.content.toLowerCase().contains(_keyword) ||
              display.author.toLowerCase().contains(_keyword) ||
              e.targetId.toLowerCase().contains(_keyword) ||
              _kindLabel(e.kind, l10n).toLowerCase().contains(_keyword);
        })
        .toList(growable: false);
    final groups = _groupsOf(visible).entries.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Text(
                l10n.historyTitle(state.items.length),
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: state.items.isEmpty
                    ? null
                    : () async {
                        final confirmed = await _showHistoryConfirmation(
                          context,
                          title: l10n.historyClearConfirmTitle,
                          message: l10n.historyClearConfirmMessage,
                          confirmLabel: l10n.historyClearAction,
                        );
                        if (confirmed && mounted) await controller.clear();
                      },
                icon: const Icon(LucideIcons.eraser, size: 16),
                label: Text(l10n.historyClearAction),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(LucideIcons.search, size: 16),
                    hintText: l10n.historySearchHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              for (final filter in <HistoryKind?>[
                null,
                HistoryKind.cell,
                HistoryKind.note,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(
                      filter == null
                          ? l10n.historyFilterAll
                          : _kindLabel(filter, l10n),
                    ),
                    selected: _kindFilter == filter,
                    onSelected: (bool selected) =>
                        setState(() => _kindFilter = selected ? filter : null),
                  ),
                ),
              const Spacer(),
              Text(
                l10n.historyVisibleCount(visible.length),
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (state.loading && state.items.isEmpty) {
            true => const Center(child: CircularProgressIndicator()),
            false when state.error != null && state.items.isEmpty =>
              _ErrorState(
                message: state.error!,
                onRetry: () => controller.load(),
              ),
            false when state.items.isEmpty => EmptyState(
              icon: LucideIcons.history,
              title: l10n.historyEmptyTitle,
              hint: l10n.historyEmptyHint,
            ),
            false when visible.isEmpty => EmptyState(
              icon: LucideIcons.searchX,
              title: l10n.historyNoMatchesTitle,
              hint: l10n.historyNoMatchesHint,
            ),
            false => ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              itemCount: groups.length,
              itemBuilder: (BuildContext context, int groupIndex) {
                final group = groups[groupIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        _groupLabel(group.key, context.l10n),
                        style: TextStyle(
                          fontSize: AppTypography.label,
                          fontWeight: AppTypography.bold,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    ...group.value.map(
                      (HistoryEntry entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _entryTile(context, controller, entry),
                      ),
                    ),
                  ],
                );
              },
            ),
          },
        ),
      ],
    );
  }

  Widget _entryTile(
    BuildContext context,
    HistoryController controller,
    HistoryEntry entry,
  ) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final display = localizeHistoryEntry(entry, l10n);
    final isCell = entry.kind == HistoryKind.cell;
    final kind = _kindLabel(entry.kind, l10n);
    final target = isCell
        ? DateKey.parse(entry.targetId).fullDate(l10n)
        : l10n.historyKindNote;
    final metadata = l10n.historyEntryMetadata(
      _relativeTime(entry.occurredAt, l10n),
      kind,
      target,
    );
    return ListTile(
      tileColor: colors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      leading: Icon(
        isCell ? LucideIcons.calendarCheck : LucideIcons.stickyNote,
        color: isCell ? colors.brand : colors.textSecondary,
      ),
      title: Text(
        display.content.isEmpty ? l10n.historyClearedContent : display.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        display.author.isEmpty ? metadata : '$metadata · ${display.author}',
        style: TextStyle(fontSize: AppTypography.caption),
      ),
      trailing: Wrap(
        spacing: AppSpacing.xxs,
        children: <Widget>[
          if (isCell)
            OutlinedButton(
              onPressed: () => _confirmRevert(context, controller, entry),
              child: Text(l10n.historyRestoreAction),
            ),
          IconButton(
            tooltip: l10n.historyDeleteRecordTooltip,
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: () async {
              final confirmed = await _showHistoryConfirmation(
                context,
                title: l10n.historyDeleteConfirmTitle,
                message: l10n.historyDeleteConfirmMessage,
                confirmLabel: l10n.commonDelete,
              );
              if (confirmed && mounted) await controller.remove(entry.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevert(
    BuildContext context,
    HistoryController controller,
    HistoryEntry entry,
  ) async {
    final l10n = context.l10n;
    final date = DateKey.parse(entry.targetId);
    final dateLabel = date.fullDate(l10n);
    final newer = controller.hasNewerContent(entry);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          newer ? l10n.historyNewerContentTitle : l10n.historyRestoreTitle,
        ),
        content: Text(
          newer
              ? l10n.historyNewerContentMessage(dateLabel)
              : l10n.historyRestoreMessage(dateLabel),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.historyRestoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final outcome = await controller.revertCell(entry, overwriteNewer: newer);
    if (!context.mounted) return;
    final strings = context.l10n;
    final message = switch (outcome) {
      RevertOutcome.success => strings.historyRestoredMessage(
        date.fullDate(strings),
      ),
      RevertOutcome.newerContent => strings.historyRestoreCancelled,
      RevertOutcome.invalidEntry => strings.historyRestoreInvalid,
      RevertOutcome.failed => strings.historyRestoreFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 按日期分组（保持 controller 已排好的降序）。
  Map<DateTime, List<HistoryEntry>> _groupsOf(List<HistoryEntry> items) {
    final groups = <DateTime, List<HistoryEntry>>{};
    for (final entry in items) {
      final day = DateTime(
        entry.occurredAt.year,
        entry.occurredAt.month,
        entry.occurredAt.day,
      );
      groups.putIfAbsent(day, () => <HistoryEntry>[]).add(entry);
    }
    return groups;
  }

  String _groupLabel(DateTime day, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l10n.commonToday;
    if (diff == 1) return l10n.historyYesterday;
    return DateKey(day).fullDate(l10n);
  }

  String _relativeTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);
    final timeLabel = DateFormat.jm(l10n.localeName).format(time);
    if (diff.inMinutes < 1) return l10n.historyJustNow;
    if (diff.inHours < 1) {
      return l10n.historyMinutesAgo(diff.inMinutes, timeLabel);
    }
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(time.year, time.month, time.day)).inDays;
    if (days == 0) return l10n.historyTodayAt(timeLabel);
    if (days == 1) return l10n.historyYesterdayAt(timeLabel);
    return l10n.historyDateAt(DateKey(time).shortDate(l10n), timeLabel);
  }

  String _kindLabel(HistoryKind kind, AppLocalizations l10n) => switch (kind) {
    HistoryKind.cell => l10n.historyKindCell,
    HistoryKind.note => l10n.historyKindNote,
  };
}

Future<bool> _showHistoryConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

final class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(LucideIcons.circleAlert, size: 32, color: context.appColors.error),
        const SizedBox(height: AppSpacing.sm),
        Text(context.l10n.historyLoadFailed(message)),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(LucideIcons.refreshCw, size: 16),
          label: Text(context.l10n.commonRetry),
        ),
      ],
    ),
  );
}
