/// 桌面端能力适配器：window_manager / desktop_multi_window /
/// tray_manager / launch_at_startup / audioplayers。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Offset, Rect, Size;

import 'package:audioplayers/audioplayers.dart';
import 'package:core/logger.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
// 三大桌面插件均已基于 nativeapi 重写，统一走各包公开的新 API。
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
// Application（quit）未被上面三个包导出，兜底退出仅此一处退回 nativeapi。
import 'package:nativeapi/nativeapi.dart' as nativeapi;

import '../core/ports.dart';

/// 原生库未加载时（如 widget test 的 Dart VM）符号查找抛 ArgumentError，
/// 与 window_manager / tray_manager legacy 桥的 tryNative 同样降级为 null。
T? _tryNative<T>(T Function() body) {
  try {
    return body();
  } on ArgumentError {
    return null;
  }
}

/// [WindowGateway] 的 window_manager 0.7 新 API 实现。
final class WindowManagerGateway implements WindowGateway {
  WindowManagerGateway({required this.logger});

  final AppLogger logger;

  @override
  void Function()? onCloseIntercepted;

  bool _ready = false;
  bool _preventClose = false;
  bool _destroying = false;
  Window? _window;
  ListenerId? _listenerId;

  /// 平台当前视为「本应用自己的」窗口；首个窗口存在前为 null。
  Window? get _target => _window ??= _tryNative<Window?>(
    () => WindowManager.instance.getCurrent(),
  );

  Future<void> ensureInitialized() async {
    if (_ready || kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    _window ??= _tryNative<Window?>(() => WindowManager.instance.getCurrent());
    _ready = true;
  }

  @override
  Future<void> initializeMainWindow() async {
    await ensureInitialized();
    final window = _target;
    if (!_ready || window == null) return;
    // 右上角 X / Alt+F4 不再直接退出：取消原生关闭请求，改为隐藏到托盘。
    // 托盘菜单里的「退出」会调用 destroy() 绕过拦截。
    _preventClose = true;
    _wireEvents();
    window.titleBarStyle = TitleBarStyle.hidden;
    window.isWindowControlButtonsVisible = true;
    if (window.isFullScreen) window.isFullScreen = false;
    if (window.isMaximized) window.unmaximize();
    if (window.isMinimized) window.restore();
    window.setSize(const Size(1320, 860).toNative(), false);
    _center(window);
    window.minimumSize = const Size(1024, 680).toNative();
    window.isVisibleInTaskbar = true;
    window.title = '企划星 · 桌面日历清单';
    window.show();
    window.focus();
  }

  @override
  Future<void> initializeSubWindow(String title, WindowRect rect) async {
    await ensureInitialized();
    final window = _target;
    if (!_ready || window == null) return;
    window.titleBarStyle = TitleBarStyle.hidden;
    window.isWindowControlButtonsVisible = true;
    window.setSize(Size(rect.width, rect.height).toNative(), false);
    window.minimumSize = const Size(280, 260).toNative();
    window.isVisibleInTaskbar = false;
    window.title = title;
    window.bounds = Rect.fromLTWH(
      rect.x,
      rect.y,
      rect.width,
      rect.height,
    ).toNative();
    window.show();
    window.focus();
  }

  /// 居中到光标所在显示器的工作区（与 legacy 桥的 calcWindowPosition 一致）。
  void _center(Window window) {
    final manager = DisplayManager.instance;
    final cursor = manager.getCursorPosition().toOffset();
    Display? current;
    for (final display in manager.getAll()) {
      final bounds = display.position.toOffset() & display.size.toSize();
      if (bounds.contains(cursor)) {
        current = display;
        break;
      }
    }
    current ??= manager.getPrimary();
    if (current == null) return;
    final workArea = current.workArea.toRect();
    final size = window.size.toSize();
    final position = Offset(
      workArea.left + (workArea.width - size.width) / 2,
      workArea.top + (workArea.height - size.height) / 2,
    );
    window.bounds = (position & size).toNative();
  }

  void _wireEvents() {
    if (_listenerId != null) return;
    final window = _target;
    if (window == null) return;
    _listenerId = _tryNative(() => window.addListener(_onWindowEvent));
  }

  void _onWindowEvent(WindowEvent event) {
    if (event is! WindowCloseRequestedEvent) return;
    if (_destroying) {
      _destroying = false;
      return;
    }
    if (_preventClose) {
      event.request.cancel();
      onCloseIntercepted?.call();
      unawaited(hide());
    }
  }

  @override
  Future<WindowRect> bounds() async {
    if (!_ready) return const WindowRect(100, 100, 1320, 860);
    final rect = _target?.bounds.toRect() ?? Rect.zero;
    return WindowRect(rect.left, rect.top, rect.width, rect.height);
  }

  @override
  Future<void> setBounds(WindowRect rect) async {
    if (!_ready) return;
    _target?.bounds = Rect.fromLTWH(
      rect.x,
      rect.y,
      rect.width,
      rect.height,
    ).toNative();
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    if (_ready) _target?.isAlwaysOnTop = value;
  }

  @override
  Future<void> setOpacity(double value) async {
    if (_ready) _target?.opacity = value.clamp(0.05, 1.0);
  }

  @override
  Future<void> startDragging() async {
    if (_ready) _target?.startDragging();
  }

  @override
  Future<void> show() async {
    if (!_ready) return;
    final window = _target;
    if (window == null) return;
    if (window.isMinimized) window.restore();
    window.show();
  }

  @override
  Future<void> hide() async {
    if (_ready) _target?.hide();
  }

  @override
  Future<void> minimize() async {
    if (_ready) _target?.minimize();
  }

  @override
  Future<void> toggleMaximize() async {
    if (!_ready) return;
    final window = _target;
    if (window == null) return;
    if (window.isMaximized) {
      if (window.isMaximizedVertically) window.setMaximizedVertically(false);
      window.unmaximize();
    } else {
      window.maximize();
    }
  }

  @override
  Future<void> close() async {
    if (!_ready) return;
    final window = _target;
    final closing =
        window != null &&
        (_tryNative(() {
              if (!Window.isCloseSupported()) return false;
              _wireEvents();
              return window.close();
            }) ??
            false);
    if (closing) return;
    // 平台不支持原生关闭时的兜底：与 legacy 桥一致，
    // 拦截态报告并隐藏，否则直接退出应用。
    final destroying = _destroying;
    _destroying = false;
    if (!destroying) {
      onCloseIntercepted?.call();
      if (_preventClose) {
        await hide();
        return;
      }
    }
    _tryNative(() => nativeapi.Application.instance.quit(0));
  }

  @override
  Future<void> destroy() async {
    if (!_ready) return;
    _destroying = true;
    await close();
  }
}

/// [TrayGateway] 的 tray_manager 0.9 新 API 实现。
final class TrayManagerGateway implements TrayGateway {
  TrayManagerGateway({this.logger});

  final AppLogger? logger;
  TrayIcon? _trayIcon;
  Image? _icon;
  Menu? _menu;
  final List<(MenuItem, ListenerId)> _menuItems = [];
  ListenerId? _trayListenerId;

  @override
  Future<void> initialize(void Function(TrayAction action) onAction) async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    final trayIcon = _tryNative(TrayIcon.create);
    if (trayIcon == null) {
      logger?.warn('创建托盘图标失败');
      return;
    }
    _trayIcon = trayIcon;
    trayIcon.setVisible(true);

    // Windows 原生层用 LoadImage(IMAGE_ICON, LR_LOADFROMFILE) 加载图标，
    // 只能识别 .ico；传 PNG 会得到 NULL HICON，托盘图标和右键菜单都不出现。
    try {
      final icon = ImageAsset.fromAsset('assets/app_icons/tray_icon.ico');
      if (icon == null) throw ArgumentError('无法加载托盘图标资源');
      trayIcon.icon = icon;
      _icon?.dispose();
      _icon = icon;
    } catch (error) {
      logger?.warn('设置托盘图标失败', error: error);
    }
    try {
      trayIcon.setTooltip('企划星 · 桌面日历清单');
    } catch (error) {
      logger?.warn('设置托盘提示失败', error: error);
    }

    // 菜单注册独立于图标：即使图标能力降级，右键菜单仍应可用。
    try {
      final menu = Menu.create();
      if (menu == null) throw StateError('无法创建托盘菜单');
      void item(TrayAction action, String label) {
        final menuItem = MenuItem.createWithLabelAndType(
          label,
          MenuItemType.normal,
        );
        if (menuItem == null) return;
        final listenerId = menuItem.addListener((event) {
          if (event is MenuItemClickedEvent) onAction(action);
        });
        menu.addItem(menuItem);
        _menuItems.add((menuItem, listenerId));
      }

      item(TrayAction.show, '显示主窗口');
      item(TrayAction.hide, '隐藏主窗口');
      menu.addSeparator();
      // 桌面日历窗口的两个独立一键项，右键即可明确显示或隐藏。
      item(TrayAction.showDesktopWidget, '显示桌面日历窗口');
      item(TrayAction.hideDesktopWidget, '隐藏桌面日历窗口');
      menu.addSeparator();
      item(TrayAction.sync, '手动同步');
      item(TrayAction.settings, '日历设置');
      // 课程表 / 订阅暂时隐藏：TrayAction 与模块代码保留，仅不放入菜单。
      item(TrayAction.notes, '便签');
      item(TrayAction.refreshWallpaper, '生成静态壁纸快照（可选）');
      menu.addSeparator();
      item(TrayAction.about, '关于');
      // 唯一能真正结束进程的入口。
      item(TrayAction.exit, '退出企划星');

      trayIcon.setContextMenu(menu);
      _menu = menu;
    } catch (error) {
      logger?.warn('设置托盘菜单失败', error: error);
    }

    // Windows 原生层不会自动弹出右键菜单（默认 trigger 为 none），
    // 监听托盘点击后主动弹出，沿用旧版行为（左键 / 右键都弹）。
    _trayListenerId = trayIcon.addListener((event) {
      if (event is TrayIconClickedEvent || event is TrayIconRightClickedEvent) {
        trayIcon.openContextMenu();
      }
    });
  }

  @override
  Future<void> dispose() async {
    if (kIsWeb) return;
    final trayIcon = _trayIcon;
    final trayListenerId = _trayListenerId;
    if (trayIcon != null && trayListenerId != null) {
      trayIcon.removeListener(trayListenerId);
    }
    _trayListenerId = null;
    final menu = _menu;
    final menuItems = List.of(_menuItems);
    _menu = null;
    _menuItems.clear();
    // dispose 可能从菜单项点击回调里被调用（托盘「退出」），
    // 原生项必须活过当前回调，延后一拍释放（与 legacy 桥一致）。
    Timer.run(() {
      for (final (item, listenerId) in menuItems) {
        item.removeListener(listenerId);
        item.dispose();
      }
      menu?.dispose();
    });
    _icon?.dispose();
    _icon = null;
    trayIcon?.dispose();
    _trayIcon = null;
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
  Future<void> showWindow(String windowId) async {
    await WindowController.fromWindowId(windowId).show();
  }

  @override
  Future<void> sendTo(String windowId, MultiWindowCommand command) async {
    await WindowController.fromWindowId(windowId)
        .invokeMethod('command', <String, Object?>{
          'method': command.method,
          'arguments': command.arguments,
        });
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

  /// asset 路径是基础设施细节，只在这里出现（ADR-0003）。
  /// dong 与 ding 同文件是旧版遗留行为，保持不动，待产品确认。
  static const Map<SoundTone, String> _toneAssets = <SoundTone, String>{
    SoundTone.ding: 'audio/audio_ding.mp3',
    SoundTone.ding2: 'audio/audio_ding2.mp3',
    SoundTone.ding3: 'audio/audio_ding3.mp3',
    SoundTone.dong: 'audio/audio_ding.mp3',
    SoundTone.littleStar: 'audio/audio_alarm_littlestar.mp3',
  };

  final AppLogger logger;
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(SoundTone tone) async {
    final asset = _toneAssets[tone];
    if (kIsWeb || asset == null) return;
    try {
      await _player.play(AssetSource(asset));
    } catch (error) {
      logger.warn('提示音播放失败：${tone.name}', error: error);
    }
  }
}
