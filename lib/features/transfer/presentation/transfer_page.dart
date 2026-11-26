/// 导入导出页：数据库 / 文本 / CSV，范围与冲突策略。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        AppSectionCard(
          title: l10n.transferExportTitle,
          subtitle: l10n.transferExportSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  for (final format in ExportFormat.values)
                    ChoiceChip(
                      label: Text(format.localizedLabel(l10n)),
                      selected: _format == format,
                      onSelected: (_) => setState(() => _format = format),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(l10n.transferRangeAllTime),
                    selected: _range == ExportRange.allTime,
                    onSelected: (_) =>
                        setState(() => _range = ExportRange.allTime),
                  ),
                  ChoiceChip(
                    label: Text(l10n.transferRangeSixMonths),
                    selected: _range == ExportRange.sixMonths,
                    onSelected: (_) =>
                        setState(() => _range = ExportRange.sixMonths),
                  ),
                  ChoiceChip(
                    label: Text(l10n.transferRangeCustom),
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
                      : () =>
                            controller.exportTo(format: _format, range: _range),
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: Text(l10n.transferExportToFile),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: l10n.transferImportTitle,
          subtitle: l10n.transferImportSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.transferReplaceConflicts),
                value: _replaceConflicts,
                onChanged: (bool? value) =>
                    setState(() => _replaceConflicts = value ?? true),
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
                  label: Text(l10n.transferChooseAndImport),
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
