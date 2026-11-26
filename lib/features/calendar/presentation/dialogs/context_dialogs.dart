/// 右键菜单相关的通用弹窗：调色板、删除范围三态、清空确认。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';

import '../../../../core/value_objects.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/common.dart';
import '../../domain/calendar_event.dart';

Future<EventColor?> showColorPickerDialog(
  BuildContext context, {
  required EventColor selected,
}) {
  final l10n = context.l10n;
  return showDialog<EventColor>(
    context: context,
    builder: (BuildContext context) => AppDialogFrame(
      title: l10n.calendarColorPickerTitle,
      width: 420,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
      child: _CalendarColorSwatchPicker(selected: selected),
    ),
  );
}

Future<DeleteScope?> showDeleteScopeDialog(BuildContext context) {
  final l10n = context.l10n;
  return showDialog<DeleteScope>(
    context: context,
    builder: (BuildContext context) => SimpleDialog(
      title: Text(l10n.calendarDeleteRecurringEventTitle),
      children: <Widget>[
        for (final scope in DeleteScope.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(scope),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(scope.localizedLabel(l10n)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: CheckboxListTile(
            value: false,
            onChanged: (_) {},
            title: Text(
              l10n.calendarDeleteScopeRememberChoice,
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
}

Future<bool> showClearConfirmDialog(BuildContext context, String target) async {
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(l10n.calendarClearConfirmTitle),
          content: Text(l10n.calendarClearConfirmMessage(target)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.calendarClearAction),
            ),
          ],
        ),
      ) ??
      false;
}

/// Calendar-local swatches keep their labels localized without changing the
/// shared picker used by other features.
final class _CalendarColorSwatchPicker extends StatelessWidget {
  const _CalendarColorSwatchPicker({required this.selected});

  final EventColor selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.calendarColorPickerDescription,
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: context.appColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.calendarAllColors,
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: context.appColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: EventColor.palette.map((EventColor color) {
            final label = color.isTransparent
                ? l10n.calendarTransparentColor
                : l10n.calendarColorValue(color.hex);
            return Tooltip(
              message: label,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(color),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.isTransparent ? null : color.toColor(),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: color == selected
                          ? context.appColors.brand
                          : context.appColors.border,
                      width: color == selected ? 2 : 1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
