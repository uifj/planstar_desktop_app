/// auto_updater（WinSparkle/Sparkle）适配器：消费服务端 appcast XML，
/// 完成桌面端（Windows/macOS）自更新。
library;

import 'dart:io' show Platform;

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

import '../core/ports.dart';

final class AutoUpdaterGateway implements AppUpdaterGateway {
  bool _configured = false;

  bool get _supported => !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  @override
  Future<void> configure(String feedUrl) async {
    if (_configured || !_supported) return;
    await autoUpdater.setFeedURL(feedUrl);
    // 默认 24h 周期检查；autoCheckUpdate 关闭时由 setAutoCheckEnabled 禁用。
    await autoUpdater.setScheduledCheckInterval(86400);
    _configured = true;
  }

  @override
  Future<void> setAutoCheckEnabled(bool enabled) async {
    if (!_configured || !_supported) return;
    await autoUpdater.setScheduledCheckInterval(enabled ? 86400 : 0);
  }

  @override
  Future<void> checkForUpdates({bool inBackground = false}) async {
    if (!_configured || !_supported) return;
    await autoUpdater.checkForUpdates(inBackground: inBackground);
  }
}
