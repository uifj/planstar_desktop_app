/// 应用层端口（六边形架构的「驱动侧」契约）。
///
/// 这里只有抽象接口与端口自带的小 DTO，具体实现放在 `lib/infrastructure/`。
/// 领域层与表现层都不 import 任何插件，插件只在组合根被注入。
library;

import 'dart:async';
import 'dart:typed_data';

/// 跨 Flutter engine 的存储缓存刷新。
///
/// `desktop_multi_window` 的每个窗口都是独立 engine / isolate，
/// `shared_preferences` 各自持有内存缓存，别处的写入不会自动可见。
abstract interface class StorageReloader {
  Future<void> reload();
}

/// 跨 engine 的「数据已变更」信号（基于磁盘标记文件 + 轮询）。
abstract interface class CrossEngineSync {
  Future<void> signalChange();

  Stream<void> get changes;
}

/// 时钟端口：让「今天」「提前量」可测，避免聚合直接读 `DateTime.now()`。
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// 提示音：对齐旧版 `taskcomplete/ding*.mp3` 与 `reminder/alarm_littlestar.mp3`。
enum SoundTone {
  none('无', null),
  ding('滴答', 'audio/audio_ding.mp3'),
  ding2('叮当', 'audio/audio_ding2.mp3'),
  ding3('叮咚', 'audio/audio_ding3.mp3'),
  dong('咚', 'audio/audio_ding.mp3'),
  littleStar('小星星', 'audio/audio_alarm_littlestar.mp3');

  const SoundTone(this.label, this.asset);

  final String label;
  final String? asset;

  static SoundTone fromName(String? name) => SoundTone.values.firstWhere(
        (SoundTone t) => t.name == name,
        orElse: () => SoundTone.none,
      );
}

abstract interface class SoundGateway {
  Future<void> play(SoundTone tone);
}

/// 一条待投递的本地通知。
final class ScheduledReminder {
  const ScheduledReminder({
    required this.notificationId,
    required this.eventId,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.payload,
  });

  final int notificationId;
  final String eventId;
  final String title;
  final String body;
  final DateTime fireAt;

  /// 点击通知时回传的数据（通常是 `eventId|date`）。
  final String payload;
}

abstract interface class NotificationGateway {
  Future<void> initialize();

  Future<void> schedule(ScheduledReminder reminder);

  Future<void> cancelForEvent(String eventId);

  Future<void> cancelAll();

  /// 点击通知 / 前台收到提醒时发出的 eventId 流，用于弹置顶提醒窗。
  Stream<String> get activations;
}

/// 与平台无关的窗口矩形，避免端口依赖 `dart:ui`。
final class WindowRect {
  const WindowRect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, Object?> toJson() => <String, Object?>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory WindowRect.fromJson(Map<String, Object?> json) => WindowRect(
        (json['x'] as num?)?.toDouble() ?? 100,
        (json['y'] as num?)?.toDouble() ?? 100,
        (json['width'] as num?)?.toDouble() ?? 360,
        (json['height'] as num?)?.toDouble() ?? 420,
      );

  WindowRect copyWith({double? x, double? y, double? width, double? height}) =>
      WindowRect(
        x ?? this.x,
        y ?? this.y,
        width ?? this.width,
        height ?? this.height,
      );
}

abstract interface class WindowGateway {
  Future<void> initializeMainWindow();

  Future<void> initializeSubWindow(String title, WindowRect rect);

  Future<void> setAlwaysOnTop(bool value);

  Future<void> setOpacity(double value);

  /// 自定义标题栏拖动窗口。
  Future<void> startDragging();

  Future<void> show();

  Future<void> hide();

  Future<void> minimize();

  Future<void> toggleMaximize();

  Future<void> close();

  Future<WindowRect> bounds();

  Future<void> setBounds(WindowRect rect);
}

/// 托盘菜单项动作。
enum TrayAction {
  show,
  hide,
  toggle,
  sync,
  settings,
  timetable,
  notes,
  about,
  embedDesktop,
  toggleDesktopWidget,
  refreshWallpaper,
  exit,
}

abstract interface class TrayGateway {
  Future<void> initialize(void Function(TrayAction action) onAction);

  Future<void> dispose();
}

/// 多窗口消息（主窗口 → 子窗口 / 反向）。
final class MultiWindowCommand {
  const MultiWindowCommand(this.method, this.arguments);

  final String method;
  final Map<String, Object?> arguments;
}

abstract interface class MultiWindowGateway {
  /// 打开独立便签窗口（旧版「便签置顶」「桌面便签」）。
  Future<String> openNoteWindow(String noteId, {WindowRect? rect});

  /// 打开倒数日桌面卡片窗口。
  Future<String> openCountdownWindow({WindowRect? rect});

  /// 打开「贴在桌面上的可编辑月历小组件」窗口（Vectra 式 overlay）。
  Future<String> openDesktopWidget();

  /// 隐藏当前 engine 所属的窗口（桌面小组件的「收起」）。
  Future<void> hideCurrentWindow();

  Future<List<String>> openWindowIds();

  Future<void> closeWindow(String windowId);

  Future<void> sendTo(String windowId, MultiWindowCommand command);

  /// 子窗口收到的指令。
  Stream<MultiWindowCommand> get incoming;
}

abstract interface class AutoStartGateway {
  Future<void> setEnabled(bool enabled);

  Future<bool> isEnabled();
}

/// 桌面（虚拟屏幕）像素尺寸，用于把月历渲染成与壁纸同尺寸的图片。
final class DesktopMetrics {
  const DesktopMetrics({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  static const DesktopMetrics fallback = DesktopMetrics(
    x: 0,
    y: 0,
    width: 1920,
    height: 1080,
  );
}

/// Windows 桌面层能力：把主窗口挂到 `WorkerW`（贴在桌面图标层）、
/// 以及通过 `SystemParametersInfo(SPI_SETDESKWALLPAPER)` 设置壁纸图片。
///
/// 非 Windows 平台 / 单元测试里插件不存在，适配器须自行降级而非抛异常。
/// 壁纸图片落盘端口：把渲染出的 PNG 存到应用数据目录，并读取用户选择的底图。
abstract interface class WallpaperImageGateway {
  Future<String> savePng(Uint8List bytes);

  Future<Uint8List?> readImage(String path);

  /// 列出壁纸轮播目录里的图片（按文件名排序）。
  Future<List<String>> listImages(String directory);

  /// 生成的壁纸文件路径。
  Future<String> get outputPath;

  /// 「从桌面抓取图片」需要记住用户原本的壁纸，否则每次刷新都会把
  /// 自己生成的图片再次当作底图叠加。
  Future<String> readOriginalWallpaper();

  Future<void> writeOriginalWallpaper(String path);

  Future<String> get outputDirectory;
}

/// 桌面小组件的一块可交互区域（物理像素，圆角矩形）。
final class DesktopCardRect {
  const DesktopCardRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.radius = 16,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double radius;

  Map<String, Object?> toJson() => <String, Object?>{
        'x': x.round(),
        'y': y.round(),
        'width': width.round(),
        'height': height.round(),
        'radius': radius.round(),
      };
}

abstract interface class DesktopWallpaperGateway {
  /// 把当前窗口变成覆盖虚拟屏、透明、常驻最底的桌面小组件层。
  Future<bool> configureOverlay({required bool enable});

  /// 把窗口裁剪成卡片并集：卡片内可点击编辑，卡片外点击穿透到桌面图标。
  /// `dragging` 为 true 时临时放开整窗，避免逐帧重设区域产生残影。
  Future<bool> setRegion({
    required List<DesktopCardRect> rects,
    bool dragging = false,
  });

  Future<bool> isOverlay();

  Future<bool> attachToDesktop({WindowRect? rect});

  Future<bool> detachFromDesktop();

  Future<bool> isAttached();

  /// 把 [path] 指向的图片设为当前桌面壁纸。
  Future<bool> setWallpaper(String path);

  /// 当前系统壁纸路径（`desktopCapture` 模式用它作为底图）。
  Future<String> currentWallpaper();

  Future<DesktopMetrics> desktopMetrics();
}

abstract interface class FileGateway {
  Future<String?> pickOpenPath();

  Future<String?> pickDirectory();

  Future<String?> pickSavePath(String suggestedName);

  Future<void> writeText(String path, String content);

  Future<String> readText(String path);

  Future<String> defaultExportDirectory();
}
