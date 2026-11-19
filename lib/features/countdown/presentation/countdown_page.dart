/// 倒数日页：倒数 / 累计 / 生日 / 纪念日 / 桌面卡片。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../../shared/widgets/common.dart';
import '../application/countdown_controller.dart';
import '../domain/countdown.dart';

final class CountdownPage extends ConsumerWidget {
  const CountdownPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countdownControllerProvider);
    final today = DateKey.today(ref.watch(clockProvider).now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Text(
                '倒数日（${state.items.length}）',
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
                label: const Text('打开桌面卡片'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('新建倒数日'),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.items.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.hourglass,
                  title: '暂无倒数日',
                  hint: '支持倒计时、累计日、生日、纪念日',
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
                    return AppSectionCard(
                      title: item.title,
                      subtitle:
                          '${item.targetDate.cnFull} · ${item.type.label}',
                      trailing: IconButton(
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
                            item.displayText(today),
                            style: TextStyle(
                              fontSize: AppTypography.title,
                              fontWeight: AppTypography.bold,
                              color: item.color.toColor(),
                            ),
                          ),
                          if (item.ageText(today).isNotEmpty)
                            Text(
                              item.ageText(today),
                              style: TextStyle(
                                fontSize: AppTypography.caption,
                                color: context.appColors.textTertiary,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          AppChip(label: item.showType.label, dense: true),
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
    final titleController = TextEditingController();
    var date = DateKey.today(ref.read(clockProvider).now()).addDays(30);
    var type = CountdownType.custom;
    var showType = CountdownShowType.both;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AppDialogFrame(
          title: '新建倒数日',
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('创建'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButton<CountdownType>(
                      value: type,
                      icon: const Icon(LucideIcons.chevronDown, size: 16),
                      isExpanded: true,
                      items: CountdownType.values
                          .map(
                            (CountdownType t) =>
                                DropdownMenuItem<CountdownType>(
                                  value: t,
                                  child: Text(t.label),
                                ),
                          )
                          .toList(),
                      onChanged: (CountdownType? value) =>
                          setState(() => type = value ?? type),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButton<CountdownShowType>(
                      value: showType,
                      icon: const Icon(LucideIcons.chevronDown, size: 16),
                      isExpanded: true,
                      items: CountdownShowType.values
                          .map(
                            (CountdownShowType t) =>
                                DropdownMenuItem<CountdownShowType>(
                                  value: t,
                                  child: Text(t.label),
                                ),
                          )
                          .toList(),
                      onChanged: (CountdownShowType? value) =>
                          setState(() => showType = value ?? showType),
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
                label: Text(date.cnFull),
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
