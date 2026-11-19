/// 托盘端口。
library;

/// 托盘菜单项动作。
enum TrayAction {
  show,
  hide,
  toggle,
  sync,
  settings,
  timetable,
  notes,
  about,
  embedDesktop,
  toggleDesktopWidget,
  showDesktopWidget,
  hideDesktopWidget,
  refreshWallpaper,
  exit,
}

abstract interface class TrayGateway {
  Future<void> initialize(void Function(TrayAction action) onAction);

  Future<void> dispose();
}
