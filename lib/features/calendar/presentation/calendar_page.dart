/// 主日历页：月历网格 + 单元格编辑面板 + 倒数日条 + 右键菜单。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../countdown/application/countdown_controller.dart';
import '../../countdown/domain/countdown.dart';
import '../../desktop/application/desktop_controller.dart';
import '../../notes/application/notes_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../application/calendar_controllers.dart';
import 'dialogs/context_dialogs.dart';
import 'dialogs/event_editor_dialog.dart';
import 'widgets/calendar_title_bar.dart';
import 'widgets/cell_editor_panel.dart';
import 'widgets/countdown_bar.dart';
import 'widgets/month_grid.dart';

final class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthDataProvider);
    final settings = ref.watch(settingsControllerProvider);
    final calendar = ref.watch(calendarControllerProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final controller = ref.read(calendarControllerProvider.notifier);

    return Column(
      children: <Widget>[
        CalendarTitleBar(onNewEvent: () => _newEvent(context, ref, null)),
        if (calendar.error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Text(
              calendar.error!,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: context.appColors.error,
              ),
            ),
          ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: calendar.loading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: MonthGrid(
                            data: data,
                            settings: settings,
                            selectedDate: selectedDate,
                            onTap: (CalendarDayModel day) => ref
                                .read(selectedDateProvider.notifier)
                                .select(day.date),
                            onDoubleTap: (CalendarDayModel day) => ref
                                .read(selectedDateProvider.notifier)
                                .select(day.date),
                            onSecondaryTap: (
                              CalendarDayModel day,
                              Offset position,
                            ) =>
                                _contextMenu(context, ref, day, position),
                            onToggleLine: (
                              CalendarDayModel day,
                              String lineId,
                            ) =>
                                controller.toggleLineCompleted(
                              day.date,
                              lineId,
                            ),
                            onToggleEvent: (
                              CalendarDayModel day,
                              EventOccurrence occurrence,
                            ) =>
                                controller.toggleEventCompleted(
                              occurrence.event,
                              day.date,
                            ),
                          ),
                        ),
                ),
              ),
              if (selectedDate != null) CellEditorPanel(date: selectedDate),
            ],
          ),
        ),
        CountdownBar(items: data.countdownBar),
      ],
    );
  }

  Future<void> _newEvent(
    BuildContext context,
    WidgetRef ref,
    DateKey? date,
  ) async {
    final result = await showEventEditorDialog(
      context,
      initialDate:
          date ?? DateKey.today(ref.read(clockProvider).now()),
    );
    if (result == null) return;
    await ref.read(calendarControllerProvider.notifier).createEvent(
          content: result.content,
          startDate: result.startDate,
          type: result.type,
          color: result.color,
          backgroundColor: result.backgroundColor,
          recurrence: result.recurrence,
          reminder: result.reminder,
        );
  }

  Future<void> _contextMenu(
    BuildContext context,
    WidgetRef ref,
    CalendarDayModel day,
    Offset position,
  ) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'edit', child: Text('编辑本日内容')),
        PopupMenuItem<String>(value: 'new_event', child: Text('新建重复任务 / 提醒')),
        PopupMenuItem<String>(value: 'copy', child: Text('复制本日内容')),
        PopupMenuItem<String>(value: 'paste', child: Text('粘贴到本日')),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'cell_color', child: Text('设置单元格颜色')),
        PopupMenuItem<String>(value: 'clear', child: Text('清空本日内容')),
        PopupMenuItem<String>(value: 'delete_event', child: Text('删除重复任务…')),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'countdown', child: Text('添加倒数日')),
        PopupMenuItem<String>(value: 'note', child: Text('打开桌面便签')),
      ],
    );
    if (action == null || !context.mounted) return;
    final controller = ref.read(calendarControllerProvider.notifier);
    switch (action) {
      case 'edit':
        ref.read(selectedDateProvider.notifier).select(day.date);
      case 'new_event':
        await _newEvent(context, ref, day.date);
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: day.cell?.snapshot ?? ''),
        );
        _toast(ref, '已复制本日内容');
      case 'paste':
        final clipboard = await Clipboard.getData('text/plain');
        final text = clipboard?.text ?? '';
        if (text.isNotEmpty) {
          await controller.restoreCellFromText(day.date, text);
        }
      case 'cell_color':
        if (!context.mounted) break;
        final picked = await showColorPickerDialog(
          context,
          selected: day.cell?.backgroundColor ?? EventColor.transparent,
        );
        if (picked != null) {
          await controller.setCellBackgroundColor(day.date, picked);
        }
      case 'clear':
        if (!context.mounted) break;
        final confirmed = await showClearConfirmDialog(context, '本日内容');
        if (confirmed) {
          await controller.saveCellLines(day.date, const <RichLine>[]);
        }
      case 'delete_event':
        if (!context.mounted) break;
        await _deleteEvent(context, ref, day);
      case 'countdown':
        await ref.read(countdownControllerProvider.notifier).create(
              title: '${day.date.month}月${day.date.day}日',
              targetDate: day.date,
              type: CountdownType.custom,
            );
        _toast(ref, '已添加倒数日');
      case 'note':
        final note = await ref
            .read(notesControllerProvider.notifier)
            .create(title: day.date.cnFull);
        if (note != null) {
          await ref
              .read(notesControllerProvider.notifier)
              .openDesktopWindow(note.id);
        }
    }
  }

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarDayModel day,
  ) async {
    if (day.events.isEmpty) {
      _toast(ref, '本日没有任务');
      return;
    }
    final scope = await showDeleteScopeDialog(context);
    if (scope == null) return;
    final occurrence = day.events.first;
    await ref.read(calendarControllerProvider.notifier).deleteEvent(
          occurrence.event,
          onDate: day.date,
          scope: scope,
        );
  }

  void _toast(WidgetRef ref, String message) {
    // 桌面控制器是全局消息通道，壳层统一呈现。
    ref.read(desktopControllerProvider.notifier).notify(message);
  }
}
