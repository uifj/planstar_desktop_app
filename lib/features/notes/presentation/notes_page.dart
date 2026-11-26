/// 便签管理页：网格 / 增删改 / 显隐 / 置顶 / 桌面独立窗口。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/notes_controller.dart';
import '../domain/note.dart';
import 'note_editor_dialog.dart';

final class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
                l10n.notesHeading(state.items.length),
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
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(l10n.notesNewNote),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.items.isEmpty
              ? EmptyState(
                  icon: LucideIcons.stickyNote,
                  title: l10n.notesEmptyTitle,
                  hint: l10n.notesEmptyHint,
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
    final l10n = context.l10n;
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
                    note.localizedTitle(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.subtitle,
                      fontWeight: AppTypography.medium,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (note.topMost) AppChip(label: l10n.notesPinned, dense: true),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Text(
                note.plainText.isEmpty ? l10n.notesEmpty : note.plainText,
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
                  tooltip: note.visible ? l10n.notesHide : l10n.notesShow,
                  icon: Icon(
                    note.visible ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 16,
                  ),
                  onPressed: () => controller.toggleVisible(note.id),
                ),
                IconButton(
                  tooltip: l10n.notesPinWindow,
                  icon: const Icon(LucideIcons.pin, size: 16),
                  onPressed: () => controller.toggleTopMost(note.id),
                ),
                IconButton(
                  tooltip: l10n.notesOpenWindow,
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  onPressed: () => controller.openDesktopWindow(note.id),
                ),
                IconButton(
                  tooltip: l10n.commonDelete,
                  icon: Icon(LucideIcons.trash2, size: 16, color: colors.error),
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
