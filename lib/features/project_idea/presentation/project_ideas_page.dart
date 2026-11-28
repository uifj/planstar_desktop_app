library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/project_idea_controller.dart';
import '../domain/project_idea.dart';
import 'idea_image.dart';

final class ProjectIdeasPage extends ConsumerWidget {
  const ProjectIdeasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final state = ref.watch(projectIdeaFeedProvider);
    final controller = ref.read(projectIdeaFeedProvider.notifier);
    return Column(
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
                      l10n.ideaTitle,
                      style: TextStyle(
                        fontSize: AppTypography.title,
                        fontWeight: AppTypography.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.ideaSubtitle,
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton.filledTonal(
                tooltip: l10n.ideaRefresh,
                onPressed: state.loading ? null : controller.loadInitial,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          ),
        ),
        if (state.error != null && state.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(state.error!, style: TextStyle(color: colors.error)),
          ),
        Expanded(
          child: state.loading && state.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.items.isEmpty
              ? EmptyState(
                  icon: LucideIcons.lightbulb,
                  title: state.error ?? l10n.ideaEmptyTitle,
                  hint: state.error == null ? l10n.ideaEmptyHint : null,
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
                      0,
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
                                  label: Text(l10n.ideaLoadMore),
                                )
                              : const SizedBox.shrink(),
                        );
                      }
                      final idea = state.items[index];
                      return _IdeaCard(
                        idea: idea,
                        onTap: () =>
                            context.push('/project-ideas/${idea.ideaId}'),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

final class _IdeaCard extends StatelessWidget {
  const _IdeaCard({required this.idea, required this.onTap});

  final ProjectIdea idea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    return InkWell(
      key: ValueKey<String>('idea-card-${idea.ideaId}'),
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
              child: IdeaImage(
                url: idea.cover,
                width: 112,
                height: 92,
                iconSize: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    idea.title.isEmpty ? l10n.ideaUntitled : idea.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.subtitle,
                      fontWeight: AppTypography.medium,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    idea.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.body,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      if (idea.categoryName.isNotEmpty)
                        AppChip(label: idea.categoryName, dense: true),
                      Text(
                        l10n.ideaSupportCount(idea.supportCount),
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          color: colors.success,
                        ),
                      ),
                      Text(
                        l10n.ideaOpposeCount(idea.opposeCount),
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
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
