/// 壁纸应用服务：底图选择 → 离屏渲染月历 → 落盘 → 通知 Windows 换壁纸。
///
/// 这是「设置 → 原生桌面」这条链路的用例实现，DesktopController 只负责
/// 触发与定时，不直接碰 `dart:ui` / 文件 / 插件。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../calendar/application/calendar_controllers.dart';
import '../../settings/domain/app_settings.dart';
import 'wallpaper_renderer.dart';

final wallpaperServiceProvider = Provider<WallpaperService>((Ref ref) {
  return WallpaperService(
    desktop: ref.watch(desktopWallpaperGatewayProvider),
    images: ref.watch(wallpaperImageGatewayProvider),
    logger: ref.watch(loggerProvider).child('wallpaper'),
  );
});

final class WallpaperRefreshResult {
  const WallpaperRefreshResult({
    required this.success,
    required this.path,
    this.message,
  });

  final bool success;
  final String path;
  final String? message;
}

final class WallpaperService {
  const WallpaperService({
    required this.desktop,
    required this.images,
    required this.logger,
    this.renderer = const WallpaperRenderer(),
  });

  final DesktopWallpaperGateway desktop;
  final WallpaperImageGateway images;
  final AppLogger logger;
  final WallpaperRenderer renderer;

  /// 重新生成并应用壁纸。
  Future<WallpaperRefreshResult> refresh({
    required MonthData month,
    required AppSettings settings,
    required DateKey today,
    required DateTime now,
  }) async {
    try {
      await _captureOriginal();
      final metrics = await desktop.desktopMetrics();
      final ui.Image? background = await _background(settings, now);
      try {
        final bytes = await renderer.render(
          metrics: metrics,
          month: month,
          settings: settings,
          today: today,
          background: background,
        );
        final path = await images.savePng(bytes);
        final applied = await desktop.setWallpaper(path);
        return WallpaperRefreshResult(
          success: applied,
          path: path,
          message: applied ? '桌面壁纸已更新' : '系统拒绝设置壁纸',
        );
      } finally {
        background?.dispose();
      }
    } catch (error) {
      logger.warn('生成桌面壁纸失败', error: error);
      return const WallpaperRefreshResult(
        success: false,
        path: '',
        message: '生成桌面壁纸失败',
      );
    }
  }

  /// 首次应用前记住用户原本的壁纸，供关闭功能 / 卸载时恢复。
  Future<void> _captureOriginal() async {
    final saved = await images.readOriginalWallpaper();
    if (saved.isNotEmpty) return;
    final current = await desktop.currentWallpaper();
    final generated = await images.outputPath;
    if (current.isEmpty || _samePath(current, generated)) return;
    await images.writeOriginalWallpaper(current);
  }

  Future<ui.Image?> _background(
    AppSettings settings,
    DateTime now,
  ) async {
    switch (settings.wallpaperMode) {
      case WallpaperMode.solidColor:
        return null;
      case WallpaperMode.desktopCapture:
        var path = await images.readOriginalWallpaper();
        if (path.isEmpty) {
          final current = await desktop.currentWallpaper();
          final generated = await images.outputPath;
          if (current.isEmpty || _samePath(current, generated)) return null;
          path = current;
          await images.writeOriginalWallpaper(path);
        }
        return _decode(await images.readImage(path));
      case WallpaperMode.rotation:
        if (settings.wallpaperImageDirectory.isEmpty) return null;
        final files = await images.listImages(
          settings.wallpaperImageDirectory,
        );
        if (files.isEmpty) return null;
        final slot = now.millisecondsSinceEpoch ~/
            (settings.wallpaperIntervalMinutes.clamp(1, 720) * 60000);
        final path = settings.wallpaperShowAll
            ? files[slot % files.length]
            : files.first;
        return _decode(await images.readImage(path));
    }
  }

  Future<ui.Image?> _decode(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (error) {
      logger.warn('壁纸底图解码失败', error: error);
      return null;
    }
  }

  bool _samePath(String a, String b) =>
      a.replaceAll('\\', '/').toLowerCase() ==
      b.replaceAll('\\', '/').toLowerCase();
}
