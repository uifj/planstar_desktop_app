/// 右键菜单相关的通用弹窗：调色板、删除范围三态、清空确认。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/value_objects.dart';
import '../../../../shared/widgets/common.dart';
import '../../domain/calendar_event.dart';

Future<EventColor?> showColorPickerDialog(
  BuildContext context, {
  required EventColor selected,
}) => showDialog<EventColor>(
  context: context,
  builder: (BuildContext context) => AppDialogFrame(
    title: '选择颜色',
    width: 420,
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
    ],
    child: ColorSwatchPicker(
      selected: selected,
      onSelected: (EventColor color) => Navigator.of(context).pop(color),
    ),
  ),
);

Future<DeleteScope?> showDeleteScopeDialog(BuildContext context) =>
    showDialog<DeleteScope>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('删除重复任务'),
        children: <Widget>[
          for (final scope in DeleteScope.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(scope),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(scope.label),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: CheckboxListTile(
              value: false,
              onChanged: (_) {},
              title: Text(
                '所有冲突都选择该方法',
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: context.appColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );

Future<bool> showClearConfirmDialog(
  BuildContext context,
  String target,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('确认清空'),
        content: Text('将清空 $target 的全部内容，此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    ) ??
    false;
