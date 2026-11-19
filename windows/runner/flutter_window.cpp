#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include "audioplayers_windows/audioplayers_windows_plugin.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h"
#include "desktop_wallpaper_plugin.h"
#include "data_hub_plugin.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // The desktop-layer channel is registered per engine. The main window owns
  // the optional static wallpaper mode; secondary engines own their own
  // transparent overlay (Vectra-style always-on-bottom widget window).
  RegisterDesktopWallpaperPlugin(flutter_controller_->engine()->messenger(),
                                 GetHandle());
  // Process-wide data hub: one channel pair per engine, shared singleton
  // behind them. Must be registered for the main engine too.
  RegisterDataHubPlugin(flutter_controller_->engine()->messenger());
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    if (flutter_view_controller == nullptr ||
        flutter_view_controller->engine() == nullptr) {
      return;
    }
    auto *registry = flutter_view_controller->engine();
    // 子 engine 只注册多 engine 安全的插件子集，不能走整份 RegisterPlugins：
    // auto_updater 的 AutoUpdater 是进程级单例，第二次构造直接 throw
    // std::invalid_argument，未捕获会 abort() 冻死主平台线程（ADR-0010）。
    // 其余插件与主 engine 保持一致；跨 engine 不发声由 Dart 层保证（ADR-0005），
    // 但 audioplayers 通道必须注册——子 engine 启动期也会构造 AudioPlayer。
    AudioplayersWindowsPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("AudioplayersWindowsPlugin"));
    DesktopMultiWindowPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("DesktopMultiWindowPlugin"));
    FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("FlutterSecureStorageWindowsPlugin"));
    RegisterDataHubPlugin(registry->messenger());
    HWND root = nullptr;
    if (flutter_view_controller->view() != nullptr) {
      root = ::GetAncestor(
          flutter_view_controller->view()->GetNativeWindow(), GA_ROOT);
    }
    if (root != nullptr) {
      RegisterDesktopWallpaperPlugin(registry->messenger(), root);
    }
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
