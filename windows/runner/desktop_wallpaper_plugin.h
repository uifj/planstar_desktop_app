#ifndef RUNNER_DESKTOP_WALLPAPER_PLUGIN_H_
#define RUNNER_DESKTOP_WALLPAPER_PLUGIN_H_

#include <windows.h>

#include <flutter/binary_messenger.h>

// Registers the Pigeon-generated DesktopWallpaperHostApi for one engine.
// `window` must be that engine's top-level HWND. One instance per engine is
// kept alive (desktop_multi_window creates an engine per widget window).
//
// The contract lives in `pigeons/planstar_api.dart`; regenerate with
// `dart run pigeon --input pigeons/planstar_api.dart`.
void RegisterDesktopWallpaperPlugin(flutter::BinaryMessenger* messenger,
                                    HWND window);

#endif  // RUNNER_DESKTOP_WALLPAPER_PLUGIN_H_
