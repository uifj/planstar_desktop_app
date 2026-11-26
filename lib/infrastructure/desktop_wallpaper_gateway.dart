/// [DesktopWallpaperGateway] 的桌面原生实现（Pigeon）。
///
/// 通道由 Windows / macOS 原生层**按 engine** 注册：
/// 主窗口与每个 `desktop_multi_window` 子窗口各有自己的一份，因此桌面小组件
/// 可以直接配置自己那个原生窗口。契约见 `pigeons/planstar_api.dart`。
///
/// 与旧的手写 `OptionalMethodChannel` 相比：参数/返回值在编译期完成类型校验，
/// 不再有字符串方法名、`Map<String, Object?>` 强转与手工默认值兜底。
/// 非 Windows / macOS / 单元测试下原生未注册，Pigeon 抛 `PlatformException`，
/// 这里统一降级为安全默认值，保持与旧实现一致的「安静失败」语义。
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
