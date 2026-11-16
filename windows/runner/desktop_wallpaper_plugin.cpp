#include "desktop_wallpaper_plugin.h"

#include <dwmapi.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodChannel;
using flutter::MethodResult;
using flutter::StandardMethodCodec;

constexpr char kChannelName[] = "planstar/desktop_wallpaper";

std::wstring Utf8ToWide(const std::string& input) {
  if (input.empty()) return std::wstring();
  const int size = ::MultiByteToWideChar(
      CP_UTF8, 0, input.c_str(), static_cast<int>(input.size()), nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring output(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, input.c_str(),
                        static_cast<int>(input.size()), &output[0], size);
  return output;
}

std::string WideToUtf8(const std::wstring& input) {
  if (input.empty()) return std::string();
  const int size = ::WideCharToMultiByte(
      CP_UTF8, 0, input.c_str(), static_cast<int>(input.size()), nullptr, 0,
      nullptr, nullptr);
  if (size <= 0) return std::string();
  std::string output(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, input.c_str(),
                        static_cast<int>(input.size()), &output[0], size,
                        nullptr, nullptr);
  return output;
}

const EncodableValue* ValueAt(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

int IntAt(const EncodableMap& map, const char* key, int fallback) {
  const EncodableValue* value = ValueAt(map, key);
  if (value == nullptr) return fallback;
  if (const auto* number = std::get_if<int>(value)) return *number;
  if (const auto* number = std::get_if<int64_t>(value)) {
    return static_cast<int>(*number);
  }
  if (const auto* number = std::get_if<double>(value)) {
    return static_cast<int>(*number);
  }
  return fallback;
}

bool BoolAt(const EncodableMap& map, const char* key, bool fallback) {
  const EncodableValue* value = ValueAt(map, key);
  if (value != nullptr) {
    if (const auto* flag = std::get_if<bool>(value)) return *flag;
  }
  return fallback;
}

std::wstring StringAt(const EncodableMap& map, const char* key) {
  const EncodableValue* value = ValueAt(map, key);
  if (value == nullptr) return std::wstring();
  if (const auto* text = std::get_if<std::string>(value)) {
    return Utf8ToWide(*text);
  }
  return std::wstring();
}

// ---------------------------------------------------------------------------
// Vectra-style desktop widget layer.
//
// The overlay is NOT a child of Progman/WorkerW. It is an independent
// WS_POPUP window covering the whole virtual screen, permanently pinned to
// HWND_BOTTOM via WM_WINDOWPOSCHANGING, with per-pixel alpha from an empty
// DWM blur region. SetWindowRgn clips it to the union of the widget cards:
// inside a card the Flutter view receives the mouse (editable), outside the
// card the hit falls through to the desktop icons.
// ---------------------------------------------------------------------------

std::unordered_map<HWND, WNDPROC> g_original_procs;
std::unordered_set<HWND> g_overlay_windows;

void CoverVirtualScreen(HWND hwnd) {
  const int x = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int y = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int w = ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int h = ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
  ::SetWindowPos(hwnd, HWND_BOTTOM, x, y, w, h,
                 SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
}

LRESULT CALLBACK BottomMostWndProc(HWND hwnd, UINT message, WPARAM wparam,
                                   LPARAM lparam) {
  if (message == WM_WINDOWPOSCHANGING) {
    auto* pos = reinterpret_cast<WINDOWPOS*>(lparam);
    if (pos != nullptr) {
      pos->hwndInsertAfter = HWND_BOTTOM;
      pos->flags &= ~SWP_NOZORDER;
    }
  } else if (message == WM_DISPLAYCHANGE || message == WM_DPICHANGED) {
    if (g_overlay_windows.count(hwnd) != 0) CoverVirtualScreen(hwnd);
  }

  const auto it = g_original_procs.find(hwnd);
  if (it == g_original_procs.end()) {
    return ::DefWindowProcW(hwnd, message, wparam, lparam);
  }
  WNDPROC original = it->second;
  if (message == WM_NCDESTROY) {
    g_original_procs.erase(hwnd);
    g_overlay_windows.erase(hwnd);
    ::SetWindowLongPtrW(hwnd, GWLP_WNDPROC,
                        reinterpret_cast<LONG_PTR>(original));
  }
  return ::CallWindowProcW(original, hwnd, message, wparam, lparam);
}

// Returns the top-level window that owns SHELLDLL_DefView (desktop icons).
// Only used by the optional static-image mode; the widget layer never calls it.
HWND FindDesktopHost() {
  HWND progman = ::FindWindowW(L"Progman", nullptr);
  if (progman != nullptr) {
    DWORD_PTR message_result = 0;
    ::SendMessageTimeoutW(progman, 0x052C, 0, 0, SMTO_NORMAL, 800,
                          &message_result);
  }
  HWND host = nullptr;
  ::EnumWindows(
      [](HWND top_level, LPARAM param) -> BOOL {
        HWND def_view =
            ::FindWindowExW(top_level, nullptr, L"SHELLDLL_DefView", nullptr);
        if (def_view == nullptr) return TRUE;
        *reinterpret_cast<HWND*>(param) = top_level;
        return FALSE;
      },
      reinterpret_cast<LPARAM>(&host));
  return host != nullptr ? host : progman;
}

class DesktopWallpaperPlugin {
 public:
  DesktopWallpaperPlugin(flutter::BinaryMessenger* messenger, HWND window)
      : window_(window) {
    channel_ = std::make_unique<MethodChannel<EncodableValue>>(
        messenger, kChannelName, &StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const MethodCall<EncodableValue>& call,
               std::unique_ptr<MethodResult<EncodableValue>> result) {
          HandleCall(call, std::move(result));
        });
  }

  ~DesktopWallpaperPlugin() {
    if (overlay_) ConfigureOverlay(false);
    if (attached_) Detach();
  }

 private:
  void HandleCall(const MethodCall<EncodableValue>& call,
                  std::unique_ptr<MethodResult<EncodableValue>> result) {
    const EncodableMap empty;
    const EncodableMap* args =
        call.arguments() ? std::get_if<EncodableMap>(call.arguments()) : &empty;
    const EncodableMap& map = args != nullptr ? *args : empty;
    const std::string& method = call.method_name();

    if (method == "configureOverlay") {
      result->Success(
          EncodableValue(ConfigureOverlay(BoolAt(map, "enable", false))));
    } else if (method == "setRegion") {
      result->Success(EncodableValue(SetRegion(map)));
    } else if (method == "isOverlay") {
      result->Success(EncodableValue(overlay_));
    } else if (method == "attach") {
      result->Success(EncodableValue(Attach(map)));
    } else if (method == "detach") {
      result->Success(EncodableValue(Detach()));
    } else if (method == "isAttached") {
      result->Success(EncodableValue(attached_));
    } else if (method == "setWallpaper") {
      result->Success(EncodableValue(SetWallpaper(StringAt(map, "path"))));
    } else if (method == "getWallpaper") {
      result->Success(EncodableValue(GetWallpaper()));
    } else if (method == "desktopMetrics") {
      EncodableMap metrics;
      metrics[EncodableValue("x")] =
          EncodableValue(::GetSystemMetrics(SM_XVIRTUALSCREEN));
      metrics[EncodableValue("y")] =
          EncodableValue(::GetSystemMetrics(SM_YVIRTUALSCREEN));
      metrics[EncodableValue("width")] =
          EncodableValue(::GetSystemMetrics(SM_CXVIRTUALSCREEN));
      metrics[EncodableValue("height")] =
          EncodableValue(::GetSystemMetrics(SM_CYVIRTUALSCREEN));
      result->Success(EncodableValue(metrics));
    } else {
      result->NotImplemented();
    }
  }

  // Clips the window to the union of rounded card rectangles. An empty list
  // or dragging=true removes the region so the whole screen stays hittable
  // while the card is being dragged (avoids per-frame region redraw trails).
  bool SetRegion(const EncodableMap& args) {
    if (!::IsWindow(window_)) return false;
    if (BoolAt(args, "dragging", false)) {
      ::SetWindowRgn(window_, nullptr, TRUE);
      return true;
    }
    HRGN combined = ::CreateRectRgn(0, 0, 0, 0);
    const EncodableValue* rects = ValueAt(args, "rects");
    if (rects != nullptr) {
      if (const auto* list = std::get_if<EncodableList>(rects)) {
        for (const EncodableValue& item : *list) {
          const auto* rect = std::get_if<EncodableMap>(&item);
          if (rect == nullptr) continue;
          const int x = IntAt(*rect, "x", 0);
          const int y = IntAt(*rect, "y", 0);
          const int w = IntAt(*rect, "width", 0);
          const int h = IntAt(*rect, "height", 0);
          const int radius = IntAt(*rect, "radius", 0);
          if (w <= 0 || h <= 0) continue;
          const int diameter = radius * 2;
          HRGN one = ::CreateRoundRectRgn(x, y, x + w + 1, y + h + 1,
                                          diameter, diameter);
          ::CombineRgn(combined, combined, one, RGN_OR);
          ::DeleteObject(one);
        }
      }
    }
    // SetWindowRgn takes ownership of `combined` on success.
    return ::SetWindowRgn(window_, combined, TRUE) != 0;
  }

  bool ConfigureOverlay(bool enable) {
    if (!::IsWindow(window_)) return false;
    if (enable == overlay_) return true;

    if (enable) {
      ::GetWindowRect(window_, &overlay_original_rect_);
      overlay_original_style_ = ::GetWindowLongPtrW(window_, GWL_STYLE);
      overlay_original_ex_style_ = ::GetWindowLongPtrW(window_, GWL_EXSTYLE);

      LONG_PTR style = overlay_original_style_;
      style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
                 WS_MAXIMIZEBOX | WS_SYSMENU | WS_CHILD);
      style |= WS_POPUP | WS_VISIBLE;
      // WS_EX_TOOLWINDOW keeps it out of Alt+Tab / taskbar. Never add
      // WS_EX_TOPMOST: widgets must live below every normal window.
      LONG_PTR ex_style = WS_EX_TOOLWINDOW;
      ::SetWindowLongPtrW(window_, GWL_STYLE, style);
      ::SetWindowLongPtrW(window_, GWL_EXSTYLE, ex_style);

      // Empty blur region = enable per-pixel alpha compositing without blur.
      // Without this the transparent parts of the Flutter surface turn black.
      HRGN empty_region = ::CreateRectRgn(0, 0, -1, -1);
      DWM_BLURBEHIND blur{};
      blur.dwFlags = DWM_BB_ENABLE | DWM_BB_BLURREGION;
      blur.fEnable = TRUE;
      blur.hRgnBlur = empty_region;
      ::DwmEnableBlurBehindWindow(window_, &blur);
      ::DeleteObject(empty_region);

      if (g_original_procs.find(window_) == g_original_procs.end()) {
        LONG_PTR previous = ::SetWindowLongPtrW(
            window_, GWLP_WNDPROC,
            reinterpret_cast<LONG_PTR>(BottomMostWndProc));
        if (previous != 0) {
          g_original_procs[window_] =
              reinterpret_cast<WNDPROC>(previous);
        }
      }
      g_overlay_windows.insert(window_);
      CoverVirtualScreen(window_);
      ::ShowWindow(window_, SW_SHOWNOACTIVATE);
      overlay_ = true;
      return true;
    }

    RestoreWndProc();
    ::SetWindowRgn(window_, nullptr, TRUE);
    DWM_BLURBEHIND blur{};
    blur.dwFlags = DWM_BB_ENABLE;
    blur.fEnable = FALSE;
    ::DwmEnableBlurBehindWindow(window_, &blur);
    ::SetWindowLongPtrW(window_, GWL_STYLE, overlay_original_style_);
    ::SetWindowLongPtrW(window_, GWL_EXSTYLE, overlay_original_ex_style_);
    ::SetWindowPos(
        window_, HWND_TOP, overlay_original_rect_.left,
        overlay_original_rect_.top,
        overlay_original_rect_.right - overlay_original_rect_.left,
        overlay_original_rect_.bottom - overlay_original_rect_.top,
        SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOACTIVATE);
    overlay_ = false;
    return true;
  }

  void RestoreWndProc() {
    const auto it = g_original_procs.find(window_);
    if (it == g_original_procs.end()) return;
    ::SetWindowLongPtrW(window_, GWLP_WNDPROC,
                        reinterpret_cast<LONG_PTR>(it->second));
    g_original_procs.erase(it);
    g_overlay_windows.erase(window_);
  }

  // Legacy optional mode: parent the window into the desktop icon layer.
  bool Attach(const EncodableMap& args) {
    if (attached_) return true;
    HWND host = FindDesktopHost();
    if (host == nullptr || !::IsWindow(window_)) return false;
    ::GetWindowRect(window_, &original_rect_);
    original_parent_ = ::GetParent(window_);
    original_style_ = ::GetWindowLongPtrW(window_, GWL_STYLE);
    original_ex_style_ = ::GetWindowLongPtrW(window_, GWL_EXSTYLE);
    const int x = IntAt(args, "x", ::GetSystemMetrics(SM_XVIRTUALSCREEN));
    const int y = IntAt(args, "y", ::GetSystemMetrics(SM_YVIRTUALSCREEN));
    const int width =
        IntAt(args, "width", ::GetSystemMetrics(SM_CXVIRTUALSCREEN));
    const int height =
        IntAt(args, "height", ::GetSystemMetrics(SM_CYVIRTUALSCREEN));
    LONG_PTR style = original_style_;
    style &= ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
               WS_MAXIMIZEBOX | WS_SYSMENU);
    style |= WS_CHILD | WS_VISIBLE;
    ::SetWindowLongPtrW(window_, GWL_STYLE, style);
    ::SetWindowLongPtrW(window_, GWL_EXSTYLE,
                        original_ex_style_ | WS_EX_TOOLWINDOW);
    ::SetParent(window_, host);
    if (::GetParent(window_) != host) {
      ::SetWindowLongPtrW(window_, GWL_STYLE, original_style_);
      ::SetWindowLongPtrW(window_, GWL_EXSTYLE, original_ex_style_);
      return false;
    }
    ::SetWindowPos(window_, HWND_TOP, x, y, width, height,
                   SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOACTIVATE);
    attached_ = true;
    return true;
  }

  bool Detach() {
    if (!attached_) return true;
    ::SetParent(window_, original_parent_);
    ::SetWindowLongPtrW(window_, GWL_STYLE, original_style_);
    ::SetWindowLongPtrW(window_, GWL_EXSTYLE, original_ex_style_);
    ::SetWindowPos(window_, HWND_TOP, original_rect_.left, original_rect_.top,
                   original_rect_.right - original_rect_.left,
                   original_rect_.bottom - original_rect_.top,
                   SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOACTIVATE);
    attached_ = false;
    return true;
  }

  bool SetWallpaper(const std::wstring& path) {
    if (path.empty()) return false;
    std::wstring mutable_path = path;
    return ::SystemParametersInfoW(
               SPI_SETDESKWALLPAPER, 0, mutable_path.data(),
               SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE) != FALSE;
  }

  std::string GetWallpaper() {
    wchar_t buffer[MAX_PATH] = {0};
    if (!::SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, buffer, 0)) {
      return std::string();
    }
    return WideToUtf8(std::wstring(buffer));
  }

  HWND window_ = nullptr;
  HWND original_parent_ = nullptr;
  LONG_PTR original_style_ = 0;
  LONG_PTR original_ex_style_ = 0;
  RECT original_rect_ = {};
  RECT overlay_original_rect_ = {};
  LONG_PTR overlay_original_style_ = 0;
  LONG_PTR overlay_original_ex_style_ = 0;
  bool attached_ = false;
  bool overlay_ = false;
  std::unique_ptr<MethodChannel<EncodableValue>> channel_;
};

// One channel instance per Flutter engine. desktop_multi_window creates a
// separate engine for every widget window, so a single global would be
// overwritten by whichever engine registered last.
std::vector<std::unique_ptr<DesktopWallpaperPlugin>> g_plugins;

}  // namespace

void RegisterDesktopWallpaperPlugin(flutter::BinaryMessenger* messenger,
                                    HWND window) {
  g_plugins.push_back(
      std::make_unique<DesktopWallpaperPlugin>(messenger, window));
}
