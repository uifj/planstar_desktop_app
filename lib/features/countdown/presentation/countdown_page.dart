/// 倒数日页：倒数 / 累计 / 生日 / 纪念日 / 桌面卡片。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/countdown_controller.dart';
import '../domain/countdown.dart';

final class CountdownPage extends ConsumerWidget {
  const CountdownPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countdownControllerProvider);
    final l10n = context.l10n;
    final today = DateKey.today(ref.watch(clockProvider).now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Text(
                l10n.countdownTitle(state.items.length),
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(countdownControllerProvider.notifier)
                    .openDesktopCard(),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: Text(l10n.countdownOpenDesktopCard),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(l10n.countdownCreate),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.items.isEmpty
              ? EmptyState(
                  icon: LucideIcons.hourglass,
                  title: l10n.countdownEmptyTitle,
                  hint: l10n.countdownEmptyHint,
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 150,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: state.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = state.items[index];
                    final ageText = item.localizedAgeText(l10n, today);
                    return AppSectionCard(
                      title: item.title,
                      subtitle:
                          '${item.targetDate.fullDate(l10n)} · ${item.type.localizedLabel(l10n)}',
                      trailing: IconButton(
                        tooltip: l10n.countdownDeleteTooltip(item.title),
                        icon: Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: context.appColors.error,
                        ),
                        onPressed: () => ref
                            .read(countdownControllerProvider.notifier)
                            .remove(item.id),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.localizedDisplayText(l10n, today),
                            style: TextStyle(
                              fontSize: AppTypography.title,
                              fontWeight: AppTypography.bold,
                              color: item.color.toColor(),
                            ),
                          ),
                          if (ageText.isNotEmpty)
                            Text(
                              ageText,
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: context.appColors.textTertiary,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          AppChip(
                            label: item.showType.localizedLabel(l10n),
                            dense: true,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final titleController = TextEditingController();
    var date = DateKey.today(ref.read(clockProvider).now()).addDays(30);
    var type = CountdownType.custom;
    var showType = CountdownShowType.both;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AppDialogFrame(
          title: l10n.countdownCreate,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.countdownCreated),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: l10n.countdownNameField),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.countdownTypeField,
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CountdownType>(
                          value: type,
                          icon: const Icon(LucideIcons.chevronDown, size: 16),
                          isExpanded: true,
                          items: CountdownType.values
                              .map(
                                (CountdownType t) =>
                                    DropdownMenuItem<CountdownType>(
                                      value: t,
                                      child: Text(t.localizedLabel(l10n)),
                                    ),
                              )
                              .toList(),
                          onChanged: (CountdownType? value) =>
                              setState(() => type = value ?? type),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.countdownShowTypeField,
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CountdownShowType>(
                          value: showType,
                          icon: const Icon(LucideIcons.chevronDown, size: 16),
                          isExpanded: true,
                          items: CountdownShowType.values
                              .map(
                                (CountdownShowType t) =>
                                    DropdownMenuItem<CountdownShowType>(
                                      value: t,
                                      child: Text(t.localizedLabel(l10n)),
                                    ),
                              )
                              .toList(),
                          onChanged: (CountdownShowType? value) =>
                              setState(() => showType = value ?? showType),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date.date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => date = DateKey(picked));
                },
                icon: const Icon(LucideIcons.calendarClock, size: 16),
                label: Text(l10n.countdownTargetDateValue(date.fullDate(l10n))),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || titleController.text.trim().isEmpty) return;
    await ref
        .read(countdownControllerProvider.notifier)
        .create(
          title: titleController.text.trim(),
          targetDate: date,
          type: type,
          showType: showType,
          birthYear: type == CountdownType.birthday ? date.year - 1 : null,
        );
    titleController.dispose();
  }
}
