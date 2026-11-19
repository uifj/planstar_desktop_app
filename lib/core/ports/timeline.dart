/// 时间线贡献端口：兄弟 feature 向月历读模型「按日供条目」的只读契约。
///
/// 纯 Dart（日期用 DateTime，避免端口依赖 dart:ui 的 DateKey）。
/// 各 feature 在 application 层把自己的状态塑形成 [TimelineContribution]，
/// 组合根聚合成列表注入日历读模型；新增 feature 只需注册贡献，日历不改。
library;

import 'package:core/domain.dart';

/// 日条目的来源类别，渲染侧据此选择颜色槽与截断规则。
enum TimelineTagKind { subscription, lesson, countdown }

/// 日历单元格内的一条来源条目（只带渲染所需的文本与类别）。
final class TimelineTag extends ValueObject {
  const TimelineTag({required this.kind, required this.text});

  final TimelineTagKind kind;
  final String text;

  @override
  List<Object?> get props => <Object?>[kind, text];
}

/// 日历底部横条的一条展示项（文本与颜色已在贡献侧预计算）。
final class TimelineBarEntry extends ValueObject {
  const TimelineBarEntry({
    required this.title,
    required this.colorArgb,
    required this.displayText,
  });

  final String title;
  final int colorArgb;
  final String displayText;

  @override
  List<Object?> get props => <Object?>[title, colorArgb, displayText];
}

/// 一个 feature 对月历读模型的贡献快照。
///
/// [tagsOn] 按日查询（贡献侧自行决定预计算 Map 还是逐日推导）；
/// 条目不截断——截断（如课程取 2、倒数日取 1）是渲染侧决策，
/// 壁纸等其它消费方可能需要全量。
final class TimelineContribution {
  const TimelineContribution({
    required this.tagsOn,
    this.bar = const <TimelineBarEntry>[],
  });

  final List<TimelineTag> Function(DateTime date) tagsOn;
  final List<TimelineBarEntry> bar;
}

/// 快捷创建自定义倒数日的命令（日历右键菜单用，组合根注入实现）。
typedef CreateCountdown = Future<void> Function({
  required String title,
  required DateTime targetDate,
});
