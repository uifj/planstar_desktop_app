#ifndef RUNNER_DESKTOP_WALLPAPER_PLUGIN_H_
#define RUNNER_DESKTOP_WALLPAPER_PLUGIN_H_

#include <windows.h>

#include <flutter/binary_messenger.h>

// Registers the "planstar/desktop_wallpaper" method channel for one engine.
// `window` must be that engine's top-level HWND. One instance per engine is
// kept alive (desktop_multi_window creates an engine per widget window).
//
// Methods: configureOverlay, setRegion, isOverlay, attach, detach,
// isAttached, setWallpaper, getWallpaper, desktopMetrics.
void RegisterDesktopWallpaperPlugin(flutter::BinaryMessenger* messenger,
                                    HWND window);

#endif  // RUNNER_DESKTOP_WALLPAPER_PLUGIN_H_
