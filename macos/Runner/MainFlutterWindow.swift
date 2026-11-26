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
    launchAtStartupPlugin = MacLaunchAtStartupPlugin(
      messenger: flutterViewController.registrar(forPlugin: "LaunchAtStartup").messenger
    )

    // 子 engine 不会自动继承主窗口的插件注册。
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      self.registerPlatformPlugins(for: controller)
    }

    super.awakeFromNib()
  }

  private func registerPlatformPlugins(for controller: FlutterViewController) {
    RegisterGeneratedPlugins(registry: controller)
    let messenger = controller.registrar(forPlugin: "PlanstarDesktop").messenger
    _ = MacDataHubPlugin(messenger: messenger)
    if let window = controller.view.window {
      _ = MacDesktopWallpaperPlugin(window: window, messenger: messenger)
    }
  }
}
