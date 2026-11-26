/// Planstar cross-engine communication contract (Pigeon).
///
/// This file replaces the hand-written MethodChannel/EventChannel layer. Every
/// method, argument and return value is type-checked at compile time, removing
/// string method names, dynamic Map decoding and null-cast risks.
///
/// IMPORTANT: keep this file ASCII-only. Pigeon copies doc comments verbatim
/// into the generated C++ header, and MSVC's default code page cannot parse
/// non-ASCII comments there.
///
/// Regenerate (output paths come from the @ConfigurePigeon annotation below):
///   dart run pigeon --input pigeons/planstar_api.dart
///
/// Generated artifacts must stay in sync with windows/runner/CMakeLists.txt.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/infrastructure/pigeon/planstar_api.g.dart',
    cppHeaderOut: 'windows/runner/pigeon/planstar_api.g.h',
    cppSourceOut: 'windows/runner/pigeon/planstar_api.g.cpp',
    cppOptions: CppOptions(namespace: 'planstar::pigeon'),
    swiftOut: 'macos/Runner/Pigeon/planstar_api.g.swift',
    dartPackageName: 'planstar_desktop_app',
  ),
)
library;

import 'package:pigeon/pigeon.dart';

/// One interactive region of the desktop widget (physical pixels).
///
/// Mirrors DesktopCardRect in lib/core/ports.dart but uses a distinct name so
/// the generated code can be imported next to the domain ports.
class CardRectDto {
  CardRectDto({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.radius,
  });

  double x;
  double y;
  double width;
  double height;
  double radius;
}

/// Window rectangle in logical pixels.
class WindowRectDto {
  WindowRectDto({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double x;
  double y;
  double width;
  double height;
}

/// Virtual screen pixel metrics (GetSystemMetrics result).
class DesktopMetricsDto {
  DesktopMetricsDto({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  int x;
  int y;
  int width;
  int height;
}

// -- DataHub ---------------------------------------------------------------

/// One key/value record in the shared store.
class DataHubEntryDto {
  DataHubEntryDto({required this.key, required this.value});

  String key;
  String value;
}

/// Full snapshot returned after a mutation (monotonic revision).
class DataHubSnapshotDto {
  DataHubSnapshotDto({required this.revision, required this.entries});

  int revision;
  List<DataHubEntryDto> entries;
}

/// One cross-engine data change.
class DataChangeDto {
  DataChangeDto({
    required this.key,
    required this.revision,
    required this.origin,
    required this.deleted,
    this.value,
  });

  String key;
  int revision;
  String origin;
  bool deleted;
  String? value;
}

/// Write side of the process-wide native DataHub (Dart -> native).
///
/// Every engine funnels through one process-wide singleton that serialises
/// writes and persists them atomically. On failure the native side returns an
/// error and rolls back, so "memory changed but disk did not" never happens
/// silently.
@HostApi()
abstract class DataHubHostApi {
  /// First-time setup: set the persistence path and seed cold-start data.
  DataHubSnapshotDto configure(String filePath, List<DataHubEntryDto> entries);

  /// Current full snapshot.
  DataHubSnapshotDto snapshot();

  /// Write one key; returns the new monotonic revision.
  int write(String key, String value, String origin);

  /// Delete one key; returns the current revision when the key is absent.
  int delete(String key, String origin);

  /// Remove all keys; returns the empty snapshot.
  DataHubSnapshotDto clear();
}

/// Native -> Dart change feed (replaces the old EventChannel).
///
/// The native side calls onDataChanged after a successful write; the Dart
/// implementation forwards it to the CrossEngineSync stream.
@FlutterApi()
abstract class DataHubEventsFlutterApi {
  void onDataChanged(DataChangeDto change);
}

// -- Desktop layer ---------------------------------------------------------

/// Windows desktop-layer capability (Dart -> native).
///
/// Registered per engine: the main window and every desktop_multi_window child
/// have their own native window, so the widget configures its own window only.
@HostApi()
abstract class DesktopWallpaperHostApi {
  /// Turn this window into a transparent, bottom-most overlay covering the
  /// entire virtual screen.
  bool configureOverlay(bool enable);

  /// Clip the window to the union of the cards. While `dragging` is true the
  /// whole window stays hittable so no per-frame region redraw is needed.
  bool setRegion(List<CardRectDto> rects, bool dragging);

  /// Whether this window currently acts as the widget overlay.
  bool isOverlay();

  /// Parent the window into the desktop icon layer (WorkerW).
  bool attach(WindowRectDto? rect);

  /// Detach from the desktop icon layer.
  bool detach();

  /// Whether the window is attached to the desktop icon layer.
  bool isAttached();

  /// Set the desktop wallpaper to the image at [path].
  bool setWallpaper(String path);

  /// Current system wallpaper path.
  String currentWallpaper();

  /// Virtual screen pixel metrics.
  DesktopMetricsDto desktopMetrics();
}
