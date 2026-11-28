library;

import 'package:core/result.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/common.dart';
import '../application/project_idea_controller.dart';
import '../domain/project_idea.dart';

const List<int> ideaSupportTiers = <int>[5, 10, 20];

enum IdeaOpposeReason {
  notInterested('not_interested'),
  tooManySimilar('too_many_similar'),
  notEnoughInfo('not_enough_info'),
  notExecutable('not_executable'),
  unreasonablePricing('unreasonable_pricing'),
  other('other');

  const IdeaOpposeReason(this.code);
  final String code;

  String labelOf(AppLocalizations l10n) => switch (this) {
    IdeaOpposeReason.notInterested => l10n.ideaOpposeReasonNotInterested,
    IdeaOpposeReason.tooManySimilar => l10n.ideaOpposeReasonTooManySimilar,
    IdeaOpposeReason.notEnoughInfo => l10n.ideaOpposeReasonNotEnoughInfo,
    IdeaOpposeReason.notExecutable => l10n.ideaOpposeReasonNotExecutable,
    IdeaOpposeReason.unreasonablePricing =>
      l10n.ideaOpposeReasonUnreasonablePricing,
    IdeaOpposeReason.other => l10n.ideaOpposeReasonOther,
  };
}

Future<IdeaVoteResult?> showSupportVoteDialog(
  BuildContext context,
  ProjectIdeaDetailController controller,
) => showDialog<IdeaVoteResult>(
  context: context,
  builder: (BuildContext context) => _SupportVoteDialog(controller: controller),
);

Future<IdeaVoteResult?> showOpposeVoteDialog(
  BuildContext context,
  ProjectIdeaDetailController controller,
) => showDialog<IdeaVoteResult>(
  context: context,
  builder: (BuildContext context) => _OpposeVoteDialog(controller: controller),
);

String _voteError(Result<IdeaVoteResult> result, AppLocalizations l10n) {
  final failure = result.failure!;
  return failure.code == 'LOGIN_REQUIRED'
      ? l10n.ideaVoteLoginRequired
      : failureLabel(failure, l10n);
}

final class _SupportVoteDialog extends StatefulWidget {
  const _SupportVoteDialog({required this.controller});

  final ProjectIdeaDetailController controller;

  @override
  State<_SupportVoteDialog> createState() => _SupportVoteDialogState();
}

final class _SupportVoteDialogState extends State<_SupportVoteDialog> {
  final TextEditingController _reason = TextEditingController();
  int _tier = ideaSupportTiers.first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.controller.support(
      tier: _tier,
      reason: _reason.text.trim(),
    );
    if (!mounted) return;
    if (result case Success<IdeaVoteResult>()) {
      Navigator.of(context).pop(result.requireData);
    } else {
      setState(() {
        _submitting = false;
        _error = _voteError(result, context.l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    return AppDialogFrame(
      title: l10n.ideaSupport,
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('support-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? l10n.ideaVoting : l10n.ideaSupportSubmit),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.ideaSupportSubtitle,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (final tier in ideaSupportTiers) ...<Widget>[
                if (tier != ideaSupportTiers.first)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ChoiceChip(
                    key: ValueKey<String>('support-tier-$tier'),
                    label: Text('$tier'),
                    selected: _tier == tier,
                    onSelected: _submitting
                        ? null
                        : (bool selected) => setState(() => _tier = tier),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            key: const ValueKey<String>('support-disclaimer'),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(LucideIcons.info, size: 16, color: colors.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.ideaSupportDisclaimer,
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: colors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('support-reason-field'),
            controller: _reason,
            enabled: !_submitting,
            maxLength: 60,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.ideaSupportReasonHint),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final tag in <String>[
                l10n.ideaSupportReasonCreative,
                l10n.ideaSupportReasonJoin,
                l10n.ideaSupportReasonLaunch,
              ])
                ActionChip(
                  label: Text(tag),
                  onPressed: _submitting
                      ? null
                      : () {
                          final current = _reason.text.trim();
                          if (current.contains(tag)) return;
                          final next = current.isEmpty ? tag : '$current，$tag';
                          _reason.value = TextEditingValue(
                            text: next.length <= 60
                                ? next
                                : next.substring(0, 60),
                            selection: TextSelection.collapsed(
                              offset: next.length <= 60 ? next.length : 60,
                            ),
                          );
                        },
                ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
        ],
      ),
    );
  }
}

final class _OpposeVoteDialog extends StatefulWidget {
  const _OpposeVoteDialog({required this.controller});

  final ProjectIdeaDetailController controller;

  @override
  State<_OpposeVoteDialog> createState() => _OpposeVoteDialogState();
}

final class _OpposeVoteDialogState extends State<_OpposeVoteDialog> {
  final TextEditingController _reason = TextEditingController();
  IdeaOpposeReason? _selected;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason.addListener(_onReasonChanged);
  }

  void _onReasonChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reason
      ..removeListener(_onReasonChanged)
      ..dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selected != null &&
      (_selected != IdeaOpposeReason.other || _reason.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.controller.oppose(
      reasonCode: _selected!.code,
      reasonText: _reason.text.trim(),
    );
    if (!mounted) return;
    if (result case Success<IdeaVoteResult>()) {
      Navigator.of(context).pop(result.requireData);
    } else {
      setState(() {
        _submitting = false;
        _error = _voteError(result, context.l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    return AppDialogFrame(
      title: l10n.ideaOpposeSubmit,
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('oppose-submit'),
          onPressed: _submitting || !_canSubmit ? null : _submit,
          child: Text(_submitting ? l10n.ideaVoting : l10n.ideaOpposeSubmit),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.ideaOpposeSubtitle,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<IdeaOpposeReason>(
            groupValue: _selected,
            onChanged: (IdeaOpposeReason? value) {
              if (!_submitting) {
                setState(() => _selected = value);
              }
            },
            child: Column(
              children: <Widget>[
                for (final reason in IdeaOpposeReason.values)
                  RadioListTile<IdeaOpposeReason>(
                    key: ValueKey<String>('oppose-reason-${reason.code}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(reason.labelOf(l10n)),
                    value: reason,
                  ),
              ],
            ),
          ),
          if (_selected != null) ...<Widget>[
            TextField(
              key: const ValueKey<String>('oppose-reason-field'),
              controller: _reason,
              enabled: !_submitting,
              maxLength: 100,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.ideaOpposeReasonHint,
                errorText:
                    _selected == IdeaOpposeReason.other &&
                        _reason.text.trim().isEmpty
                    ? l10n.ideaOtherReasonRequired
                    : null,
              ),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
        ],
      ),
    );
  }
}
