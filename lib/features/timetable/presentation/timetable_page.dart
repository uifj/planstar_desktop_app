/// 课程表页：学期设置、节次时间、单双周、时间冲突检测。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../../shared/widgets/common.dart';
import '../application/timetable_controller.dart';
import '../domain/timetable.dart';

final class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timetableControllerProvider);
    final controller = ref.read(timetableControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Text(
                '课程表',
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showSettings(context, ref),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('课程表设置'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () async {
                  await controller.create(
                    name: '新建课程表',
                    startDate:
                        DateKey.today(ref.read(clockProvider).now()),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('新建课程表'),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              state.error!,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: context.appColors.error,
              ),
            ),
          ),
        Expanded(
          child: state.items.isEmpty
              ? const EmptyState(
                  icon: Icons.table_chart_outlined,
                  title: '暂无课程表',
                  hint: '支持单双周、节次时间与课程冲突检测',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: <Widget>[
                    for (final timetable in state.items)
                      _TimetableCard(timetable: timetable),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showSettings(BuildContext context, WidgetRef ref) async {
    final state = ref.read(timetableControllerProvider);
    if (state.items.isEmpty) return;
    final timetable = state.items.first;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AppDialogFrame(
        title: '课程表设置：${timetable.name}',
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: const Text('开学日期'),
              trailing: Text(timetable.startDate.cnFull),
            ),
            ListTile(
              title: const Text('学期周数'),
              trailing: Text('${timetable.weeks} 周'),
            ),
            ListTile(
              title: const Text('每天节次'),
              trailing: Text('${timetable.periodsPerDay} 节'),
            ),
            SwitchListTile(
              title: const Text('隐藏周末'),
              value: timetable.hideWeekend,
              onChanged: (bool v) => ref
                  .read(timetableControllerProvider.notifier)
                  .save(timetable.copyWith(hideWeekend: v)),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TimetableCard extends ConsumerWidget {
  const _TimetableCard({required this.timetable});

  final Timetable timetable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final dayCount = timetable.hideWeekend ? 5 : 7;
    return AppSectionCard(
      title: timetable.name,
      subtitle: '${timetable.startDate.cnFull} 开学 · ${timetable.weeks} 周',
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
        onPressed: () => ref
            .read(timetableControllerProvider.notifier)
            .remove(timetable.id),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: <DataColumn>[
            const DataColumn(label: Text('节次')),
            for (var day = 1; day <= dayCount; day++)
              DataColumn(label: Text('周$day')),
          ],
          rows: <DataRow>[
            for (final period in timetable.periods)
              DataRow(
                cells: <DataCell>[
                  DataCell(
                    Text('${period.index}\n${period.startLabel}'),
                  ),
                  for (var day = 1; day <= dayCount; day++)
                    DataCell(
                      _lessonCell(context, ref, day, period.index),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _lessonCell(
    BuildContext context,
    WidgetRef ref,
    int weekday,
    int period,
  ) {
    final matches = timetable.lessons
        .where(
          (Lesson l) => l.weekday == weekday && l.period == period,
        )
        .toList();
    if (matches.isEmpty) {
      return InkWell(
        onTap: () => _addLesson(context, ref, weekday, period),
        child: SizedBox(
          width: 88,
          height: 36,
          child: Icon(
            Icons.add,
            size: 14,
            color: context.appColors.textDisabled,
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => ref
          .read(timetableControllerProvider.notifier)
          .removeLesson(timetable.id, matches.first.id),
      child: Container(
        width: 88,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: matches.first.color.toColor().withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          matches.first.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTypography.label,
            color: matches.first.color.toColor(),
          ),
        ),
      ),
    );
  }

  Future<void> _addLesson(
    BuildContext context,
    WidgetRef ref,
    int weekday,
    int period,
  ) async {
    final nameController = TextEditingController();
    var parity = WeekParity.all;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            AppDialogFrame(
          title: '添加课程（周$weekday 第$period节）',
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('添加'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '课程名称'),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButton<WeekParity>(
                value: parity,
                items: WeekParity.values
                    .map(
                      (WeekParity p) => DropdownMenuItem<WeekParity>(
                        value: p,
                        child: Text(p.label),
                      ),
                    )
                    .toList(),
                onChanged: (WeekParity? v) =>
                    setState(() => parity = v ?? parity),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || nameController.text.trim().isEmpty) return;
    await ref.read(timetableControllerProvider.notifier).addLesson(
          timetable.id,
          Lesson(
            id: ref.read(idGeneratorProvider).next(),
            name: nameController.text.trim(),
            weekday: weekday,
            period: period,
            parity: parity,
          ),
        );
    nameController.dispose();
  }
}
