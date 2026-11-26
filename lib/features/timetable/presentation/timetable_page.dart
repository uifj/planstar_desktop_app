/// 课程表页：学期设置、节次时间、单双周、时间冲突检测。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/timetable_controller.dart';
import '../domain/timetable.dart';

final class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timetableControllerProvider);
    final controller = ref.read(timetableControllerProvider.notifier);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Text(
                l10n.timetableTitle,
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showSettings(context, ref),
                icon: const Icon(LucideIcons.settings, size: 16),
                label: Text(l10n.timetableSettings),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () async {
                  await controller.create(
                    name: l10n.timetableNewName,
                    startDate: DateKey.today(ref.read(clockProvider).now()),
                  );
                },
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(l10n.timetableNewName),
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
              ? EmptyState(
                  icon: LucideIcons.table2,
                  title: l10n.timetableEmptyTitle,
                  hint: l10n.timetableEmptyHint,
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
    final l10n = context.l10n;
    final name = timetable.localizedName(l10n);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AppDialogFrame(
        title: l10n.timetableSettingsTitle(name),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(l10n.timetableStartDate),
              trailing: Text(timetable.startDate.fullDate(l10n)),
            ),
            ListTile(
              title: Text(l10n.timetableSemesterWeeks),
              trailing: Text(l10n.timetableWeeksCount(timetable.weeks)),
            ),
            ListTile(
              title: Text(l10n.timetablePeriodsPerDay),
              trailing: Text(
                l10n.timetablePeriodsPerDayCount(timetable.periodsPerDay),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.timetableHideWeekend),
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
    final l10n = context.l10n;
    final name = timetable.localizedName(l10n);
    final dayCount = timetable.hideWeekend ? 5 : 7;
    return AppSectionCard(
      title: name,
      subtitle: l10n.timetableSummary(
        timetable.startDate.fullDate(l10n),
        timetable.weeks,
      ),
      trailing: IconButton(
        icon: Icon(LucideIcons.trash2, size: 16, color: colors.error),
        tooltip: l10n.timetableRemoveTooltip(name),
        onPressed: () =>
            ref.read(timetableControllerProvider.notifier).remove(timetable.id),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: <DataColumn>[
            DataColumn(label: Text(l10n.timetablePeriod)),
            for (var day = 1; day <= dayCount; day++)
              DataColumn(label: Text(weekdayShort(day, l10n))),
          ],
          rows: <DataRow>[
            for (final period in timetable.periods)
              DataRow(
                cells: <DataCell>[
                  DataCell(Text('${period.index}\n${period.startLabel}')),
                  for (var day = 1; day <= dayCount; day++)
                    DataCell(_lessonCell(context, ref, day, period.index)),
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
        .where((Lesson l) => l.weekday == weekday && l.period == period)
        .toList();
    final l10n = context.l10n;
    final addTooltip = l10n.timetableAddLessonTooltip(
      weekdayLong(weekday, l10n),
      period,
    );
    if (matches.isEmpty) {
      return InkWell(
        onTap: () => _addLesson(context, ref, weekday, period),
        child: SizedBox(
          width: 88,
          height: 36,
          child: Tooltip(
            message: addTooltip,
            child: Icon(
              LucideIcons.plus,
              size: 14,
              color: context.appColors.textDisabled,
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => ref
          .read(timetableControllerProvider.notifier)
          .removeLesson(timetable.id, matches.first.id),
      child: Tooltip(
        message: l10n.timetableRemoveLessonTooltip(matches.first.name),
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
    final l10n = context.l10n;
    var parity = WeekParity.all;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AppDialogFrame(
          title: l10n.timetableAddLessonTitle(
            weekdayLong(weekday, l10n),
            period,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.timetableAdd),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.timetableCourseName,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButton<WeekParity>(
                value: parity,
                icon: const Icon(LucideIcons.chevronDown, size: 16),
                items: WeekParity.values
                    .map(
                      (WeekParity p) => DropdownMenuItem<WeekParity>(
                        value: p,
                        child: Text(p.localizedLabel(l10n)),
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
    await ref
        .read(timetableControllerProvider.notifier)
        .addLesson(
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
