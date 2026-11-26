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

/// Complete LunarUtil.YI_JI vocabulary, also used by both yi and ji.
const _yiJiEn = <String, String>{
  '祭祀': 'Offer sacrifices',
  '祈福': 'Pray for blessings',
  '求嗣': 'Pray for offspring',
  '开光': 'Consecrate a statue',
  '塑绘': 'Sculpt and paint',
  '齐醮': 'Grand Taoist ritual',
  '斋醮': 'Taoist fasting ritual',
  '沐浴': 'Bathe',
  '酬神': 'Repay the gods',
  '造庙': 'Build a temple',
  '祀灶': 'Worship the kitchen god',
  '焚香': 'Burn incense',
  '谢土': 'Thank the earth spirit',
  '出火': 'Move a fire source',
  '雕刻': 'Carve',
  '嫁娶': 'Get married',
  '订婚': 'Get engaged',
  '纳采': 'Receive betrothal gifts',
  '问名': 'Ask for a marriage name',
  '纳婿': 'Take a son-in-law',
  '归宁': 'Visit parents after marriage',
  '安床': 'Set up a bed',
  '合帐': 'Make wedding curtains',
  '冠笄': 'Hold a coming-of-age ceremony',
  '订盟': 'Form an engagement',
  '进人口': 'Bring someone into the household',
  '裁衣': 'Cut and sew clothes',
  '挽面': 'Thread facial hair',
  '开容': 'Apply makeup',
  '修坟': 'Repair a grave',
  '启钻': 'Exhume a coffin',
  '破土': 'Break ground',
  '安葬': 'Inter a body',
  '立碑': 'Erect a tombstone',
  '成服': 'Put on mourning clothes',
  '除服': 'Remove mourning clothes',
  '开生坟': 'Open a new grave site',
  '合寿木': 'Prepare a coffin',
  '入殓': 'Place a body in a coffin',
  '移柩': 'Move a coffin',
  '普渡': 'Perform a universal salvation rite',
  '入宅': 'Move into a home',
  '安香': 'Install incense',
  '安门': 'Install a gate',
  '修造': 'Repair and build',
  '起基': 'Lay a foundation',
  '动土': 'Start construction',
  '上梁': 'Raise the roof beam',
  '竖柱': 'Erect columns',
  '开井开池': 'Dig a well or pond',
  '作陂放水': 'Build embankments and drain water',
  '拆卸': 'Dismantle',
  '破屋': 'Demolish a house',
  '坏垣': 'Break down a wall',
  '补垣': 'Repair a wall',
  '伐木做梁': 'Cut timber for beams',
  '作灶': 'Build a stove',
  '解除': 'Remove a taboo',
  '开柱眼': 'Open timber joints',
  '穿屏扇架': 'Assemble screens and frames',
  '盖屋合脊': 'Roof a house',
  '开厕': 'Open a toilet',
  '造仓': 'Build a granary',
  '塞穴': 'Seal a hole',
  '平治道涂': 'Level and pave roads',
  '造桥': 'Build a bridge',
  '作厕': 'Build a toilet',
  '筑堤': 'Build an embankment',
  '开池': 'Dig a pond',
  '伐木': 'Cut wood',
  '开渠': 'Dig a channel',
  '掘井': 'Dig a well',
  '扫舍': 'Clean the house',
  '放水': 'Drain water',
  '造屋': 'Build a house',
  '合脊': 'Join roof ridges',
  '造畜稠': 'Build a livestock pen',
  '修门': 'Repair a gate',
  '定磉': 'Set foundation stones',
  '作梁': 'Make roof beams',
  '修饰垣墙': 'Repair courtyard walls',
  '架马': 'Set up scaffolding',
  '开市': 'Open a business',
  '挂匾': 'Hang a plaque',
  '纳财': 'Receive wealth',
  '求财': 'Seek wealth',
  '开仓': 'Open a granary',
  '买车': 'Buy a vehicle',
  '置产': 'Acquire property',
  '雇佣': 'Hire workers',
  '出货财': 'Ship goods',
  '安机械': 'Install machinery',
  '造车器': 'Make carts and tools',
  '经络': 'Treat the meridians',
  '酝酿': 'Brew',
  '作染': 'Dye fabric',
  '鼓铸': 'Cast metal',
  '造船': 'Build a boat',
  '割蜜': 'Harvest honey',
  '栽种': 'Plant',
  '取渔': 'Fish',
  '结网': 'Mend fishing nets',
  '牧养': 'Raise livestock',
  '安碓磑': 'Install a mill',
  '习艺': 'Learn a craft',
  '入学': 'Start school',
  '理发': 'Cut hair',
  '探病': 'Visit the sick',
  '见贵': 'Meet an influential person',
  '乘船': 'Travel by boat',
  '渡水': 'Cross water',
  '针灸': 'Acupuncture and moxibustion',
  '出行': 'Travel',
  '移徙': 'Move house',
  '分居': 'Live separately',
  '剃头': 'Shave the head',
  '整手足甲': 'Trim fingernails and toenails',
  '纳畜': 'Raise animals',
  '捕捉': 'Capture animals',
  '畋猎': 'Hunt',
  '教牛马': 'Train cattle and horses',
  '会亲友': 'Meet friends and relatives',
  '赴任': 'Take up a post',
  '求医': 'Seek medical care',
  '治病': 'Treat illness',
  '词讼': 'Litigate',
  '起基动土': 'Lay foundations and break ground',
  '破屋坏垣': 'Demolish a house and wall',
  '盖屋': 'Roof a house',
  '造仓库': 'Build a warehouse',
  '立券交易': 'Make a contract and trade',
  '交易': 'Trade',
  '立券': 'Make a contract',
  '安机': 'Install machinery',
  '会友': 'Meet friends',
  '求医疗病': 'Seek treatment for illness',
  '诸事不宜': 'Nothing is advisable',
  '馀事勿取': 'Avoid all other activities',
  '行丧': 'Hold a funeral procession',
  '断蚁': 'Control ants',
  '归岫': 'Return to seclusion',
  '无': 'None',
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

String _localizedYiJi(String raw, AppLocalizations l10n) {
  if (raw.isEmpty) return '';
  final terms = raw.split('·').map((term) => term.trim());
  if (!_isEnglish(l10n)) return terms.join('·');
  return terms.map((term) => _yiJiEn[term] ?? term).join(' · ');
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

  String localizedYi(AppLocalizations l10n) => _localizedYiJi(yi, l10n);

  String localizedJi(AppLocalizations l10n) => _localizedYiJi(ji, l10n);

  /// Same priority as the raw subtitle: solar term > first festival > lunar day.
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
