import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunar/lunar.dart';
import 'package:planstar_desktop_app/core/calendar_math.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/l10n/calendar_terms.dart';
import 'package:planstar_desktop_app/l10n/generated/app_localizations.dart';

final _zh = lookupAppLocalizations(const Locale('zh'));
final _en = lookupAppLocalizations(const Locale('en'));
final _chinese = RegExp(r'[\u3400-\u9fff]');

CalendarDayMeta _meta({
  String lunarLabel = '初一',
  String solarTerm = '',
  List<String> festivals = const <String>[],
  String yi = '',
  String ji = '',
}) => CalendarDayMeta(
  date: DateKey(DateTime(2026, 1, 1)),
  lunarLabel: lunarLabel,
  solarTerm: solarTerm,
  festivals: festivals,
  isRestDay: false,
  isMakeupWorkday: false,
  yi: yi,
  ji: ji,
  weekNumber: 1,
);

void _expectEnglish(String value) {
  expect(value, isNotEmpty);
  expect(value, isNot(contains(_chinese)));
}

DateKey _dateKey(Solar solar) =>
    DateKey(DateTime(solar.getYear(), solar.getMonth(), solar.getDay()));

void main() {
  group('lunar dates', () {
    test('all package day and month labels have zh/en parity', () {
      final days = LunarUtil.DAY.skip(1).toList();
      expect(days, hasLength(30));
      for (final raw in days) {
        final meta = _meta(lunarLabel: raw);
        expect(meta.localizedLunarLabel(_zh), raw);
        _expectEnglish(meta.localizedLunarLabel(_en));
      }

      final months = LunarUtil.MONTH.skip(1);
      expect(months, hasLength(12));
      for (final month in months) {
        for (final raw in <String>['$month月', '闰$month月']) {
          final meta = _meta(lunarLabel: raw);
          expect(meta.localizedLunarLabel(_zh), raw);
          _expectEnglish(meta.localizedLunarLabel(_en));
        }
      }
    });

    test('real first, second, last and leap-month boundaries localize', () {
      final firstMonth = LunarYear.fromYear(2024).getMonth(1)!;
      final leapMonth = LunarYear.fromYear(2025).getMonth(-6)!;
      final dates = <Lunar>[
        Lunar.fromYmd(2024, 1, 1),
        Lunar.fromYmd(2024, 1, 2),
        Lunar.fromYmd(2024, 1, firstMonth.getDayCount()),
        Lunar.fromYmd(2024, 2, 1),
        Lunar.fromYmd(2025, -6, 1),
        Lunar.fromYmd(2025, -6, 2),
        Lunar.fromYmd(2025, -6, leapMonth.getDayCount()),
      ];
      final labels = <String>[];
      for (final lunar in dates) {
        final meta = CalendarMath.metaOf(_dateKey(lunar.getSolar()));
        final raw = lunar.getDay() == 1
            ? '${lunar.getMonthInChinese()}月'
            : lunar.getDayInChinese();
        expect(meta.lunarLabel, raw);
        expect(meta.localizedLunarLabel(_zh), raw);
        _expectEnglish(meta.localizedLunarLabel(_en));
        labels.add(raw);
      }
      expect(labels.first, '正月');
      expect(labels[1], '初二');
      expect(labels, contains('闰六月'));
      expect(
        CalendarMath.metaOf(
          _dateKey(Lunar.fromYmd(2025, -6, 1).getSolar()),
        ).localizedLunarLabel(_en),
        'Leap 6th lunar month',
      );
    });

    test('localization does not change raw metadata or cache identity', () {
      final date = DateKey(DateTime(2025, 1, 29));
      final meta = CalendarMath.metaOf(date);
      expect(meta.lunarLabel, '正月');
      expect(meta.localizedLunarLabel(_en), '1st lunar month');
      expect(meta.lunarLabel, '正月');
      expect(identical(CalendarMath.metaOf(date), meta), isTrue);
    });
  });

  group('solar terms', () {
    test('a real year emits and localizes all 24 package solar terms', () {
      final byTerm = <String, DateKey>{};
      var day = DateTime(2026, 1, 1);
      while (day.year == 2026) {
        final date = DateKey(day);
        final raw = CalendarMath.metaOf(date).solarTerm;
        if (raw.isNotEmpty) byTerm[raw] = date;
        day = day.add(const Duration(days: 1));
      }
      expect(byTerm, hasLength(24));
      for (final entry in byTerm.entries) {
        final meta = CalendarMath.metaOf(entry.value);
        expect(meta.localizedSolarTerm(_zh), entry.key);
        _expectEnglish(meta.localizedSolarTerm(_en));
      }
      expect(
        CalendarMath.metaOf(
          DateKey(DateTime(2026, 11, 1)),
        ).localizedSolarTerm(_en),
        isEmpty,
      );
    });
  });

  group('festivals', () {
    test('all source and computed festival values are covered', () {
      final lastMonth = LunarYear.fromYear(2025).getMonths().last;
      final newYearsEve = Lunar.fromYmd(
        lastMonth.getYear(),
        lastMonth.getMonth(),
        lastMonth.getDayCount(),
      );
      final vocabulary = <String>{
        ...SolarUtil.FESTIVAL.values,
        ...SolarUtil.WEEK_FESTIVAL.values,
        ...LunarUtil.FESTIVAL.values,
        ...newYearsEve.getFestivals(),
      };
      expect(vocabulary, hasLength(33));

      for (final raw in vocabulary) {
        final meta = _meta(festivals: <String>[raw]);
        expect(meta.localizedFestivals(_zh), <String>[raw]);
        final english = meta.localizedFestivals(_en).single;
        _expectEnglish(english);
        expect(
          meta.localizedSubtitle(
            _en,
            showLunar: false,
            showSolarTerms: false,
            showFestival: true,
          ),
          english,
        );
      }
    });

    test(
      'real package output over two years matches the finite vocabulary',
      () {
        final discovered = <String>{};
        var day = DateTime(2025, 1, 1);
        while (day.year < 2027) {
          discovered.addAll(CalendarMath.metaOf(DateKey(day)).festivals);
          day = day.add(const Duration(days: 1));
        }
        expect(discovered, hasLength(33));
        for (final raw in discovered) {
          final meta = _meta(festivals: <String>[raw]);
          _expectEnglish(meta.localizedFestivals(_en).single);
        }
      },
    );
  });

  group('yi and ji', () {
    test('every LunarUtil.YI_JI value localizes in both fields', () {
      expect(LunarUtil.YI_JI, hasLength(142));
      for (final raw in LunarUtil.YI_JI) {
        final meta = _meta(yi: raw, ji: raw);
        expect(meta.localizedYi(_zh), raw);
        expect(meta.localizedJi(_zh), raw);
        _expectEnglish(meta.localizedYi(_en));
        _expectEnglish(meta.localizedJi(_en));
      }
    });

    test('real joined values preserve raw data and localize each term', () {
      final meta = CalendarMath.metaOf(DateKey(DateTime(2026, 11, 26)));
      expect(meta.yi, contains('·'));
      expect(meta.ji, contains('·'));
      expect(meta.localizedYi(_zh), meta.yi);
      expect(meta.localizedJi(_zh), meta.ji);
      _expectEnglish(meta.localizedYi(_en));
      _expectEnglish(meta.localizedJi(_en));
      expect(meta.localizedYi(_en), contains(' · '));
      expect(meta.localizedJi(_en), contains(' · '));
    });
  });

  test('subtitle keeps solar term > first festival > lunar day priority', () {
    final meta = _meta(
      lunarLabel: '初一',
      solarTerm: '立春',
      festivals: const <String>['春节', '元宵节'],
    );

    String subtitle(
      AppLocalizations l10n, {
      bool lunar = true,
      bool terms = true,
      bool festivals = true,
    }) => meta.localizedSubtitle(
      l10n,
      showLunar: lunar,
      showSolarTerms: terms,
      showFestival: festivals,
    );

    expect(subtitle(_zh), '立春');
    expect(subtitle(_en), 'Start of Spring');
    expect(subtitle(_en, terms: false), 'Spring Festival');
    expect(subtitle(_en, terms: false, festivals: false), '1st lunar day');
    expect(subtitle(_en, lunar: false), 'Start of Spring');
    expect(
      subtitle(_en, lunar: false, terms: false, festivals: false),
      isEmpty,
    );
  });
}
