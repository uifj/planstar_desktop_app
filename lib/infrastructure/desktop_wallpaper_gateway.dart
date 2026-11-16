/// [DesktopWallpaperGateway] 的 Windows 原生实现。
///
/// 通道由 `windows/runner/desktop_wallpaper_plugin.cpp` **按 engine** 注册：
/// 主窗口与每个 `desktop_multi_window` 子窗口各有自己的一份，因此桌面小组件
/// 可以直接配置自己那个原生窗口。用 `OptionalMethodChannel` 保证非 Windows
/// 平台和单元测试安静降级。
library;

import 'package:core/logger.dart';
import 'package:flutter/services.dart';

import '../core/ports.dart';

final class MethodChannelDesktopWallpaperGateway
    implements DesktopWallpaperGateway {
  MethodChannelDesktopWallpaperGateway({required this.logger})
      : _channel = const OptionalMethodChannel('planstar/desktop_wallpaper');

  final AppLogger logger;
  final OptionalMethodChannel _channel;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      logger.warn('桌面壁纸能力调用失败：$method', error: error);
      return null;
    }
  }

  @override
  Future<bool> configureOverlay({required bool enable}) async =>
      await _invoke<bool>(
        'configureOverlay',
        <String, Object?>{'enable': enable},
      ) ??
      false;

  @override
  Future<bool> setRegion({
    required List<DesktopCardRect> rects,
    bool dragging = false,
  }) async =>
      await _invoke<bool>(
        'setRegion',
        <String, Object?>{
          'dragging': dragging,
          'rects': rects
              .map((DesktopCardRect rect) => rect.toJson())
              .toList(growable: false),
        },
      ) ??
      false;

  @override
  Future<bool> isOverlay() async =>
      await _invoke<bool>('isOverlay') ?? false;

  @override
  Future<bool> attachToDesktop({WindowRect? rect}) async =>
      await _invoke<bool>('attach', rect?.toJson()) ?? false;

  @override
  Future<bool> detachFromDesktop() async =>
      await _invoke<bool>('detach') ?? false;

  @override
  Future<bool> isAttached() async =>
      await _invoke<bool>('isAttached') ?? false;

  @override
  Future<bool> setWallpaper(String path) async =>
      await _invoke<bool>('setWallpaper', <String, Object?>{'path': path}) ??
      false;

  @override
  Future<String> currentWallpaper() async =>
      await _invoke<String>('getWallpaper') ?? '';

  @override
  Future<DesktopMetrics> desktopMetrics() async {
    final raw = await _invoke<dynamic>('desktopMetrics');
    if (raw is! Map) return DesktopMetrics.fallback;
    int read(String key, int fallback) {
      final value = raw[key];
      return value is num ? value.toInt() : fallback;
    }

    return DesktopMetrics(
      x: read('x', 0),
      y: read('y', 0),
      width: read('width', DesktopMetrics.fallback.width),
      height: read('height', DesktopMetrics.fallback.height),
    );
  }
}
