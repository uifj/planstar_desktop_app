import AppKit

enum MainWindowRestorer {
  static func restoreMainWindows(in windows: [NSWindow]) {
    // 最小化会临时让 canBecomeMain=false，因此必须同时接受 isMiniaturized。
    for window in windows where window.canBecomeMain || window.isMiniaturized {
      if window.isMiniaturized {
        window.deminiaturize(nil)
      }
      window.makeKeyAndOrderFront(nil)
    }
  }
}
