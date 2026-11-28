library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/auth_state.dart';
import '../application/project_idea_controller.dart';
import '../domain/project_idea.dart';
import 'idea_image.dart';
import 'idea_vote_dialogs.dart';

final class ProjectIdeaDetailPage extends ConsumerWidget {
  const ProjectIdeaDetailPage({super.key, required this.ideaId});

  final int ideaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = projectIdeaDetailProvider(ideaId);
    final state = ref.watch(provider);
    ref.listen<AuthState>(authControllerProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (next.isLoggedIn) {
        _resumePendingVote(context, ref);
      }
    });
    ref.listen<ProjectIdeaDetailState>(provider, (
      ProjectIdeaDetailState? previous,
      ProjectIdeaDetailState next,
    ) {
      if (next.detail != null && ref.read(authControllerProvider).isLoggedIn) {
        _resumePendingVote(context, ref);
      }
    });

    final detail = state.detail;
    final pending = ref.read(projectIdeaPendingVoteProvider);
    if (detail != null &&
        ref.read(authControllerProvider).isLoggedIn &&
        pending?.ideaId == ideaId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _resumePendingVote(context, ref);
      });
    }
    return Scaffold(
      backgroundColor: context.appColors.bgPage,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/project-ideas'),
        ),
        title: Text(context.l10n.ideaDetailTitle),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.ideaRefresh,
            onPressed: state.loading
                ? null
                : () => ref.read(provider.notifier).load(),
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: state.loading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? EmptyState(
              icon: LucideIcons.lightbulb,
              title: state.error ?? context.l10n.ideaEmptyTitle,
              action: FilledButton(
                onPressed: () => ref.read(provider.notifier).load(),
                child: Text(context.l10n.commonRetry),
              ),
            )
          : _DetailBody(
              ideaId: ideaId,
              detail: detail,
              submitting: state.submitting,
              onSupport: () =>
                  _startVote(context, ref, ProjectIdeaVoteIntent.support),
              onOppose: () =>
                  _startVote(context, ref, ProjectIdeaVoteIntent.oppose),
            ),
    );
  }

  void _resumePendingVote(BuildContext context, WidgetRef ref) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
    final pending = ref.read(projectIdeaPendingVoteProvider);
    if (pending == null ||
        pending.ideaId != ideaId ||
        ref.read(projectIdeaDetailProvider(ideaId)).detail == null) {
      return;
    }
    Future<void>.microtask(() {
      if (!context.mounted ||
          ModalRoute.of(context)?.isCurrent == false ||
          !ref.read(authControllerProvider).isLoggedIn ||
          ref.read(projectIdeaPendingVoteProvider) != pending) {
        return;
      }
      ref.read(projectIdeaPendingVoteProvider.notifier).take();
      _openVote(context, ref, pending.intent);
    });
  }

  Future<void> _startVote(
    BuildContext context,
    WidgetRef ref,
    ProjectIdeaVoteIntent intent,
  ) async {
    final auth = ref.read(authControllerProvider);
    if (auth.isRestoring) return;
    if (!auth.isLoggedIn) {
      final pending = ProjectIdeaPendingVote(ideaId: ideaId, intent: intent);
      final pendingController = ref.read(
        projectIdeaPendingVoteProvider.notifier,
      );
      pendingController.set(pending);
      final destination = '/project-ideas/$ideaId';
      await context.push<void>(
        Uri(
          path: '/login',
          queryParameters: <String, String>{'from': destination},
        ).toString(),
      );
      if (!context.mounted) {
        pendingController.clear(pending);
        return;
      }
      if (!ref.read(authControllerProvider).isLoggedIn) {
        pendingController.clear(pending);
        return;
      }
      _resumePendingVote(context, ref);
      return;
    }
    await _openVote(context, ref, intent);
  }

  Future<void> _openVote(
    BuildContext context,
    WidgetRef ref,
    ProjectIdeaVoteIntent intent,
  ) async {
    final controller = ref.read(projectIdeaDetailProvider(ideaId).notifier);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final dialog = intent == ProjectIdeaVoteIntent.support
        ? showSupportVoteDialog(context, controller)
        : showOpposeVoteDialog(context, controller);
    final result = await dialog;
    if (result == null || !context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyVoted
                ? l10n.ideaVoteAlready
                : intent == ProjectIdeaVoteIntent.support
                ? l10n.ideaSupportSuccess
                : l10n.ideaOpposeSuccess,
          ),
        ),
      );
  }
}

final class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.ideaId,
    required this.detail,
    required this.submitting,
    required this.onSupport,
    required this.onOppose,
  });

  final int ideaId;
  final ProjectIdeaDetail detail;
  final bool submitting;
  final VoidCallback onSupport;
  final VoidCallback onOppose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final vote = detail.myVote;
    final percent = (detail.supportRate.clamp(0, 1).toDouble() * 100).round();
    final reasons = detail.reasonCounts.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );
    return ListView(
      key: ValueKey<String>('idea-detail-$ideaId'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IdeaImage(
            url: detail.cover,
            width: double.infinity,
            height: 240,
            iconSize: 48,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (detail.categoryName.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: AppChip(label: detail.categoryName),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          detail.title.isEmpty ? l10n.ideaUntitled : detail.title,
          style: TextStyle(
            fontSize: AppTypography.title,
            fontWeight: AppTypography.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          detail.summary,
          style: TextStyle(
            fontSize: AppTypography.body,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            AppChip(
              label: l10n.ideaSupportRate(percent),
              color: colors.success,
            ),
            Text(
              l10n.ideaSupportCount(detail.supportCount),
              style: TextStyle(color: colors.success),
            ),
            Text(
              l10n.ideaOpposeCount(detail.opposeCount),
              style: TextStyle(color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.ideaCreator(
            detail.creatorName.isEmpty
                ? l10n.ideaUnknownCreator
                : detail.creatorName,
          ),
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: colors.textTertiary,
          ),
        ),
        Text(
          l10n.ideaCreatedAt(
            DateFormat.yMMMd(l10n.localeName).add_Hm().format(detail.createdAt),
          ),
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (vote != null)
          Container(
            key: const ValueKey<String>('idea-my-vote'),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: <Widget>[
                Icon(LucideIcons.circleCheck, color: colors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    vote.voteType == IdeaVote.support
                        ? l10n.ideaVoteMySupport(vote.coinTier ?? 0)
                        : l10n.ideaVoteMyOppose,
                    style: TextStyle(color: colors.brand),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey<String>('idea-support'),
                  onPressed: submitting ? null : onSupport,
                  icon: const Icon(LucideIcons.thumbsUp, size: 16),
                  label: Text(l10n.ideaSupport),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('idea-oppose'),
                  onPressed: submitting ? null : onOppose,
                  icon: const Icon(LucideIcons.thumbsDown, size: 16),
                  label: Text(l10n.ideaOpposeSubmit),
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: l10n.ideaTierDistributionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TierRow(
                label: l10n.ideaTierCount(5, detail.tierDistribution.five),
                count: detail.tierDistribution.five,
                total: detail.tierDistribution.total,
              ),
              _TierRow(
                label: l10n.ideaTierCount(10, detail.tierDistribution.ten),
                count: detail.tierDistribution.ten,
                total: detail.tierDistribution.total,
              ),
              _TierRow(
                label: l10n.ideaTierCount(20, detail.tierDistribution.twenty),
                count: detail.tierDistribution.twenty,
                total: detail.tierDistribution.total,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: l10n.ideaDetailTitle,
          child: Text(
            detail.description.isEmpty
                ? l10n.ideaNoDescription
                : detail.description,
            style: TextStyle(color: colors.textSecondary, height: 1.6),
          ),
        ),
        if (detail.gallery.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: l10n.ideaGallery,
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: detail.gallery.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: IdeaImage(
                    url: detail.gallery[index],
                    width: 240,
                    height: 180,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: l10n.ideaReasonCountsTitle,
          child: reasons.isEmpty
              ? Text(
                  l10n.ideaNoReasonStats,
                  style: TextStyle(color: colors.textTertiary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final reason in reasons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _reasonLabel(reason.key, l10n),
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ),
                            Text('${reason.value}'),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

final class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: TextStyle(color: context.appColors.textSecondary)),
        const SizedBox(height: AppSpacing.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : count / total,
            minHeight: 6,
            color: context.appColors.brand,
            backgroundColor: context.appColors.bgSubtle,
          ),
        ),
      ],
    ),
  );
}

String _reasonLabel(String code, AppLocalizations l10n) {
  for (final reason in IdeaOpposeReason.values) {
    if (reason.code == code) return reason.labelOf(l10n);
  }
  return code;
}
