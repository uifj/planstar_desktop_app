/// 搜索页：全部 / 一月 / 三月 / 一年 / 自定义范围 + 结果计数。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/search_controller.dart';

final class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
              labelText: l10n.searchFieldLabel,
              hintText: l10n.searchFieldHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: IconButton(
                tooltip: l10n.searchClearQueryTooltip,
                icon: const Icon(LucideIcons.x),
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
                  label: Text(range.localizedLabel(l10n)),
                  selected: state.range == range,
                  onSelected: (_) => controller.setRange(range),
                ),
              if (state.range == SearchRange.custom)
                OutlinedButton(
                  onPressed: () async {
                    final today = DateKey.today(ref.read(clockProvider).now());
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
                        ? l10n.searchChooseCustomRange
                        : l10n.searchCustomRangeLabel(
                            state.customStart!.fullDate(l10n),
                            (state.customEnd ?? state.customStart!).fullDate(
                              l10n,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            l10n.searchResultCount(state.hits.length),
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: context.appColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: state.hits.isEmpty
              ? EmptyState(
                  icon: LucideIcons.searchX,
                  title: l10n.searchEmptyTitle,
                  hint: l10n.searchEmptyHint,
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
                          : Text(hit.date!.shortDate(l10n)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
