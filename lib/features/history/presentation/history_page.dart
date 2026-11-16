/// 历史记录页：内容留痕 / 搜索筛选 / 按日期分组 / 恢复到指定日期 / 清空。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/value_objects.dart';
import '../../../shared/widgets/common.dart';
import '../../calendar/presentation/dialogs/context_dialogs.dart';
import '../application/history_controller.dart';
import '../domain/history_entry.dart';

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
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    // 内存筛选：历史条目规模有限，无需下推到仓储；保留全量 items 供导出等复用。
    final visible = state.items.where((HistoryEntry e) {
      if (_kindFilter != null && e.kind != _kindFilter) return false;
      if (_keyword.isEmpty) return true;
      return e.content.toLowerCase().contains(_keyword) ||
          e.targetId.toLowerCase().contains(_keyword) ||
          _kindLabel(e.kind).contains(_keyword);
    }).toList(growable: false);
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
                '历史记录（${state.items.length}）',
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
                        final confirmed =
                            await showClearConfirmDialog(context, '历史记录');
                        if (confirmed && mounted) await controller.clear();
                      },
                icon: const Icon(LucideIcons.eraser, size: 16),
                label: const Text('清空历史'),
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
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(LucideIcons.search, size: 16),
                    hintText: '搜索历史内容…',
                    border: OutlineInputBorder(),
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
                      filter == null ? '全部' : _kindLabel(filter),
                    ),
                    selected: _kindFilter == filter,
                    onSelected: (bool selected) =>
                        setState(() => _kindFilter = selected ? filter : null),
                  ),
                ),
              const Spacer(),
              Text(
                '显示 ${visible.length} 条',
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
            false when state.items.isEmpty => const EmptyState(
                icon: LucideIcons.history,
                title: '暂无历史记录',
                hint: '编辑日历格子或便签会自动留痕',
              ),
            false when visible.isEmpty => const EmptyState(
                icon: LucideIcons.searchX,
                title: '没有匹配的历史',
                hint: '换个关键词或筛选条件试试',
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
                          _groupLabel(group.key),
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
    final isCell = entry.kind == HistoryKind.cell;
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
        entry.content.isEmpty ? '（清空内容）' : entry.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_relativeTime(entry.occurredAt)} · ${_kindLabel(entry.kind)} · '
        '${isCell ? DateKey.parse(entry.targetId).cnDate : '便签'}',
        style: TextStyle(fontSize: AppTypography.caption),
      ),
      trailing: Wrap(
        spacing: AppSpacing.xxs,
        children: <Widget>[
          if (isCell)
            OutlinedButton(
              onPressed: () => _confirmRevert(context, controller, entry),
              child: const Text('恢复'),
            ),
          IconButton(
            tooltip: '删除这条记录',
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: () async {
              final confirmed = await showClearConfirmDialog(context, '这条历史');
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
    final date = DateKey.parse(entry.targetId);
    final newer = controller.hasNewerContent(entry);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(newer ? '当前内容更新' : '恢复历史内容'),
        content: Text(
          newer
              ? '${date.cnDate} 的当前内容比这条历史更新，恢复会覆盖较新内容。确定继续吗？'
              : '将 ${date.cnDate} 的格子内容恢复为这条历史快照？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final outcome = await controller.revertCell(
      entry,
      overwriteNewer: newer,
    );
    if (!context.mounted) return;
    final message = switch (outcome) {
      RevertOutcome.success => '已恢复到 ${date.cnDate}',
      RevertOutcome.newerContent => '当前内容更新，已取消恢复',
      RevertOutcome.invalidEntry => '这条记录无法恢复',
      RevertOutcome.failed => '恢复失败，请稍后重试',
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

  String _groupLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return DateKey(day).cnDate;
  }

  String _relativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    final hhmm = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前 · $hhmm';
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(time.year, time.month, time.day))
        .inDays;
    if (days == 0) return '今天 $hhmm';
    if (days == 1) return '昨天 $hhmm';
    return '${time.month}月${time.day}日 $hhmm';
  }

  String _kindLabel(HistoryKind kind) => switch (kind) {
        HistoryKind.cell => '日历格子',
        HistoryKind.note => '便签',
      };
}

final class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              LucideIcons.circleAlert,
              size: 32,
              color: context.appColors.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('加载失败：$message'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      );
}
