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

final class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.id, this.initial});

  final String id;
  final ShowSummary? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = projectDetailProvider(id);
    final state = ref.watch(provider);
    final show = state.detail ?? initial;
    return Scaffold(
      backgroundColor: context.appColors.bgPage,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/projects'),
        ),
        title: Text(context.l10n.catalogDetailTitle),
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
      body: state.loading && show == null
          ? const Center(child: CircularProgressIndicator())
          : show == null
          ? EmptyState(
              icon: LucideIcons.drama,
              title: state.error ?? context.l10n.catalogDetailEmpty,
              action: FilledButton(
                onPressed: () => ref.read(provider.notifier).load(),
                child: Text(context.l10n.commonRetry),
              ),
            )
          : ListView(
              key: ValueKey<String>('project-detail-$id'),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      state.error!,
                      style: TextStyle(color: context.appColors.error),
                    ),
                  ),
                _Header(show: show),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.appColors.brandSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(LucideIcons.info),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          context.l10n.catalogReadOnlyNotice,
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (show.isProject) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _FundingSection(show: show),
                ],
                if (show.venueLabel.isNotEmpty ||
                    show.sessions.isNotEmpty ||
                    show.lineup.isNotEmpty)
                  _InfoSection(show: show),
                if (show.tiers.isNotEmpty) _TierSection(show: show),
                if (show.updates.isNotEmpty) _UpdatesSection(show: show),
                if (show.riskNote.isNotEmpty ||
                    show.deliveryPlan.isNotEmpty ||
                    show.fundUsage.isNotEmpty ||
                    show.refundRule.isNotEmpty)
                  _RiskSection(show: show),
                if (show.reviews.isNotEmpty) _ReviewSection(show: show),
                if (show.faqs.isNotEmpty) _FaqSection(show: show),
                if (show.artist.isNotEmpty ||
                    show.creatorBio.isNotEmpty ||
                    show.creatorProjectNum > 0)
                  _CreatorSection(show: show),
                if (show.intro.isNotEmpty)
                  AppSectionCard(
                    title: context.l10n.catalogStoryTitle,
                    child: Text(
                      show.intro,
                      style: TextStyle(
                        fontSize: AppTypography.body,
                        height: 1.7,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ),
                if (show.gallery.isNotEmpty) _GallerySection(show: show),
                if (show.purchaseNotice.isNotEmpty)
                  AppSectionCard(
                    title: context.l10n.catalogNoticeTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final notice in show.purchaseNotice)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: Text(
                              '• $notice',
                              style: TextStyle(
                                fontSize: AppTypography.body,
                                color: context.appColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final image = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ShowImage(
          url: show.cover,
          width: constraints.maxWidth < 640 ? double.infinity : 236,
          height: constraints.maxWidth < 640 ? 190 : 168,
          iconSize: 48,
        ),
      );
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (show.categoryName.isNotEmpty)
                AppChip(label: show.categoryName, dense: true),
              AppChip(
                label: fundingStatusLabel(context, show),
                color: context.appColors.brand,
                dense: true,
              ),
              for (final tag in show.tags.take(4))
                AppChip(label: tag, dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            show.title,
            style: TextStyle(
              fontSize: AppTypography.title,
              fontWeight: AppTypography.bold,
              color: context.appColors.textPrimary,
            ),
          ),
          if (show.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              show.summary,
              style: TextStyle(
                fontSize: AppTypography.body,
                color: context.appColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            moneyLabel(context, show.priceFrom),
            style: TextStyle(
              fontSize: AppTypography.subtitle,
              fontWeight: AppTypography.bold,
              color: context.appColors.price,
            ),
          ),
          if (show.artist.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.catalogCreator(show.artist),
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: context.appColors.textTertiary,
              ),
            ),
          ],
        ],
      );
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.appColors.border),
        ),
        child: constraints.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  image,
                  const SizedBox(height: AppSpacing.md),
                  content,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  image,
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: content),
                ],
              ),
      );
    },
  );
}

final class _FundingSection extends StatelessWidget {
  const _FundingSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) {
    final days = show.projectDeadline?.difference(DateTime.now()).inDays ?? 0;
    return AppSectionCard(
      title: context.l10n.catalogProgressTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                context.l10n.catalogAchievement(
                  (show.achievementPermille / 10).round(),
                ),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.brand,
                ),
              ),
              const Spacer(),
              Text(
                days > 0
                    ? context.l10n.catalogDaysLeft(days)
                    : context.l10n.catalogEnded,
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: (show.achievementPermille / 1000).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: context.appColors.bgSubtle,
              color: context.appColors.brand,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Metric(
                label: context.l10n.catalogGoalAmount,
                value: show.goalAmount == null
                    ? '—'
                    : moneyLabel(context, show.goalAmount!),
              ),
              _Metric(
                label: context.l10n.catalogRaisedAmount,
                value: show.raisedAmount == null
                    ? '—'
                    : moneyLabel(context, show.raisedAmount!),
              ),
              _Metric(
                label: context.l10n.catalogSupporters(show.supporterCount),
                value: '${show.supporterCount}',
              ),
              _Metric(
                label: context.l10n.catalogDeadline,
                value: formatProjectDate(context, show.projectDeadline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        value,
        style: TextStyle(
          fontSize: AppTypography.subtitle,
          fontWeight: AppTypography.bold,
          color: context.appColors.textPrimary,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.caption,
          color: context.appColors.textTertiary,
        ),
      ),
    ],
  );
}

final class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogInfoTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (show.venueLabel.isNotEmpty)
          _IconLine(
            icon: LucideIcons.mapPin,
            title: show.venueLabel,
            subtitle: show.venueAddress,
          ),
        if (show.duration.isNotEmpty)
          _IconLine(
            icon: LucideIcons.clock3,
            title: context.l10n.catalogDuration(show.duration),
          ),
        for (final session in show.sessions)
          _IconLine(
            icon: LucideIcons.calendarDays,
            title: formatProjectDate(context, session.startsAt),
            subtitle: session.tierSummary,
            trailing: session.soldOut ? context.l10n.catalogSoldOut : null,
          ),
        if (show.lineup.isNotEmpty)
          Text(
            show.lineup.join(' · '),
            style: TextStyle(color: context.appColors.textSecondary),
          ),
      ],
    ),
  );
}

final class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: context.appColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTypography.body,
                  fontWeight: AppTypography.medium,
                  color: context.appColors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: context.appColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: context.appColors.textDisabled,
            ),
          ),
      ],
    ),
  );
}

final class _TierSection extends StatelessWidget {
  const _TierSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogRewardsTitle,
    child: Column(
      children: <Widget>[
        for (final tier in show.tiers)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.appColors.bgSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        tier.name,
                        style: TextStyle(
                          fontSize: AppTypography.subtitle,
                          fontWeight: AppTypography.bold,
                          color: context.appColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      tier.soldOut
                          ? context.l10n.catalogSoldOut
                          : moneyLabel(context, tier.price),
                      style: TextStyle(
                        fontWeight: AppTypography.bold,
                        color: tier.soldOut
                            ? context.appColors.textDisabled
                            : context.appColors.price,
                      ),
                    ),
                  ],
                ),
                if (tier.items.isNotEmpty)
                  Text(
                    tier.items.join(' · '),
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                if (tier.note != null)
                  Text(
                    tier.note!,
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: context.appColors.textTertiary,
                    ),
                  ),
                if (tier.estimatedDeliveryTime.isNotEmpty)
                  Text(
                    context.l10n.catalogDelivery(tier.estimatedDeliveryTime),
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: context.appColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

final class _UpdatesSection extends StatelessWidget {
  const _UpdatesSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogUpdatesTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final update in show.updates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  update.title,
                  style: TextStyle(
                    fontWeight: AppTypography.bold,
                    color: context.appColors.textPrimary,
                  ),
                ),
                if (update.publishTime != null)
                  Text(
                    formatProjectDate(context, update.publishTime),
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: context.appColors.textTertiary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  update.content,
                  style: TextStyle(
                    fontSize: AppTypography.body,
                    height: 1.6,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

final class _RiskSection extends StatelessWidget {
  const _RiskSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogRiskTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final entry in <(String, String)>[
          (context.l10n.catalogRiskNote, show.riskNote),
          (context.l10n.catalogDeliveryPlan, show.deliveryPlan),
          (context.l10n.catalogFundUsage, show.fundUsage),
          (context.l10n.catalogRefundRule, show.refundRule),
        ])
          if (entry.$2.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.$1,
                    style: TextStyle(
                      fontWeight: AppTypography.bold,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.$2,
                    style: TextStyle(
                      fontSize: AppTypography.body,
                      height: 1.6,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

final class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogReviewsTitle(show.reviews.length),
    child: Column(
      children: <Widget>[
        for (final review in show.reviews.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        review.displayName.isEmpty
                            ? context.l10n.catalogAnonymous
                            : review.displayName,
                        style: TextStyle(
                          fontWeight: AppTypography.medium,
                          color: context.appColors.textPrimary,
                        ),
                      ),
                    ),
                    for (var star = 1; star <= 5; star++)
                      Icon(
                        star <= review.rating
                            ? LucideIcons.star
                            : LucideIcons.starOff,
                        size: 14,
                        color: context.appColors.price,
                      ),
                  ],
                ),
                if (review.content.isNotEmpty)
                  Text(
                    review.content,
                    style: TextStyle(
                      fontSize: AppTypography.body,
                      color: context.appColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

final class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogFaqTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final faq in show.faqs)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              faq.question,
              style: TextStyle(
                fontSize: AppTypography.body,
                fontWeight: AppTypography.medium,
                color: context.appColors.textPrimary,
              ),
            ),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq.answer,
                  style: TextStyle(
                    fontSize: AppTypography.body,
                    height: 1.6,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

final class _CreatorSection extends StatelessWidget {
  const _CreatorSection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogCreatorTitle,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipOval(
          child: ShowImage(
            url: show.creatorAvatar,
            width: 56,
            height: 56,
            iconSize: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                show.artist,
                style: TextStyle(
                  fontSize: AppTypography.subtitle,
                  fontWeight: AppTypography.bold,
                  color: context.appColors.textPrimary,
                ),
              ),
              if (show.creatorVerified)
                Text(
                  context.l10n.catalogCreatorVerified,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: context.appColors.success,
                  ),
                ),
              if (show.creatorProjectNum > 0)
                Text(
                  context.l10n.catalogCreatorStats(
                    show.creatorProjectNum,
                    show.creatorSuccessNum,
                    (show.creatorFulfillmentPermille / 10).round(),
                  ),
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: context.appColors.textTertiary,
                  ),
                ),
              if (show.creatorBio.isNotEmpty)
                Text(
                  show.creatorBio,
                  style: TextStyle(
                    fontSize: AppTypography.body,
                    color: context.appColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.show});

  final ShowSummary show;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: context.l10n.catalogGalleryTitle,
    child: SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: show.gallery.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) => ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ShowImage(url: show.gallery[index], width: 220, height: 160),
        ),
      ),
    ),
  );
}
