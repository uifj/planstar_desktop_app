import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/bootstrap/bootstrap.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

void main() {
  test(
    'runtime startup initializes Chinese and English date symbols',
    () async {
      await AppBootstrap.initializeRuntime();

      final date = DateKey(DateTime(2026, 11, 26));
      final zh = date.fullDate(lookupAppLocalizations(const Locale('zh')));
      final en = date.fullDate(lookupAppLocalizations(const Locale('en')));

      expect(zh, contains('2026'));
      expect(zh, contains('11'));
      expect(zh, contains('26'));
      expect(en, 'November 26, 2026');
      expect(zh, isNot(en));
    },
  );
}
