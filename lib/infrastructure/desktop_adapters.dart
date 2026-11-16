/// 桌面端能力适配器：window_manager / desktop_multi_window /
/// tray_manager / launch_at_startup / audioplayers。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Rect, Size;

import 'package:audioplayers/audioplayers.dart';
import 'package:core/logger.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/ports.dart';

/// [WindowGateway] 的 window_manager 实现。
final class WindowManagerGateway implements WindowGateway {
  WindowManagerGateway({required this.logger});

  final AppLogger logger;

  bool _ready = false;

  Future<void> ensureInitialized() async {
    if (_ready || kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    await windowManager.ensureInitialized();
    _ready = true;
  }

  @override
  Future<void> initializeMainWindow() async {
    await ensureInitialized();
    if (!_ready) return;
    const options = WindowOptions(
      size: Size(1320, 860),
      minimumSize: Size(1024, 680),
      center: true,
      title: '企划星 · 桌面日历清单',
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: false,
    );
    // 不能 await：该调用要等首帧，而在 runApp 之前首帧永远不会到来。
    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  @override
  Future<void> initializeSubWindow(String title, WindowRect rect) async {
    await ensureInitialized();
    if (!_ready) return;
    unawaited(windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: Size(rect.width, rect.height),
        minimumSize: const Size(280, 260),
        title: title,
        titleBarStyle: TitleBarStyle.hidden,
        skipTaskbar: true,
      ),
      () async {
        await windowManager.setBounds(
          Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height),
        );
        await windowManager.show();
        await windowManager.focus();
      },
    ));
  }

  @override
  Future<WindowRect> bounds() async {
    if (!_ready) return const WindowRect(100, 100, 1320, 860);
    final rect = await windowManager.getBounds();
    return WindowRect(
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    );
  }

  @override
  Future<void> setBounds(WindowRect rect) async {
    if (!_ready) return;
    await windowManager.setBounds(
      Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height),
    );
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    if (_ready) await windowManager.setAlwaysOnTop(value);
  }

  @override
  Future<void> setOpacity(double value) async {
    if (_ready) await windowManager.setOpacity(value.clamp(0.05, 1.0));
  }

  @override
  Future<void> startDragging() async {
    if (_ready) await windowManager.startDragging();
  }

  @override
  Future<void> show() async {
    if (_ready) await windowManager.show();
  }

  @override
  Future<void> hide() async {
    if (_ready) await windowManager.hide();
  }

  @override
  Future<void> minimize() async {
    if (_ready) await windowManager.minimize();
  }

  @override
  Future<void> toggleMaximize() async {
    if (!_ready) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() async {
    if (_ready) await windowManager.close();
  }
}

/// [TrayGateway] 的 tray_manager 实现。
final class TrayManagerGateway implements TrayGateway {
  @override
  Future<void> initialize(void Function(TrayAction action) onAction) async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    try {
      await trayManager.setIcon('assets/icons/tray_icon.png');
      await trayManager.setToolTip('企划星 · 桌面日历清单');
      MenuItem item(TrayAction action, String label) => MenuItem(
            key: action.name,
            label: label,
            onClick: (MenuItem _) => onAction(action),
          );
      await trayManager.setContextMenu(
        Menu(
          items: <MenuItem>[
            item(TrayAction.show, '显示日历清单'),
            item(TrayAction.hide, '隐藏日历清单'),
            MenuItem.separator(),
            item(TrayAction.sync, '手动同步'),
            item(TrayAction.settings, '日历设置'),
            item(TrayAction.timetable, '课程表'),
            item(TrayAction.notes, '便签'),
            MenuItem.separator(),
            item(TrayAction.toggleDesktopWidget,
                '显示 / 隐藏桌面可编辑月历'),
            item(TrayAction.refreshWallpaper, '生成静态壁纸快照（可选）'),
            MenuItem.separator(),
            item(TrayAction.about, '关于'),
            item(TrayAction.exit, '退出'),
          ],
        ),
      );
    } catch (error) {
      // 托盘不可用属于能力降级，不影响主流程。
      return;
    }
  }

  @override
  Future<void> dispose() async {
    if (kIsWeb) return;
    try {
      await trayManager.destroy();
    } catch (_) {
      // ignore
    }
  }
}

/// [MultiWindowGateway] 的 desktop_multi_window 实现。
///
/// 0.3.x 的子窗口复用同一个 `main` 入口，原生层会传入
/// `['multi_window', windowId, arguments]`，因此不需要额外 `@pragma` 入口。
final class DesktopMultiWindowGateway implements MultiWindowGateway {
  DesktopMultiWindowGateway({required this.logger});

  final AppLogger logger;
  final StreamController<MultiWindowCommand> _incoming =
      StreamController<MultiWindowCommand>.broadcast();

  @override
  Stream<MultiWindowCommand> get incoming => _incoming.stream;

  /// 在当前 engine 注册窗口专属的指令处理器。
  Future<void> bindCurrentWindow() async {
    if (kIsWeb) return;
    try {
      final controller = await WindowController.fromCurrentEngine();
      await controller.setWindowMethodHandler((call) async {
        if (call.method == 'command') {
          final raw = Map<String, Object?>.from(call.arguments as Map);
          _incoming.add(
            MultiWindowCommand(
              raw['method'] as String? ?? '',
              Map<String, Object?>.from(
                (raw['arguments'] as Map?) ?? const <String, Object?>{},
              ),
            ),
          );
        }
        return true;
      });
    } catch (error) {
      logger.warn('多窗口指令绑定失败', error: error);
    }
  }

  @override
  Future<String> openNoteWindow(String noteId, {WindowRect? rect}) =>
      _create(
        kind: 'note',
        noteId: noteId,
        rect: rect ?? const WindowRect(180, 160, 360, 420),
      );

  @override
  Future<String> openCountdownWindow({WindowRect? rect}) => _create(
        kind: 'countdown',
        noteId: '',
        rect: rect ?? const WindowRect(220, 200, 320, 220),
      );

  @override
  Future<String> openDesktopWidget() => _create(
        kind: 'desktop',
        noteId: '',
        rect: const WindowRect(0, 0, 1920, 1080),
      );

  @override
  Future<void> hideCurrentWindow() async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      await controller.hide();
    } catch (error) {
      logger.warn('隐藏当前窗口失败', error: error);
    }
  }

  Future<String> _create({
    required String kind,
    required String noteId,
    required WindowRect rect,
  }) async {
    final arguments = jsonEncode(<String, Object?>{
      'kind': kind,
      'noteId': noteId,
      'rect': rect.toJson(),
    });
    final controller = await WindowController.create(
      WindowConfiguration(arguments: arguments, hiddenAtLaunch: true),
    );
    await controller.show();
    return controller.windowId;
  }

  @override
  Future<List<String>> openWindowIds() async {
    final all = await WindowController.getAll();
    return all.map((WindowController c) => c.windowId).toList();
  }

  @override
  Future<void> closeWindow(String windowId) async {
    await WindowController.fromWindowId(windowId).hide();
  }

  @override
  Future<void> sendTo(String windowId, MultiWindowCommand command) async {
    await WindowController.fromWindowId(windowId).invokeMethod(
      'command',
      <String, Object?>{
        'method': command.method,
        'arguments': command.arguments,
      },
    );
  }
}

/// [AutoStartGateway] 的 launch_at_startup 实现。
final class LaunchAtStartupGateway implements AutoStartGateway {
  bool _setup = false;

  void _ensureSetup() {
    if (_setup || kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    launchAtStartup.setup(
      appName: '企划星桌面日历清单',
      appPath: Platform.resolvedExecutable,
    );
    _setup = true;
  }

  @override
  Future<bool> isEnabled() async {
    _ensureSetup();
    if (!_setup) return false;
    try {
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _ensureSetup();
    if (!_setup) return;
    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (_) {
      // 注册表被安全软件拦截时保持本地设置，不中断用户操作。
    }
  }
}

/// [SoundGateway] 的 audioplayers 实现，音效复用归档里的 4 个 mp3。
final class AudioPlayersSoundGateway implements SoundGateway {
  AudioPlayersSoundGateway({required this.logger});

  final AppLogger logger;
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(SoundTone tone) async {
    if (kIsWeb || tone.asset == null) return;
    try {
      await _player.play(AssetSource(tone.asset!));
    } catch (error) {
      logger.warn('提示音播放失败：${tone.name}', error: error);
    }
  }
}
