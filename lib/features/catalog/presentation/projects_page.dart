library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/catalog_controller.dart';
import '../domain/show_summary.dart';
import 'project_formatters.dart';
import 'show_image.dart';

final class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

final class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  int? _categoryId;
  ProjectSort _sort = ProjectSort.recommended;

  ProjectListQuery get _query =>
      ProjectListQuery(categoryId: _categoryId, sort: _sort);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final categories = ref.watch(projectCategoriesProvider);
    final state = ref.watch(projectListProvider(_query));
    final controller = ref.read(projectListProvider(_query).notifier);
    return Scaffold(
      backgroundColor: colors.bgPage,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.catalogTitle,
                        style: TextStyle(
                          fontSize: AppTypography.title,
                          fontWeight: AppTypography.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.catalogSubtitle,
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ProjectSort>(
                    value: _sort,
                    onChanged: state.loading
                        ? null
                        : (ProjectSort? value) {
                            if (value != null) {
                              setState(() => _sort = value);
                            }
                          },
                    items: <DropdownMenuItem<ProjectSort>>[
                      for (final sort in ProjectSort.values)
                        DropdownMenuItem<ProjectSort>(
                          value: sort,
                          child: Text(_sortLabel(l10n, sort)),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.ideaRefresh,
                  onPressed: state.loading ? null : controller.loadInitial,
                  icon: const Icon(LucideIcons.refreshCw),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: <Widget>[
                ChoiceChip(
                  label: Text(l10n.catalogAllCategories),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                for (final category in categories.items)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: _categoryId == category.id,
                      onSelected: (_) =>
                          setState(() => _categoryId = category.id),
                    ),
                  ),
              ],
            ),
          ),
          if (categories.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                categories.error!,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.error,
                ),
              ),
            ),
          if (state.error != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Text(
                state.error!,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: colors.error,
                ),
              ),
            ),
          Expanded(
            child: state.loading && state.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                ? EmptyState(
                    icon: LucideIcons.drama,
                    title: state.error ?? l10n.catalogEmptyTitle,
                    hint: state.error == null ? l10n.catalogEmptyHint : null,
                    action: state.error == null
                        ? null
                        : FilledButton(
                            onPressed: controller.loadInitial,
                            child: Text(l10n.commonRetry),
                          ),
                  )
                : RefreshIndicator(
                    onRefresh: controller.loadInitial,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      itemCount: state.items.length + 1,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == state.items.length) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: state.hasMore
                                ? OutlinedButton.icon(
                                    key: const ValueKey<String>(
                                      'catalog-load-more',
                                    ),
                                    onPressed: state.loadingMore
                                        ? null
                                        : controller.loadMore,
                                    icon: state.loadingMore
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(LucideIcons.chevronDown),
                                    label: Text(l10n.catalogLoadMore),
                                  )
                                : Text(
                                    l10n.catalogEnd,
                                    style: TextStyle(
                                      fontSize: AppTypography.caption,
                                      color: colors.textTertiary,
                                    ),
                                  ),
                          );
                        }
                        final show = state.items[index];
                        return _ProjectCard(
                          show: show,
                          onTap: () => context.push(
                            '/projects/${Uri.encodeComponent(show.id)}',
                            extra: show,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _sortLabel(AppLocalizations l10n, ProjectSort sort) => switch (sort) {
  ProjectSort.recommended => l10n.catalogSortRecommended,
  ProjectSort.newest => l10n.catalogSortNewest,
  ProjectSort.ending => l10n.catalogSortEnding,
  ProjectSort.achievement => l10n.catalogSortAchievement,
};

final class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.show, required this.onTap});

  final ShowSummary show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    return InkWell(
      key: ValueKey<String>('project-card-${show.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: ShowImage(
                url: show.cover,
                width: 152,
                height: 112,
                iconSize: 30,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    show.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.subtitle,
                      fontWeight: AppTypography.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (show.summary.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      show.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.body,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      if (show.categoryName.isNotEmpty)
                        AppChip(label: show.categoryName, dense: true),
                      if (show.isProject)
                        AppChip(
                          label: l10n.catalogAchievement(
                            (show.achievementPermille / 10).round(),
                          ),
                          color: colors.success,
                          dense: true,
                        ),
                      Text(
                        moneyLabel(context, show.priceFrom),
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          fontWeight: AppTypography.bold,
                          color: colors.price,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    <String>[
                      if (show.venueLabel.isNotEmpty) show.venueLabel,
                      formatProjectDate(context, show.firstSessionAt),
                      if (show.supporterCount > 0)
                        l10n.catalogSupporters(show.supporterCount),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(LucideIcons.chevronRight, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
