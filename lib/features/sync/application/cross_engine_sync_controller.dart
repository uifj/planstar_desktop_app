/// 跨 engine 数据同步：收到磁盘 revision 变化后刷新存储缓存并重载全部读模型。
///
/// 主窗口与桌面小组件窗口是两个 Flutter engine，`SharedPreferences` 各自
/// 缓存；[CrossEngineSync] 负责发信号，这里负责「刷新 + 重新读聚合」。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../calendar/application/calendar_controllers.dart';
import '../../countdown/application/countdown_controller.dart';
import '../../history/application/history_controller.dart';
import '../../notes/application/notes_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../subscription/application/subscription_controller.dart';
import '../../timetable/application/timetable_controller.dart';

final crossEngineSyncControllerProvider =
    NotifierProvider<CrossEngineSyncController, int>(
  CrossEngineSyncController.new,
);

final class CrossEngineSyncController extends Notifier<int> {
  @override
  int build() {
    // 只在入口 initState 里被 ref.read，没有 widget watch 它；Riverpod 3
    // 默认会在无人监听时 dispose 此 controller，连同 revision 订阅一起取消，
    // 导致子窗口的编辑永远不会被主窗口 reload。必须显式保活。
    ref.keepAlive();
    final subscription =
        ref.watch(crossEngineSyncProvider).changes.listen((_) {
      _reload();
    });
    ref.onDispose(subscription.cancel);
    return 0;
  }

  Future<void> _reload() async {
    await ref.read(storageReloaderProvider).reload();
    await Future.wait(<Future<void>>[
      ref.read(calendarControllerProvider.notifier).load(),
      ref.read(settingsControllerProvider.notifier).load(),
      ref.read(notesControllerProvider.notifier).load(),
      ref.read(countdownControllerProvider.notifier).load(),
      ref.read(subscriptionControllerProvider.notifier).load(),
      ref.read(timetableControllerProvider.notifier).load(),
      ref.read(historyControllerProvider.notifier).load(),
    ]);
    state++;
  }
}
