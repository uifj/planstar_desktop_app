import AppKit

enum MainWindowRestorer {
  static func restoreMainWindows(in windows: [NSWindow]) {
    for window in windows where window.canBecomeMain || window.isMiniaturized {
      if window.isMiniaturized {
        window.deminiaturize(nil)
      }
      window.makeKeyAndOrderFront(nil)
    }
  }
}
