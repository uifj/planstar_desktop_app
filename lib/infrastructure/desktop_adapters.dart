/// 桌面端能力适配器：window_manager / desktop_multi_window /
/// tray_manager / launch_at_startup / audioplayers。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:core/logger.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/ports.dart';
import 'desktop_platform_config.dart';
import 'pigeon/planstar_api.g.dart';

/// [WindowGateway] 的 window_manager 实现。
final class WindowManagerGateway with WindowListener implements WindowGateway {
  WindowManagerGateway({required this.logger});

  final AppLogger logger;

  @override
  void Function()? onCloseIntercepted;

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
    // 右上角 X / Alt+F4 不再直接退出：拦截原生关闭信号，改为隐藏到托盘。
    // 托盘菜单里的「退出」会调用 destroy() 绕过拦截。
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
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
    unawaited(
      windowManager.waitUntilReadyToShow(
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
      ),
    );
  }

  @override
  Future<WindowRect> bounds() async {
    if (!_ready) return const WindowRect(100, 100, 1320, 860);
    final rect = await windowManager.getBounds();
    return WindowRect(rect.left, rect.top, rect.width, rect.height);
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

  @override
  Future<void> destroy() async {
    if (_ready) await windowManager.destroy();
  }

  /// window_manager 的关闭拦截回调：只隐藏，托盘「退出」才真正结束进程。
  @override
  void onWindowClose() {
    onCloseIntercepted?.call();
    unawaited(hide());
  }
}

/// tray_manager 0.5.3 有两个必须自己补的行为：
/// 1. `_methodCallHandler` 把菜单点击的 `onClick` 分发放在 `_listeners`
///    循环**内部**，不注册 listener 时菜单项点击永远到不了 Dart；
/// 2. Windows 原生层不会自动弹出右键菜单（`TrackPopupMenu` 只在
///    `popUpContextMenu` 里调用），必须监听托盘点击事件后主动弹出。
final class _TrayEventSink with TrayListener {
  @override
  void onTrayIconMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }
}

/// [TrayGateway] 的 tray_manager 实现。
final class TrayManagerGateway implements TrayGateway {
  TrayManagerGateway({this.logger});

  final AppLogger? logger;
  TrayListener? _listener;

  @override
  Future<void> initialize(void Function(TrayAction action) onAction) async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    final listener = _TrayEventSink();
    _listener = listener;
    trayManager.addListener(listener);

    // Windows 原生层用 LoadImage(IMAGE_ICON, LR_LOADFROMFILE) 加载图标，
    // 只能识别 .ico；传 PNG 会得到 NULL HICON，托盘图标和右键菜单都不出现。
    try {
      await trayManager.setIcon(desktopTrayIconAsset(defaultTargetPlatform));
    } catch (error) {
      logger?.warn('设置托盘图标失败', error: error);
    }
    try {
      await trayManager.setToolTip('企划星 · 桌面日历清单');
    } catch (error) {
      logger?.warn('设置托盘提示失败', error: error);
    }

    MenuItem item(TrayAction action, String label) => MenuItem(
      key: action.name,
      label: label,
      onClick: (MenuItem _) => onAction(action),
    );
    // 菜单注册独立于图标：即使图标能力降级，右键菜单仍应可用。
    try {
      await trayManager.setContextMenu(
        Menu(
          items: <MenuItem>[
            item(TrayAction.show, '显示主窗口'),
            item(TrayAction.hide, '隐藏主窗口'),
            MenuItem.separator(),
            // 桌面日历窗口的两个独立一键项，右键即可明确显示或隐藏。
            item(TrayAction.showDesktopWidget, '显示桌面日历窗口'),
            item(TrayAction.hideDesktopWidget, '隐藏桌面日历窗口'),
            MenuItem.separator(),
            item(TrayAction.sync, '手动同步'),
            item(TrayAction.settings, '日历设置'),
            // 课程表 / 订阅暂时隐藏：TrayAction 与模块代码保留，仅不放入菜单。
            item(TrayAction.notes, '便签'),
            item(TrayAction.refreshWallpaper, '生成静态壁纸快照（可选）'),
            MenuItem.separator(),
            item(TrayAction.about, '关于'),
            // 唯一能真正结束进程的入口。
            item(TrayAction.exit, '退出企划星'),
          ],
        ),
      );
    } catch (error) {
      logger?.warn('设置托盘菜单失败', error: error);
    }
  }

  @override
  Future<void> dispose() async {
    if (kIsWeb) return;
    final listener = _listener;
    if (listener != null) {
      trayManager.removeListener(listener);
      _listener = null;
    }
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
  Future<String> openNoteWindow(String noteId, {WindowRect? rect}) => _create(
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
    if (kind != 'desktop' ||
        desktopWindowShownAfterCreate(defaultTargetPlatform)) {
      await controller.show();
    }
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
  Future<void> showWindow(String windowId) async {
    await WindowController.fromWindowId(windowId).show();
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

/// [AutoStartGateway] 的桌面端实现。
///
/// macOS 使用 Pigeon 类型化桥；Windows/Linux 继续使用 launch_at_startup 包。
final class LaunchAtStartupGateway implements AutoStartGateway {
  LaunchAtStartupGateway({BinaryMessenger? binaryMessenger})
    : _hostApi = LaunchAtStartupHostApi(binaryMessenger: binaryMessenger);

  final LaunchAtStartupHostApi _hostApi;
  bool _packageSetup = false;

  bool get _supported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  void _ensurePackageSetup() {
    if (_packageSetup || !_supported || Platform.isMacOS) return;
    launchAtStartup.setup(
      appName: '企划星桌面日历清单',
      appPath: Platform.resolvedExecutable,
    );
    _packageSetup = true;
  }

  @override
  Future<bool> isEnabled() async {
    if (!_supported) return false;
    try {
      if (Platform.isMacOS) return await _hostApi.isEnabled();
      _ensurePackageSetup();
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!_supported) return;
    try {
      if (Platform.isMacOS) {
        await _hostApi.setEnabled(enabled);
      } else {
        _ensurePackageSetup();
        if (enabled) {
          await launchAtStartup.enable();
        } else {
          await launchAtStartup.disable();
        }
      }
    } catch (_) {
      // 系统安全策略拦截时保持本地设置，不中断用户操作。
    }
  }
}

/// [SoundGateway] 的 audioplayers 实现，音效复用归档里的 4 个 mp3。
final class AudioPlayersSoundGateway implements SoundGateway {
  AudioPlayersSoundGateway({required this.logger});

  final AppLogger logger;
  // 懒创建：启动阶段没有任何提示音，提前构造会白白初始化一次音频插件。
  AudioPlayer? _player;

  @override
  Future<void> play(SoundTone tone) async {
    if (kIsWeb || tone.asset == null) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.play(AssetSource(tone.asset!));
    } catch (error) {
      logger.warn('提示音播放失败：${tone.name}', error: error);
    }
  }
}

/// [ScreenGateway] 的 screen_retriever 实现。
///
/// `getAllDisplays` 返回的是**逻辑像素**（插件已在原生层按每显示器 DPI
/// 折算），桌面小组件直接用即可，无需像 `DesktopMetrics` 那样再除 dpr。
final class ScreenRetrieverGateway implements ScreenGateway {
  ScreenRetrieverGateway({this.logger});

  final AppLogger? logger;

  Future<List<ScreenDisplay>> _displays() async {
    final displays = await screenRetriever.getAllDisplays();
    return displays
        .map((Display d) {
          final size = d.visibleSize ?? d.size;
          final position = d.visiblePosition;
          return ScreenDisplay(
            id: d.id,
            x: position?.dx ?? 0,
            y: position?.dy ?? 0,
            width: size.width,
            height: size.height,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<ScreenDisplay?> virtualBounds() async {
    try {
      final displays = await _displays();
      if (displays.isEmpty) return null;
      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = double.negativeInfinity;
      var maxY = double.negativeInfinity;
      for (final d in displays) {
        if (d.x < minX) minX = d.x;
        if (d.y < minY) minY = d.y;
        if (d.x + d.width > maxX) maxX = d.x + d.width;
        if (d.y + d.height > maxY) maxY = d.y + d.height;
      }
      return ScreenDisplay(
        id: 'virtual',
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY,
      );
    } catch (error) {
      logger?.warn('枚举显示器失败', error: error);
      return null;
    }
  }
}

/// [HotkeyGateway] 的 hotkey_manager 实现。
///
/// 全部注册为 `HotKeyScope.system`（系统级）：即使主窗口未聚焦 / 在托盘里，
/// 也能用 `Ctrl+Alt+H` 显示主窗口、`Ctrl+Alt+D` 切换桌面小组件。
final class HotkeyManagerGateway implements HotkeyGateway {
  HotkeyManagerGateway({this.logger});

  final AppLogger? logger;

  @override
  Future<void> initialize(void Function(HotkeyAction action) onAction) async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {
      // 首次启动没有已注册热键，忽略。
    }
    await _register(
      onAction,
      action: HotkeyAction.toggleMainWindow,
      key: PhysicalKeyboardKey.keyH,
    );
    await _register(
      onAction,
      action: HotkeyAction.toggleDesktopWidget,
      key: PhysicalKeyboardKey.keyD,
    );
  }

  Future<void> _register(
    void Function(HotkeyAction action) onAction, {
    required HotkeyAction action,
    required PhysicalKeyboardKey key,
  }) async {
    final hotKey = HotKey(
      key: key,
      modifiers: const <HotKeyModifier>[
        HotKeyModifier.control,
        HotKeyModifier.alt,
      ],
      scope: HotKeyScope.system,
    );
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => onAction(action),
      );
    } catch (error) {
      logger?.warn('注册全局热键失败：${hotKey.debugName}', error: error);
    }
  }

  @override
  Future<void> dispose() async {
    if (kIsWeb) return;
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {
      // ignore
    }
  }
}
