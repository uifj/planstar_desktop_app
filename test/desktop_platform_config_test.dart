import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/infrastructure/desktop_platform_config.dart';

void main() {
  test('更新源按平台选择且保持 Windows 地址不变', () {
    expect(desktopUpdatePlatform(TargetPlatform.windows), 'windows');
    expect(desktopUpdatePlatform(TargetPlatform.macOS), 'macos');
  });

  test('托盘图标按平台选择且保持 Windows ico 不变', () {
    expect(
      desktopTrayIconAsset(TargetPlatform.windows),
      'assets/app_icons/tray_icon.ico',
    );
    expect(
      desktopTrayIconAsset(TargetPlatform.macOS),
      'assets/app_icons/planstar_icon_1024_transparent.png',
    );
  });

  test('仅 macOS 桌面组件由原生 overlay 自行显示', () {
    expect(desktopWindowShownAfterCreate(TargetPlatform.windows), isTrue);
    expect(desktopWindowShownAfterCreate(TargetPlatform.macOS), isFalse);
  });

  test('Windows 与 macOS 均使用原生 DataHub', () {
    expect(desktopUsesNativeDataHub(TargetPlatform.windows), isTrue);
    expect(desktopUsesNativeDataHub(TargetPlatform.macOS), isTrue);
    expect(desktopUsesNativeDataHub(TargetPlatform.linux), isFalse);
  });
}
