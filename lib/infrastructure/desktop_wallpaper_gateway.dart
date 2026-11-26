/// Pigeon 桌面覆盖层网关。
///
/// 通道由 Windows / macOS 原生层按 engine 注册：主窗口与每个
/// `desktop_multi_window` 子窗口只配置自己的原生窗口。
/// 非桌面平台或单元测试未注册原生能力时，将缺失与平台错误降级为安全默认值。
library;

import 'package:core/logger.dart';
import 'package:flutter/services.dart';

import '../core/ports.dart';
import 'pigeon/planstar_api.g.dart';

final class PigeonDesktopWallpaperGateway implements DesktopWallpaperGateway {
  PigeonDesktopWallpaperGateway({required this.logger})
    : _api = DesktopWallpaperHostApi();

  final AppLogger logger;
  final DesktopWallpaperHostApi _api;

  Future<T?> _invoke<T>(String label, Future<T> Function() action) async {
    try {
      return await action();
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      logger.warn('桌面壁纸能力调用失败：$label', error: error);
      return null;
    }
  }

  @override
  Future<bool> configureOverlay({required bool enable}) async =>
      await _invoke('configureOverlay', () => _api.configureOverlay(enable)) ??
      false;

  @override
  Future<bool> setRegion({
    required List<DesktopCardRect> rects,
    bool dragging = false,
  }) async =>
      await _invoke(
        'setRegion',
        () => _api.setRegion(
          rects
              .map(
                (DesktopCardRect rect) => CardRectDto(
                  x: rect.x.roundToDouble(),
                  y: rect.y.roundToDouble(),
                  width: rect.width.roundToDouble(),
                  height: rect.height.roundToDouble(),
                  radius: rect.radius.roundToDouble(),
                ),
              )
              .toList(growable: false),
          dragging,
        ),
      ) ??
      false;

  @override
  Future<bool> isOverlay() async =>
      await _invoke('isOverlay', _api.isOverlay) ?? false;

  @override
  Future<bool> attachToDesktop({WindowRect? rect}) async =>
      await _invoke(
        'attach',
        () => _api.attach(
          rect == null
              ? null
              : WindowRectDto(
                  x: rect.x,
                  y: rect.y,
                  width: rect.width,
                  height: rect.height,
                ),
        ),
      ) ??
      false;

  @override
  Future<bool> detachFromDesktop() async =>
      await _invoke('detach', _api.detach) ?? false;

  @override
  Future<bool> isAttached() async =>
      await _invoke('isAttached', _api.isAttached) ?? false;

  @override
  Future<bool> setWallpaper(String path) async =>
      await _invoke('setWallpaper', () => _api.setWallpaper(path)) ?? false;

  @override
  Future<String> currentWallpaper() async =>
      await _invoke('currentWallpaper', _api.currentWallpaper) ?? '';

  @override
  Future<DesktopMetrics> desktopMetrics() async {
    final metrics = await _invoke('desktopMetrics', _api.desktopMetrics);
    if (metrics == null) return DesktopMetrics.fallback;
    return DesktopMetrics(
      x: metrics.x,
      y: metrics.y,
      width: metrics.width,
      height: metrics.height,
    );
  }
}
