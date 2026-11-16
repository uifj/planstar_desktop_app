/// 单元格富文本编辑面板（旧版双击单元格进入的编辑态）。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/core_providers.dart';
import '../../../../core/value_objects.dart';
import '../../../../shared/widgets/common.dart';
import '../../application/calendar_controllers.dart';
import '../../domain/day_cell.dart';
import '../dialogs/context_dialogs.dart';
import '../dialogs/event_editor_dialog.dart';

final class CellEditorPanel extends ConsumerWidget {
  const CellEditorPanel({super.key, required this.date});

  final DateKey date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final state = ref.watch(calendarControllerProvider);
    final cell = state.cells.where((DayCell c) => c.date == date).toList();
    final lines = cell.isEmpty
        ? const <RichLine>[]
        : cell.first.lines;
    final controller = ref.read(calendarControllerProvider.notifier);

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Text(
                  '${date.cnFull} 周${date.cnWeekday}',
                  style: TextStyle(
                    fontSize: AppTypography.subtitle,
                    fontWeight: AppTypography.medium,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      ref.read(selectedDateProvider.notifier).clear(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: <Widget>[
                for (final line in lines)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Row(
                        children: <Widget>[
                          Checkbox(
                            value: line.completed,
                            onChanged: (_) => controller.toggleLineCompleted(
                              date,
                              line.id,
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey<String>(line.id),
                              initialValue: line.text,
                              maxLines: null,
                              style: TextStyle(
                                fontSize: AppTypography.body,
                                color: line.color.toColor(),
                                decoration: line.completed
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (String value) =>
                                  controller.saveCellLines(
                                date,
                                lines
                                    .map(
                                      (RichLine l) => l.id == line.id
                                          ? l.copyWith(text: value)
                                          : l,
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.palette_outlined, size: 16),
                            onPressed: () async {
                              final picked = await showColorPickerDialog(
                                context,
                                selected: line.color,
                              );
                              if (picked != null) {
                                await controller.setLineColor(
                                  date,
                                  line.id,
                                  picked,
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.repeat, size: 16),
                            tooltip: '设为重复任务',
                            onPressed: () => _promote(context, ref, line),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () =>
                                controller.removeLine(date, line.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Text(
                      '双击单元格或直接添加一行开始记录',
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => controller.saveCellLines(
                    date,
                    <RichLine>[
                      ...lines,
                      RichLine(
                        id: ref.read(idGeneratorProvider).next(),
                        text: '',
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加一行'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showColorPickerDialog(
                      context,
                      selected: EventColor.transparent,
                    );
                    if (picked != null) {
                      await controller.setCellBackgroundColor(date, picked);
                    }
                  },
                  icon: const Icon(Icons.format_color_fill, size: 16),
                  label: const Text('单元格颜色'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed =
                        await showClearConfirmDialog(context, '本日内容');
                    if (confirmed) {
                      await controller.saveCellLines(
                        date,
                        const <RichLine>[],
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('清空'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promote(
    BuildContext context,
    WidgetRef ref,
    RichLine line,
  ) async {
    final result = await showEventEditorDialog(
      context,
      initialDate: date,
      initialContent: line.text,
    );
    if (result == null) return;
    await ref.read(calendarControllerProvider.notifier).promoteLineToEvent(
          date,
          line.id,
          result.type,
          recurrence: result.recurrence,
          reminder: result.reminder,
        );
  }
}
