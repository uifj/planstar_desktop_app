/// 提醒规格值对象：触发时刻 + 提前量多选 + 微信通知开关。
library;

import 'package:core/domain.dart';

import '../../../core/value_objects.dart';

final class ReminderSpec extends ValueObject {
  const ReminderSpec({
    this.hour = 9,
    this.minute = 0,
    this.advanceDays = const <int>[0],
    this.customAdvanceDays = 0,
    this.wechatNotify = false,
  });

  /// 旧版多选提前量：当天 / 1 / 2 / 3 / 5 天 / 1 周 / 自定义。
  static const List<int> optionalAdvanceDays = <int>[0, 1, 2, 3, 5, 7, -1];

  final int hour;
  final int minute;
  final List<int> advanceDays;
  final int customAdvanceDays;
  final bool wechatNotify;

  /// 把某个发生日展开为具体的本地触发时刻。
  List<DateTime> fireTimesFor(DateKey occurrence) {
    final result = <DateTime>{};
    for (final advance in advanceDays) {
      final days = advance == -1 ? customAdvanceDays : advance;
      final date = occurrence.addDays(-days).date;
      result.add(DateTime(date.year, date.month, date.day, hour, minute));
    }
    return result.toList()..sort();
  }

  ReminderSpec copyWith({
    int? hour,
    int? minute,
    List<int>? advanceDays,
    int? customAdvanceDays,
    bool? wechatNotify,
  }) => ReminderSpec(
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    advanceDays: advanceDays ?? this.advanceDays,
    customAdvanceDays: customAdvanceDays ?? this.customAdvanceDays,
    wechatNotify: wechatNotify ?? this.wechatNotify,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'hour': hour,
    'minute': minute,
    'advanceDays': advanceDays,
    'customAdvanceDays': customAdvanceDays,
    'wechatNotify': wechatNotify,
  };

  factory ReminderSpec.fromJson(Map<String, Object?> json) => ReminderSpec(
    hour: (json['hour'] as num?)?.toInt() ?? 9,
    minute: (json['minute'] as num?)?.toInt() ?? 0,
    advanceDays: (json['advanceDays'] as List?)?.cast<int>() ?? const <int>[0],
    customAdvanceDays: (json['customAdvanceDays'] as num?)?.toInt() ?? 0,
    wechatNotify: json['wechatNotify'] as bool? ?? false,
  );

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => <Object?>[
    hour,
    minute,
    advanceDays,
    customAdvanceDays,
    wechatNotify,
  ];
}
