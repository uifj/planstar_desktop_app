/// 重载目标注册表的聚合点：各 feature 自带键名映射，这里只汇总。
///
/// 新增 feature 时在自己的文件里声明键与 `register*ReloadTargets`，
/// 然后在此追加一行——core 端口层不再认识任何具体持久化键。
library;

import '../core/ports.dart';
import '../features/calendar/infrastructure/local_calendar_repository.dart';
import '../features/countdown/application/countdown_controller.dart';
import '../features/history/application/history_controller.dart';
import '../features/notes/infrastructure/local_note_repository.dart';
import '../features/settings/infrastructure/settings_repository.dart';
import '../features/subscription/application/subscription_controller.dart';
import '../features/timetable/application/timetable_controller.dart';
import '../windows/desktop_widget_app.dart';

/// 构建全量注册表（纯函数，可被守卫测试直接覆盖）。
ReloadTargetRegistry buildReloadTargetRegistry() {
  final registry = ReloadTargetRegistry();
  registerCalendarReloadTargets(registry);
  registerSettingsReloadTargets(registry);
  registerNotesReloadTargets(registry);
  registerCountdownReloadTargets(registry);
  registerSubscriptionReloadTargets(registry);
  registerTimetableReloadTargets(registry);
  registerHistoryReloadTargets(registry);
  registerDesktopPositionReloadTargets(registry);
  return registry;
}
