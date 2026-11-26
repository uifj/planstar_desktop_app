import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'domain_labels.dart';
export 'failure_labels.dart';
export 'generated/app_localizations.dart';

const supportedLocales = <Locale>[Locale('zh'), Locale('en')];

Locale localeForLanguage(String? language) => switch (language) {
  'en' || 'en_US' || 'en_GB' => const Locale('en'),
  _ => const Locale('zh'),
};

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

final class AppLocalizationScope extends ValueNotifier<Locale> {
  AppLocalizationScope([super.locale = const Locale('zh')]);

  AppLocalizations get localizations => lookupAppLocalizations(value);

  void setLanguage(String? language) {
    value = localeForLanguage(language);
  }
}
