/// 桌面能力控制器：托盘动作、窗口透明度 / 置顶、开机自启、多窗口，
/// 以及「贴到桌面上的可编辑月历小组件」的生命周期。
///
/// 桌面小组件走 Vectra 式方案：独立透明 overlay 窗口，不是静态壁纸。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../calendar/application/calendar_controllers.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/app_settings.dart';
import 'wallpaper_service.dart';

final class DesktopState {
  const DesktopState({
    this.message,
    this.visible = true,
    this.widgetActive = false,
    this.wallpaperApplied = false,
    this.wallpaperPath = '',
  });

  final String? message;
  final bool visible;
  final bool widgetActive;
  final bool wallpaperApplied;
  final String wallpaperPath;

  DesktopState copyWith({
    String? message,
    bool? visible,
    bool? widgetActive,
    bool? wallpaperApplied,
    String? wallpaperPath,
  }) =>
      DesktopState(
        message: message ?? this.message,
        visible: visible ?? this.visible,
        widgetActive: widgetActive ?? this.widgetActive,
        wallpaperApplied: wallpaperApplied ?? this.wallpaperApplied,
        wallpaperPath: wallpaperPath ?? this.wallpaperPath,
      );
}

final desktopControllerProvider =
    NotifierProvider<DesktopController, DesktopState>(DesktopController.new);

final class DesktopController extends Notifier<DesktopState> {
  Timer? _wallpaperTimer;
  Timer? _refreshDebounce;
  final List<String> _widgetWindowIds = <String>[];
  bool _openingWidget = false;
  bool _wallpaperRestored = false;
  String _appliedSignature = '';

  @override
  DesktopState build() {
    ref.read(trayActionsProvider).listen(_onTrayAction);
    ref.read(domainEventBusProvider).on<SettingsChanged>(_onSettingsChanged);
    ref.listen<AppSettings>(
      settingsControllerProvider,
      (AppSettings? previous, AppSettings next) {
        if (previous != next) applySettings();
      },
    );
    ref.listen<MonthData>(
      monthDataProvider,
      (MonthData? previous, MonthData next) {
        if (ref.read(settingsControllerProvider).wallpaperAutoRender) {
          _scheduleRefresh();
        }
      },
    );
    ref
        .read(multiWindowGatewayProvider)
        .incoming
        .listen(_onWindowCommand);
    ref.onDispose(() {
      _wallpaperTimer?.cancel();
      _refreshDebounce?.cancel();
    });
    Future.microtask(applySettings);
    return const DesktopState();
  }

  Future<void> _onSettingsChanged(SettingsChanged event) => applySettings();

  Future<void> applySettings() async {
    final settings = ref.read(settingsControllerProvider);
    final window = ref.read(windowGatewayProvider);
    await window.setOpacity(settings.calendarTransparency);
    await ref
        .read(autoStartGatewayProvider)
        .setEnabled(settings.startWithWindow);

    await _syncDesktopWidget(settings.desktopWidgetEnabled);

    // 旧版曾把月历画成系统壁纸；现在默认关闭，并把原壁纸还回去。
    if (!settings.wallpaperAutoRender && !_wallpaperRestored) {
      _wallpaperRestored = true;
      await restoreSystemWallpaper();
    }

    final signature = '${settings.wallpaperAutoRender}|'
        '${settings.wallpaperIntervalMinutes}';
    if (signature != _appliedSignature) {
      _appliedSignature = signature;
      _wallpaperTimer?.cancel();
      if (settings.wallpaperAutoRender) {
        _wallpaperTimer = Timer.periodic(
          Duration(
            minutes: settings.wallpaperIntervalMinutes.clamp(1, 720),
          ),
          (_) => _refreshWallpaper(),
        );
        _scheduleRefresh();
      }
    }
  }

  Future<void> _syncDesktopWidget(bool enabled) async {
    final multiWindow = ref.read(multiWindowGatewayProvider);
    if (enabled) {
      // applySettings 会在首帧微任务、设置加载、跨 engine 同步时并发触发，
      // 必须防重入，否则会开出多个互相重叠的 overlay 窗口。
      if (_openingWidget || _widgetWindowIds.isNotEmpty) return;
      _openingWidget = true;
      try {
        final id = await multiWindow.openDesktopWidget();
        _widgetWindowIds.add(id);
        state = state.copyWith(
          widgetActive: true,
          message: '桌面可编辑月历已显示',
        );
      } catch (error) {
        state = state.copyWith(
          widgetActive: false,
          message: '桌面小组件启动失败：$error',
        );
      } finally {
        _openingWidget = false;
      }
      return;
    }
    final ids = List<String>.from(_widgetWindowIds);
    _widgetWindowIds.clear();
    for (final id in ids) {
      await multiWindow.closeWindow(id);
    }
    state = state.copyWith(
      widgetActive: false,
      message: '桌面可编辑月历已隐藏',
    );
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 1200),
      _refreshWallpaper,
    );
  }

  Future<void> _refreshWallpaper() async {
    final settings = ref.read(settingsControllerProvider);
    if (!settings.wallpaperAutoRender) return;
    final result = await ref.read(wallpaperServiceProvider).refresh(
          month: ref.read(monthDataProvider),
          settings: settings,
          today: DateKey.today(ref.read(clockProvider).now()),
          now: ref.read(clockProvider).now(),
        );
    state = state.copyWith(
      wallpaperApplied: result.success,
      wallpaperPath: result.path,
      message: result.message,
    );
  }

  /// 可选的静态快照模式；默认不启用，桌面主路径是可编辑小组件。
  Future<void> refreshWallpaper() => _refreshWallpaper();

  Future<void> restoreSystemWallpaper() async {
    final original = await ref
        .read(wallpaperImageGatewayProvider)
        .readOriginalWallpaper();
    if (original.isEmpty) return;
    final ok = await ref
        .read(desktopWallpaperGatewayProvider)
        .setWallpaper(original);
    state = state.copyWith(
      wallpaperApplied: false,
      message: ok ? '已恢复系统原壁纸' : null,
    );
  }

  Future<void> toggleDesktopWidget() async {
    final current = ref.read(settingsControllerProvider).desktopWidgetEnabled;
    await ref.read(settingsControllerProvider.notifier).update(
          (AppSettings s) => s.copyWith(desktopWidgetEnabled: !current),
        );
  }

  void _onTrayAction(TrayAction action) {
    switch (action) {
      case TrayAction.show:
        show();
      case TrayAction.hide:
        hide();
      case TrayAction.toggle:
        state.visible ? hide() : show();
      case TrayAction.sync:
        state = state.copyWith(message: '托盘：手动同步');
      case TrayAction.settings:
      case TrayAction.timetable:
      case TrayAction.notes:
        state = state.copyWith(message: '托盘：${action.name}');
      case TrayAction.embedDesktop:
      case TrayAction.toggleDesktopWidget:
        toggleDesktopWidget();
      case TrayAction.refreshWallpaper:
        refreshWallpaper();
      case TrayAction.about:
        state = state.copyWith(message: '企划星 · 桌面日历清单');
      case TrayAction.exit:
        close();
    }
  }

  void _onWindowCommand(MultiWindowCommand command) {
    state = state.copyWith(message: '子窗口指令：${command.method}');
  }

  /// 页面统一写入的轻量提示消息。
  void notify(String message) => state = state.copyWith(message: message);

  void show() {
    ref.read(windowGatewayProvider).show();
    state = state.copyWith(visible: true);
  }

  void hide() {
    ref.read(windowGatewayProvider).hide();
    state = state.copyWith(visible: false);
  }

  void close() => ref.read(windowGatewayProvider).close();

  Future<void> openNoteWindow(String noteId) => ref
      .read(multiWindowGatewayProvider)
      .openNoteWindow(noteId)
      .then<void>((_) {});

  Future<void> openCountdownWindow() => ref
      .read(multiWindowGatewayProvider)
      .openCountdownWindow()
      .then<void>((_) {});
}
