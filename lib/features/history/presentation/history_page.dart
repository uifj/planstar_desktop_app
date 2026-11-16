/// 历史记录页：内容留痕 / 恢复到指定日期 / 清空。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/common.dart';
import '../../calendar/presentation/dialogs/context_dialogs.dart';
import '../application/history_controller.dart';
import '../domain/history_entry.dart';

final class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Text(
                '历史记录（${state.items.length}）',
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed =
                      await showClearConfirmDialog(context, '历史记录');
                  if (confirmed) await controller.clear();
                },
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('清空历史'),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.items.isEmpty
              ? const EmptyState(
                  icon: Icons.history_outlined,
                  title: '暂无历史记录',
                  hint: '编辑单元格或便签会自动留痕',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (BuildContext context, int index) {
                    final entry = state.items[index];
                    return ListTile(
                      tileColor: context.appColors.bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      leading: Icon(
                        entry.kind == HistoryKind.cell
                            ? Icons.calendar_today_outlined
                            : Icons.sticky_note_2_outlined,
                      ),
                      title: Text(
                        entry.content.isEmpty ? '（清空内容）' : entry.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.occurredAt.toIso8601String().substring(0, 19)} · '
                        '${entry.kind == HistoryKind.cell ? '单元格' : '便签'} · '
                        '${entry.targetId}',
                      ),
                      trailing: Wrap(
                        spacing: AppSpacing.xs,
                        children: <Widget>[
                          if (entry.kind == HistoryKind.cell)
                            OutlinedButton(
                              onPressed: () => controller.revertCell(entry),
                              child: const Text('恢复'),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () => controller.remove(entry.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
