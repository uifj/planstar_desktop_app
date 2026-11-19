/// ADR-0013 回归：浮层启动期瞬态小 view 的 clamp 不得破坏存储坐标。
///
/// 子窗口以 1920×1080 物理像素创建（150% DPI 下逻辑 1280×720），全屏化
/// （configureOverlay）与原生屏幕尺寸都在其后到达；若 clamp 从「上一次
/// clamp 的结果」出发，存储位置会被瞬态小屏压扁且再也恢复不回来。
library;

import 'dart:convert';
import 'dart:ui' show Size;

import 'package:core/config.dart';
import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/network.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show SizedBox;
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/windows/desktop_widget_app.dart';

final class _FakeDesktop implements DesktopWallpaperGateway {
  final List<List<DesktopCardRect>> regions = <List<DesktopCardRect>>[];

  @override
  Future<bool> configureOverlay({required bool enable}) async => true;

  @override
  Future<bool> setRegion({
    required List<DesktopCardRect> rects,
    bool dragging = false,
  }) async {
    regions.add(rects);
    return true;
  }

  @override
  Future<bool> isOverlay() async => true;

  @override
  Future<bool> attachToDesktop({WindowRect? rect}) async => true;

  @override
  Future<bool> detachFromDesktop() async => true;

  @override
  Future<bool> isAttached() async => false;

  @override
  Future<bool> setWallpaper(String path) async => true;

  @override
  Future<String> currentWallpaper() async => '';

  @override
  Future<DesktopMetrics> desktopMetrics() async =>
      const DesktopMetrics(x: 0, y: 0, width: 2560, height: 1600);
}

void main() {
  testWidgets('启动期小 view clamp 后，全屏尺寸到达仍还原存储坐标', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.5;

    final store = MemoryKeyValueStore(<String, String>{
      desktopCardPositionKey: jsonEncode(<String, Object?>{
        'x': 640.0,
        'y': 16.0,
        'width': 1000.0,
        'height': 1016.0,
      }),
    });
    final desktop = _FakeDesktop();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          domainEventBusProvider.overrideWithValue(DomainEventBus()),
          appConfigProvider.overrideWithValue(AppConfig.empty),
          apiClientProvider.overrideWithValue(
            ApiClient(buildDio(baseUrl: 'https://unit.test/')),
          ),
          desktopWallpaperGatewayProvider.overrideWithValue(desktop),
          loggerProvider.overrideWithValue(
            AppLogger(sinks: <LogSink>[SilentLogSink()], level: LogLevel.debug),
          ),
        ],
        child: const DesktopWidgetApp(),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(desktop.regions, isNotEmpty);
    final rect = desktop.regions.last.first;

    // 先卸载浮层再重置 view：否则 reset 触发的 didChangeMetrics 会落在
    // 已卸载的 State 上，MediaQuery 祖先查找抛异常掩盖主断言结果。
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    expect(rect.x, 640 * 1.5, reason: '存储 x 不得被启动期瞬态小 view 压扁');
    expect(rect.y, 16 * 1.5, reason: '存储 y 不得被启动期瞬态小 view 压扁');
    expect(rect.width, 1000 * 1.5);
    expect(rect.height, 1016 * 1.5);
  });
}
