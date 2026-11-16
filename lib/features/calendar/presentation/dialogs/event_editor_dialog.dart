/// 事件编辑弹窗：对齐旧版 `event_frame.xml`（标题、日期、重复、提醒、颜色）。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../../../../core/value_objects.dart';
import '../../../../shared/widgets/common.dart';
import '../../domain/calendar_event.dart';
import '../../domain/recurrence.dart';
import '../../domain/reminder_spec.dart';
import 'context_dialogs.dart';

final class EventEditorResult {
  const EventEditorResult({
    required this.content,
    required this.startDate,
    required this.type,
    required this.color,
    required this.backgroundColor,
    required this.recurrence,
    required this.reminder,
  });

  final String content;
  final DateKey startDate;
  final CalendarEventType type;
  final EventColor color;
  final EventColor backgroundColor;
  final RecurrenceRule recurrence;
  final ReminderSpec? reminder;
}

/// 返回 `null` 表示取消；编辑既有事件时会带上 `eventId`。
Future<EventEditorResult?> showEventEditorDialog(
  BuildContext context, {
  CalendarEvent? event,
  DateKey? initialDate,
  String initialContent = '',
}) async =>
    showDialog<EventEditorResult>(
      context: context,
      builder: (BuildContext context) => EventEditorDialog(
        event: event,
        initialDate: initialDate,
        initialContent: initialContent,
      ),
    );

final class EventEditorDialog extends StatefulWidget {
  const EventEditorDialog({
    super.key,
    this.event,
    this.initialDate,
    this.initialContent = '',
  });

  final CalendarEvent? event;
  final DateKey? initialDate;
  final String initialContent;

  @override
  State<EventEditorDialog> createState() => _EventEditorDialogState();
}

final class _EventEditorDialogState extends State<EventEditorDialog> {
  late final TextEditingController _contentController;
  late DateKey _startDate;
  late CalendarEventType _type;
  late EventColor _color;
  late EventColor _backgroundColor;
  late RecurrenceRule _recurrence;
  late bool _hasReminder;
  late ReminderSpec _reminder;
  late final TextEditingController _customRepeatController;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _contentController = TextEditingController(
      text: event?.content ?? widget.initialContent,
    );
    _startDate = event?.startDate ??
        widget.initialDate ??
        DateKey.today(DateTime.now());
    _type = event?.type ?? CalendarEventType.task;
    _color = event?.color ?? EventColor.defaultText;
    _backgroundColor = event?.backgroundColor ?? EventColor.transparent;
    _recurrence = event?.recurrence ?? const RecurrenceRule();
    _hasReminder = event?.reminder != null;
    _reminder = event?.reminder ?? const ReminderSpec();
    _customRepeatController = TextEditingController(
      text: _reminder.customAdvanceDays.toString(),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _customRepeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      title: widget.event == null ? '新建任务 / 提醒' : '编辑任务 / 提醒',
      width: 620,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _contentController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '内容',
              hintText: '输入任务或提醒内容',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<CalendarEventType>(
                  initialValue: _type,
                  icon: const Icon(LucideIcons.chevronDown, size: 16),
                  decoration: const InputDecoration(labelText: '类型'),
                  items: CalendarEventType.values
                      .map(
                        (CalendarEventType t) => DropdownMenuItem<
                            CalendarEventType>(
                          value: t,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (CalendarEventType? value) =>
                      setState(() => _type = value ?? _type),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(LucideIcons.calendarClock, size: 16),
                  label: Text(_startDate.cnFull),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('重复规则', style: _label(context)),
          Wrap(
            spacing: AppSpacing.xs,
            children: <Widget>[
              SizedBox(
                width: 240,
                child: DropdownButton<RecurrenceKind>(
                  value: _recurrence.kind,
                  icon: const Icon(LucideIcons.chevronDown, size: 16),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: RecurrenceKind.values
                      .map(
                        (RecurrenceKind k) => DropdownMenuItem<RecurrenceKind>(
                          value: k,
                          child: Text(k.label),
                        ),
                      )
                      .toList(),
                  onChanged: (RecurrenceKind? value) => setState(
                    () => _recurrence = _recurrence.copyWith(kind: value),
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: _recurrence.interval.toString(),
                  decoration: const InputDecoration(labelText: '间隔'),
                  keyboardType: TextInputType.number,
                  onChanged: (String value) => setState(
                    () => _recurrence = _recurrence.copyWith(
                      interval: int.tryParse(value) ?? 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: <Widget>[
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text('周${CalendarMathShort.label(day)}'),
                  selected: _recurrence.weekdays.contains(day),
                  onSelected: (bool selected) => setState(() {
                    final days = List<int>.of(_recurrence.weekdays);
                    if (selected) {
                      days.add(day);
                    } else {
                      days.remove(day);
                    }
                    _recurrence = _recurrence.copyWith(weekdays: days);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('提醒', style: _label(context)),
          Row(
            children: <Widget>[
              Switch(
                value: _hasReminder,
                onChanged: (bool value) =>
                    setState(() => _hasReminder = value),
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton(
                onPressed: _hasReminder ? _pickTime : null,
                child: Text(_reminder.timeLabel),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.xs,
            children: <Widget>[
              for (final advance in ReminderSpec.optionalAdvanceDays)
                FilterChip(
                  label: Text(
                    advance == 0
                        ? '当天'
                        : (advance == -1 ? '自定义' : '$advance 天前'),
                  ),
                  selected: _reminder.advanceDays.contains(advance),
                  onSelected: (bool selected) => setState(() {
                    final days = List<int>.of(_reminder.advanceDays);
                    if (selected) {
                      days.add(advance);
                    } else {
                      days.remove(advance);
                    }
                    _reminder = _reminder.copyWith(advanceDays: days);
                  }),
                ),
              Checkbox(
                value: _reminder.wechatNotify,
                onChanged: (bool? value) => setState(
                  () => _reminder = _reminder.copyWith(
                    wechatNotify: value ?? false,
                  ),
                ),
              ),
              const Text('微信通知'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('颜色', style: _label(context)),
          Row(
            children: <Widget>[
              const Text('文字颜色'),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showColorPickerDialog(
                    context,
                    selected: _color,
                  );
                  if (picked != null) setState(() => _color = picked);
                },
                child: Icon(LucideIcons.palette,
                    size: 16, color: _color.toColor()),
              ),
              const SizedBox(width: AppSpacing.md),
              const Text('单元格颜色'),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showColorPickerDialog(
                    context,
                    selected: _backgroundColor,
                  );
                  if (picked != null) {
                    setState(() => _backgroundColor = picked);
                  }
                },
                child: const Icon(LucideIcons.paintBucket, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _label(BuildContext context) => TextStyle(
        fontSize: AppTypography.caption,
        color: context.appColors.textTertiary,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = DateKey(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (picked == null) return;
    setState(
      () => _reminder = _reminder.copyWith(
        hour: picked.hour,
        minute: picked.minute,
      ),
    );
  }

  void _submit() {
    if (_contentController.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      EventEditorResult(
        content: _contentController.text.trim(),
        startDate: _startDate,
        type: _type,
        color: _color,
        backgroundColor: _backgroundColor,
        recurrence: _recurrence,
        reminder: _hasReminder
            ? _reminder.copyWith(
                customAdvanceDays:
                    int.tryParse(_customRepeatController.text) ?? 0,
              )
            : null,
      ),
    );
  }
}

/// 只用于星期文案的小工具，避免对话框再引入整份日历数学。
abstract final class CalendarMathShort {
  static String label(int weekday) => const <String>[
        '一',
        '二',
        '三',
        '四',
        '五',
        '六',
        '日',
      ][weekday - 1];
}
