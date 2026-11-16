/// 导入导出页：数据库 / 文本 / CSV，范围与冲突策略。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/common.dart';
import '../application/transfer_controller.dart';

final class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

final class _TransferPageState extends ConsumerState<TransferPage> {
  ExportFormat _format = ExportFormat.database;
  ExportRange _range = ExportRange.allTime;
  bool _replaceConflicts = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferControllerProvider);
    final controller = ref.read(transferControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        AppSectionCard(
          title: '导出日历清单',
          subtitle: '支持再次导入的数据库文件、可打印文本、Excel 兼容 CSV',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  for (final format in ExportFormat.values)
                    ChoiceChip(
                      label: Text(format.label),
                      selected: _format == format,
                      onSelected: (_) =>
                          setState(() => _format = format),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('所有时间'),
                    selected: _range == ExportRange.allTime,
                    onSelected: (_) =>
                        setState(() => _range = ExportRange.allTime),
                  ),
                  ChoiceChip(
                    label: const Text('近半年'),
                    selected: _range == ExportRange.sixMonths,
                    onSelected: (_) =>
                        setState(() => _range = ExportRange.sixMonths),
                  ),
                  ChoiceChip(
                    label: const Text('自定义'),
                    selected: _range == ExportRange.custom,
                    onSelected: (_) =>
                        setState(() => _range = ExportRange.custom),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => controller.exportTo(
                            format: _format,
                            range: _range,
                          ),
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: const Text('导出到文件'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: '导入日历清单',
          subtitle: '从 `*.json` 数据库文件恢复单元格与任务',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('所有冲突都替换为导入内容'),
                value: _replaceConflicts,
                onChanged: (bool? value) => setState(
                  () => _replaceConflicts = value ?? true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => controller.importFrom(
                            replaceConflicts: _replaceConflicts,
                          ),
                  icon: const Icon(LucideIcons.upload, size: 16),
                  label: const Text('选择文件并导入'),
                ),
              ),
            ],
          ),
        ),
        if (state.message != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              state.message!,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: context.appColors.brand,
              ),
            ),
          ),
      ],
    );
  }
}
