/// 桌面集成端口：开机自启、桌面 overlay、壁纸图片。
library;

import 'dart:typed_data';

import 'window.dart';

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

/// Windows 桌面层能力：把主窗口挂到 `WorkerW`（贴在桌面图标层）、
/// 以及通过 `SystemParametersInfo(SPI_SETDESKWALLPAPER)` 设置壁纸图片。
///
/// 非 Windows 平台 / 单元测试里插件不存在，适配器须自行降级而非抛异常。
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
