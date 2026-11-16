/// 搜索页：全部 / 一月 / 三月 / 一年 / 自定义范围 + 结果计数。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../../shared/widgets/common.dart';
import '../application/search_controller.dart';

final class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final queryController = TextEditingController(text: state.keyword);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: queryController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '搜日历清单',
              hintText: '内容、任务、便签、倒数日、订阅、课程',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  queryController.clear();
                  controller.run('');
                },
              ),
            ),
            onChanged: (String value) => controller.run(value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.xs,
            children: <Widget>[
              for (final range in SearchRange.values)
                ChoiceChip(
                  label: Text(range.label),
                  selected: state.range == range,
                  onSelected: (_) => controller.setRange(range),
                ),
              if (state.range == SearchRange.custom)
                OutlinedButton(
                  onPressed: () async {
                    final today =
                        DateKey.today(ref.read(clockProvider).now());
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      initialDateRange: DateTimeRange(
                        start: (state.customStart ?? today.addDays(-30)).date,
                        end: (state.customEnd ?? today).date,
                      ),
                    );
                    if (picked == null) return;
                    controller.setCustomRange(
                      DateKey(picked.start),
                      DateKey(picked.end),
                    );
                  },
                  child: Text(
                    state.customStart == null
                        ? '选择自定义范围'
                        : '${state.customStart!.key} ~ ${state.customEnd?.key}',
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            '共找到 ${state.hits.length} 条结果',
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: context.appColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: state.hits.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_outlined,
                  title: '没有匹配内容',
                  hint: '输入关键词后即时检索全部模块',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: state.hits.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xxs),
                  itemBuilder: (BuildContext context, int index) {
                    final hit = state.hits[index];
                    return ListTile(
                      tileColor: context.appColors.bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      leading: AppChip(label: hit.kind, dense: true),
                      title: Text(hit.title),
                      subtitle: Text(
                        hit.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: hit.date == null
                          ? null
                          : Text(hit.date!.cnDate),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
