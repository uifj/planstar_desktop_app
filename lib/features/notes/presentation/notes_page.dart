/// 便签管理页：网格 / 增删改 / 显隐 / 置顶 / 桌面独立窗口。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/common.dart';
import '../application/notes_controller.dart';
import '../domain/note.dart';
import 'note_editor_dialog.dart';

final class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notesControllerProvider);
    final controller = ref.read(notesControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Text(
                '便签（${state.items.length}）',
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  final note = await controller.create();
                  if (note != null && context.mounted) {
                    await showNoteEditorDialog(context, note.id);
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('新建便签'),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.items.isEmpty
                  ? const EmptyState(
                      icon: Icons.sticky_note_2_outlined,
                      title: '暂无便签',
                      hint: '点击右上角新建，便签可以独立窗口置顶显示',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        mainAxisExtent: 190,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                      ),
                      itemCount: state.items.length,
                      itemBuilder: (BuildContext context, int index) =>
                          _NoteCard(note: state.items[index]),
                    ),
        ),
      ],
    );
  }
}

final class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final controller = ref.read(notesControllerProvider.notifier);
    return InkWell(
      onTap: () => showNoteEditorDialog(context, note.id),
      child: Container(
        decoration: BoxDecoration(
          color: note.backgroundColor.toColor().withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.subtitle,
                      fontWeight: AppTypography.medium,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (note.topMost) const AppChip(label: '置顶', dense: true),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Text(
                note.plainText.isEmpty ? '（空便签）' : note.plainText,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: note.fontColor.toColor(),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  tooltip: note.visible ? '隐藏' : '显示',
                  icon: Icon(
                    note.visible ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                  ),
                  onPressed: () => controller.toggleVisible(note.id),
                ),
                IconButton(
                  tooltip: '窗口置顶',
                  icon: const Icon(Icons.push_pin_outlined, size: 16),
                  onPressed: () => controller.toggleTopMost(note.id),
                ),
                IconButton(
                  tooltip: '打开独立窗口',
                  icon: const Icon(Icons.open_in_new, size: 16),
                  onPressed: () => controller.openDesktopWindow(note.id),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: colors.error),
                  onPressed: () => controller.remove(note.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
