import 'package:flutter/foundation.dart';

String desktopUpdatePlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows => 'windows',
  TargetPlatform.macOS => 'macos',
  _ => 'windows',
};

String desktopTrayIconAsset(TargetPlatform platform) =>
    platform == TargetPlatform.macOS
    ? 'assets/app_icons/planstar_icon_1024_transparent.png'
    : 'assets/app_icons/tray_icon.ico';

bool desktopWindowShownAfterCreate(TargetPlatform platform) =>
    platform != TargetPlatform.macOS;

bool desktopUsesNativeDataHub(TargetPlatform platform) =>
    platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
