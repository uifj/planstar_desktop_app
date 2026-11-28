import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  private var launchAtStartupPlugin: MacLaunchAtStartupPlugin?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    registerPlatformPlugins(for: flutterViewController)
    // 登录项只属于主应用，子 engine 不注册。
    launchAtStartupPlugin = MacLaunchAtStartupPlugin(
      messenger: flutterViewController.registrar(forPlugin: "LaunchAtStartup").messenger
    )

    // 子 engine 不会自动继承主窗口的插件注册。
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller, window in
      self.registerPlatformPlugins(for: controller, window: window)
    }

    super.awakeFromNib()
  }

  private func registerPlatformPlugins(for controller: FlutterViewController, window: NSWindow? = nil) {
    RegisterGeneratedPlugins(registry: controller)
    let messenger = controller.registrar(forPlugin: "PlanstarDesktop").messenger
    _ = MacDataHubPlugin(messenger: messenger)
    let pluginWindow = window ?? controller.view.window
    if let pluginWindow {
      _ = MacDesktopWallpaperPlugin(window: pluginWindow, messenger: messenger)
    }
  }
}
