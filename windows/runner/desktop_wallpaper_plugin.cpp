#include "desktop_wallpaper_plugin.h"

#include <dwmapi.h>

#include <flutter/encodable_value.h>

#include <algorithm>
#include <any>
#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "pigeon/planstar_api.g.h"

namespace {

namespace pp = planstar::pigeon;

using flutter::CustomEncodableValue;
using flutter::EncodableList;

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

// Pigeon encodes custom classes as CustomEncodableValue(std::any).
const pp::CardRectDto* AsRect(const flutter::EncodableValue& value) {
  if (const auto* custom = std::get_if<CustomEncodableValue>(&value)) {
    const std::any& payload = *custom;
    return std::any_cast<pp::CardRectDto>(&payload);
  }
  return nullptr;
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

// One generated-HostApi instance per Flutter engine. desktop_multi_window
// creates a separate engine for every widget window, so a single global would
// be overwritten by whichever engine registered last.
class DesktopWallpaperPlugin : public pp::DesktopWallpaperHostApi {
 public:
  DesktopWallpaperPlugin(flutter::BinaryMessenger* messenger, HWND window)
      : window_(window) {
    pp::DesktopWallpaperHostApi::SetUp(messenger, this);
  }

  ~DesktopWallpaperPlugin() override {
    if (overlay_) ConfigureOverlayInternal(false);
    if (attached_) Detach();
  }

  pp::ErrorOr<bool> ConfigureOverlay(bool enable) override {
    return ConfigureOverlayInternal(enable);
  }

  pp::ErrorOr<bool> SetRegion(const EncodableList& rects,
                              bool dragging) override {
    return SetRegionInternal(rects, dragging);
  }

  pp::ErrorOr<bool> IsOverlay() override { return overlay_; }

  pp::ErrorOr<bool> Attach(const pp::WindowRectDto* rect) override {
    return AttachInternal(rect);
  }

  pp::ErrorOr<bool> Detach() override { return DetachInternal(); }

  pp::ErrorOr<bool> IsAttached() override { return attached_; }

  pp::ErrorOr<bool> SetWallpaper(const std::string& path) override {
    if (path.empty()) return false;
    std::wstring mutable_path = Utf8ToWide(path);
    return ::SystemParametersInfoW(
               SPI_SETDESKWALLPAPER, 0, mutable_path.data(),
               SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE) != FALSE;
  }

  pp::ErrorOr<std::string> CurrentWallpaper() override {
    wchar_t buffer[MAX_PATH] = {0};
    if (!::SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, buffer, 0)) {
      return std::string();
    }
    return WideToUtf8(std::wstring(buffer));
  }

  pp::ErrorOr<pp::DesktopMetricsDto> DesktopMetrics() override {
    return pp::DesktopMetricsDto(
        ::GetSystemMetrics(SM_XVIRTUALSCREEN),
        ::GetSystemMetrics(SM_YVIRTUALSCREEN),
        ::GetSystemMetrics(SM_CXVIRTUALSCREEN),
        ::GetSystemMetrics(SM_CYVIRTUALSCREEN));
  }

 private:
  // Clips the window to the union of rounded card rectangles. An empty list
  // or dragging=true removes the region so the whole screen stays hittable
  // while the card is being dragged (avoids per-frame region redraw trails).
  bool SetRegionInternal(const EncodableList& rects, bool dragging) {
    if (!::IsWindow(window_)) return false;
    if (dragging) {
      ::SetWindowRgn(window_, nullptr, TRUE);
      return true;
    }
    HRGN combined = ::CreateRectRgn(0, 0, 0, 0);
    for (const auto& item : rects) {
      const pp::CardRectDto* rect = AsRect(item);
      if (rect == nullptr) continue;
      const int x = static_cast<int>(rect->x());
      const int y = static_cast<int>(rect->y());
      const int w = static_cast<int>(rect->width());
      const int h = static_cast<int>(rect->height());
      const int radius = static_cast<int>(rect->radius());
      if (w <= 0 || h <= 0) continue;
      const int diameter = radius * 2;
      HRGN one = ::CreateRoundRectRgn(x, y, x + w + 1, y + h + 1, diameter,
                                      diameter);
      ::CombineRgn(combined, combined, one, RGN_OR);
      ::DeleteObject(one);
    }
    // SetWindowRgn takes ownership of `combined` on success.
    return ::SetWindowRgn(window_, combined, TRUE) != 0;
  }

  bool ConfigureOverlayInternal(bool enable) {
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
          g_original_procs[window_] = reinterpret_cast<WNDPROC>(previous);
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
  bool AttachInternal(const pp::WindowRectDto* rect) {
    if (attached_) return true;
    HWND host = FindDesktopHost();
    if (host == nullptr || !::IsWindow(window_)) return false;
    ::GetWindowRect(window_, &original_rect_);
    original_parent_ = ::GetParent(window_);
    original_style_ = ::GetWindowLongPtrW(window_, GWL_STYLE);
    original_ex_style_ = ::GetWindowLongPtrW(window_, GWL_EXSTYLE);
    const int x = rect != nullptr
                      ? static_cast<int>(rect->x())
                      : ::GetSystemMetrics(SM_XVIRTUALSCREEN);
    const int y = rect != nullptr
                      ? static_cast<int>(rect->y())
                      : ::GetSystemMetrics(SM_YVIRTUALSCREEN);
    const int width = rect != nullptr
                          ? static_cast<int>(rect->width())
                          : ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
    const int height = rect != nullptr
                           ? static_cast<int>(rect->height())
                           : ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
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

  bool DetachInternal() {
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
};

std::vector<std::unique_ptr<DesktopWallpaperPlugin>> g_plugins;

}  // namespace

void RegisterDesktopWallpaperPlugin(flutter::BinaryMessenger* messenger,
                                    HWND window) {
  g_plugins.push_back(
      std::make_unique<DesktopWallpaperPlugin>(messenger, window));
}
