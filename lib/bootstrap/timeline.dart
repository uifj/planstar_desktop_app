/// 组合根：时间线贡献注册与跨 feature 快捷命令接线（ADR-0004）。
///
/// 日历读模型只消费 [timelineContributionsProvider]，不 import 任何兄弟
/// feature；新增来源在此追加一行注册即可。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ports/timeline.dart';
import '../core/value_objects.dart';
import '../features/countdown/application/countdown_controller.dart';
import '../features/countdown/domain/countdown.dart';
import '../features/subscription/application/subscription_controller.dart';
import '../features/timetable/application/timetable_controller.dart';

/// 注册顺序即日条目拼接顺序：订阅 → 课程 → 倒数日（与旧版渲染一致）。
final timelineContributionsProvider = Provider<List<TimelineContribution>>(
  (Ref ref) => <TimelineContribution>[
    ref.watch(subscriptionContributionProvider),
    ref.watch(timetableContributionProvider),
    ref.watch(countdownContributionProvider),
  ],
);

/// 日历右键「添加倒数日」命令：日历不 import countdown，实现接在这里。
final createCountdownProvider = Provider<CreateCountdown>(
  (Ref ref) =>
      ({required String title, required DateTime targetDate}) => ref
          .read(countdownControllerProvider.notifier)
          .create(
            title: title,
            targetDate: DateKey(targetDate),
            type: CountdownType.custom,
          ),
);
