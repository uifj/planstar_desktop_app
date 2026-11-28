library;

import 'package:core/domain.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../domain/show_summary.dart';

String moneyLabel(BuildContext context, Money money) =>
    '${context.l10n.catalogCredits} ${money.format(withSymbol: false)}';

String formatProjectDate(BuildContext context, DateTime? value) => value == null
    ? '—'
    : DateFormat.yMMMd(
        Localizations.localeOf(context).toString(),
      ).format(value);

String fundingStatusLabel(BuildContext context, ShowSummary show) =>
    switch (show.fundingStatusValue) {
      'preheating' => context.l10n.catalogStatusPreheating,
      'achieved' => context.l10n.catalogStatusAchieved,
      'delivered' => context.l10n.catalogStatusDelivered,
      'failed' => context.l10n.catalogStatusFailed,
      _ => context.l10n.catalogStatusOngoing,
    };
