/// Runtime Chinese/English presentation for the finite vocabulary emitted by
/// `lunar` 1.7.9. Raw values stay in [CalendarDayMeta] and its date cache.
library;

import '../core/calendar_math.dart';
import 'generated/app_localizations.dart';

const _lunarMonthEn = <String, String>{
  '正': '1st lunar month',
  '二': '2nd lunar month',
  '三': '3rd lunar month',
  '四': '4th lunar month',
  '五': '5th lunar month',
  '六': '6th lunar month',
  '七': '7th lunar month',
  '八': '8th lunar month',
  '九': '9th lunar month',
  '十': '10th lunar month',
  '冬': '11th lunar month',
  '腊': '12th lunar month',
};

const _lunarDayEn = <String, String>{
  '初一': '1st lunar day',
  '初二': '2nd lunar day',
  '初三': '3rd lunar day',
  '初四': '4th lunar day',
  '初五': '5th lunar day',
  '初六': '6th lunar day',
  '初七': '7th lunar day',
  '初八': '8th lunar day',
  '初九': '9th lunar day',
  '初十': '10th lunar day',
  '十一': '11th lunar day',
  '十二': '12th lunar day',
  '十三': '13th lunar day',
  '十四': '14th lunar day',
  '十五': '15th lunar day',
  '十六': '16th lunar day',
  '十七': '17th lunar day',
  '十八': '18th lunar day',
  '十九': '19th lunar day',
  '二十': '20th lunar day',
  '廿一': '21st lunar day',
  '廿二': '22nd lunar day',
  '廿三': '23rd lunar day',
  '廿四': '24th lunar day',
  '廿五': '25th lunar day',
  '廿六': '26th lunar day',
  '廿七': '27th lunar day',
  '廿八': '28th lunar day',
  '廿九': '29th lunar day',
  '三十': '30th lunar day',
};

/// The 24 names returned by `Lunar.getJieQi` (after its alias conversion).
const _solarTermEn = <String, String>{
  '立春': 'Start of Spring',
  '雨水': 'Rain Water',
  '惊蛰': 'Awakening of Insects',
  '春分': 'Spring Equinox',
  '清明': 'Qingming',
  '谷雨': 'Grain Rain',
  '立夏': 'Start of Summer',
  '小满': 'Grain Buds',
  '芒种': 'Grain in Ear',
  '夏至': 'Summer Solstice',
  '小暑': 'Minor Heat',
  '大暑': 'Major Heat',
  '立秋': 'Start of Autumn',
  '处暑': 'End of Heat',
  '白露': 'White Dew',
  '秋分': 'Autumn Equinox',
  '寒露': 'Cold Dew',
  '霜降': "Frost's Descent",
  '立冬': 'Start of Winter',
  '小雪': 'Minor Snow',
  '大雪': 'Major Snow',
  '冬至': 'Winter Solstice',
  '小寒': 'Minor Cold',
  '大寒': 'Major Cold',
};

/// Union of SolarUtil.FESTIVAL, SolarUtil.WEEK_FESTIVAL,
/// LunarUtil.FESTIVAL and the computed `除夕` in Lunar.getFestivals.
const _festivalEn = <String, String>{
  '元旦节': "New Year's Day",
  '情人节': "Valentine's Day",
  '妇女节': "International Women's Day",
  '植树节': 'Arbor Day',
  '消费者权益日': 'Consumer Rights Day',
  '愚人节': "April Fools' Day",
  '劳动节': 'Labor Day',
  '青年节': 'Youth Day',
  '儿童节': "Children's Day",
  '建党节': 'Founding Day of the Communist Party of China',
  '建军节': 'PLA Founding Day',
  '教师节': "Teachers' Day",
  '国庆节': 'National Day',
  '万圣节前夜': 'Halloween Eve',
  '万圣节': 'Halloween',
  '平安夜': 'Christmas Eve',
  '圣诞节': 'Christmas Day',
  '全国中小学生安全教育日': 'National School Safety Education Day',
  '母亲节': "Mother's Day",
  '全国助残日': 'National Disability Assistance Day',
  '父亲节': "Father's Day",
  '全民国防教育日': 'National Defense Education Day',
  '世界住房日': 'World Habitat Day',
  '感恩节': 'Thanksgiving Day',
  '春节': 'Spring Festival',
  '元宵节': 'Lantern Festival',
  '龙头节': 'Dragon Head Festival',
  '端午节': 'Dragon Boat Festival',
  '七夕节': 'Qixi Festival',
  '中秋节': 'Mid-Autumn Festival',
  '重阳节': 'Double Ninth Festival',
  '腊八节': 'Laba Festival',
  '除夕': "Chinese New Year's Eve",
};

bool _isEnglish(AppLocalizations l10n) =>
    l10n.localeName.toLowerCase().startsWith('en');

String _localized(
  String raw,
  AppLocalizations l10n,
  Map<String, String> english,
) {
  if (raw.isEmpty || !_isEnglish(l10n)) return raw;
  // Preserve an unexpected future package value rather than silently hiding it.
  return english[raw] ?? raw;
}

/// Presentation only: these methods never mutate or persist [CalendarDayMeta].
extension CalendarDayMetaLocalization on CalendarDayMeta {
  String localizedLunarLabel(AppLocalizations l10n) {
    if (!lunarLabel.endsWith('月')) {
      return _localized(lunarLabel, l10n, _lunarDayEn);
    }
    if (!_isEnglish(l10n)) return lunarLabel;
    final leap = lunarLabel.startsWith('闰');
    final month = lunarLabel.substring(leap ? 1 : 0, lunarLabel.length - 1);
    final label = _lunarMonthEn[month] ?? lunarLabel;
    return leap ? 'Leap $label' : label;
  }

  String localizedSolarTerm(AppLocalizations l10n) =>
      _localized(solarTerm, l10n, _solarTermEn);

  List<String> localizedFestivals(AppLocalizations l10n) => festivals
      .map((festival) => _localized(festival, l10n, _festivalEn))
      .toList(growable: false);

  /// 副标题优先级：节气 > 首个节日 > 农历日。
  String localizedSubtitle(
    AppLocalizations l10n, {
    required bool showLunar,
    required bool showSolarTerms,
    required bool showFestival,
  }) {
    if (showSolarTerms && solarTerm.isNotEmpty) {
      return localizedSolarTerm(l10n);
    }
    if (showFestival && festivals.isNotEmpty) {
      return localizedFestivals(l10n).first;
    }
    if (showLunar) return localizedLunarLabel(l10n);
    return '';
  }
}
