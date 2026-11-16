/// 统一 UI 组件库。
///
/// 所有颜色 / 字号 / 圆角 / 间距都来自 `packages/infras/core_design_system`，
/// 本文件不出现任何硬编码色值。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';

import '../../core/value_objects.dart';

/// 领域颜色值对象 → Flutter Color。
extension EventColorX on EventColor {
  Color toColor() => Color(argb);
}

/// 分组卡片。
final class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppTypography.subtitle,
                        fontWeight: AppTypography.medium,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// 开关设置行。
final class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: TextStyle(fontSize: AppTypography.body, color: colors.textPrimary),
      ),
      subtitle: description == null
          ? null
          : Text(
              description!,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: colors.textTertiary,
              ),
            ),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// 下拉设置行。
final class SettingDropdown<T> extends StatelessWidget {
  const SettingDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.body,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 数值滑杆设置行。
final class SettingSlider extends StatelessWidget {
  const SettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.display,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String? display;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.body,
              color: colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            display ?? value.toStringAsFixed(1),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 空状态。
final class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: colors.textDisabled),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: AppTypography.subtitle,
              color: colors.textSecondary,
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                hint!,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.textTertiary,
                ),
              ),
            ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: action,
            ),
        ],
      ),
    );
  }
}

/// 状态标签。
final class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.color,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effective = color ?? colors.brand;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.xs : AppSpacing.sm,
        vertical: dense ? 2 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.label,
          color: effective,
        ),
      ),
    );
  }
}

/// 23 色调色板 + 「最近使用」区域。
final class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.recent = const <EventColor>[],
  });

  final EventColor selected;
  final ValueChanged<EventColor> onSelected;
  final List<EventColor> recent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          recent.isEmpty ? '文字颜色 / 单元格颜色' : '最近使用',
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: colors.textTertiary,
          ),
        ),
        if (recent.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: _swatchRow(context, recent),
          ),
        Text(
          '全部颜色',
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _swatchRow(context, EventColor.palette),
      ],
    );
  }

  Widget _swatchRow(BuildContext context, List<EventColor> palette) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: palette
            .map(
              (EventColor color) => InkWell(
                onTap: () => onSelected(color),
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
                  child: color.isTransparent
                      ? const Icon(Icons.block, size: 14)
                      : null,
                ),
              ),
            )
            .toList(),
      );
}

/// 通用弹窗骨架。
final class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.width = 520,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Dialog(
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.medium,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(child: SingleChildScrollView(child: child)),
              if (actions != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
