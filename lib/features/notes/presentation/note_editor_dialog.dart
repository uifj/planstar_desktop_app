/// 便签编辑弹窗：标题、逐行富文本、背景色、删除行、独立窗口。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../../shared/widgets/common.dart';
import '../../calendar/presentation/dialogs/context_dialogs.dart';
import '../application/notes_controller.dart';
import '../domain/note.dart';

Future<void> showNoteEditorDialog(BuildContext context, String noteId) =>
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => NoteEditorDialog(noteId: noteId),
    );

final class NoteEditorDialog extends ConsumerStatefulWidget {
  const NoteEditorDialog({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

final class _NoteEditorDialogState extends ConsumerState<NoteEditorDialog> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notesControllerProvider);
    Note? note;
    for (final item in state.items) {
      if (item.id == widget.noteId) note = item;
    }
    if (note == null) {
      return const AppDialogFrame(title: '便签', child: Text('便签不存在或已被删除'));
    }
    if (_titleController.text != note.title) {
      _titleController.text = note.title;
    }
    final controller = ref.read(notesControllerProvider.notifier);
    return AppDialogFrame(
      title: '编辑便签',
      width: 560,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => controller.rename(note!.id, value),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '背景颜色',
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: context.appColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ColorSwatchPicker(
            selected: note.backgroundColor,
            onSelected: (EventColor color) => controller.setBackground(
              note!.id,
              EventColor.palette
                  .indexOf(color)
                  .clamp(0, EventColor.palette.length - 1),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final line in note.lines)
            Row(
              children: <Widget>[
                Checkbox(
                  value: line.completed,
                  onChanged: (_) => controller.saveLines(
                    note!.id,
                    note.lines
                        .map(
                          (RichLine l) => l.id == line.id
                              ? l.copyWith(completed: !l.completed)
                              : l,
                        )
                        .toList(),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>(line.id),
                    initialValue: line.text,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (String value) => controller.saveLines(
                      note!.id,
                      note.lines
                          .map(
                            (RichLine l) =>
                                l.id == line.id ? l.copyWith(text: value) : l,
                          )
                          .toList(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.palette, size: 16),
                  onPressed: () async {
                    final color = await showColorPickerDialog(
                      context,
                      selected: line.color,
                    );
                    if (color == null) return;
                    await controller.saveLines(
                      note!.id,
                      note.lines
                          .map(
                            (RichLine l) =>
                                l.id == line.id ? l.copyWith(color: color) : l,
                          )
                          .toList(),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: () => controller.saveLines(
                    note!.id,
                    note.lines.where((RichLine l) => l.id != line.id).toList(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => controller.saveLines(note!.id, <RichLine>[
                  ...note.lines,
                  RichLine(id: ref.read(idGeneratorProvider).next(), text: ''),
                ]),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('添加一行'),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.openDesktopWindow(note!.id),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: const Text('独立窗口'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
