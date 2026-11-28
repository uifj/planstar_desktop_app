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
import '../../../l10n/l10n.dart';
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
    bool clearMessage = false,
  }) => DesktopState(
    message: clearMessage ? null : (message ?? this.message),
    visible: visible ?? this.visible,
    widgetActive: widgetActive ?? this.widgetActive,
    wallpaperApplied: wallpaperApplied ?? this.wallpaperApplied,
    wallpaperPath: wallpaperPath ?? this.wallpaperPath,
  );
}

final desktopControllerProvider =
    NotifierProvider<DesktopController, DesktopState>(DesktopController.new);

final class DesktopController extends Notifier<DesktopState> {
  AppLocalizations get _l10n =>
      ref.read(appLocalizationScopeProvider).localizations;
  Timer? _wallpaperTimer;
  Timer? _refreshDebounce;
  final List<String> _widgetWindowIds = <String>[];
  bool _openingWidget = false;
  bool _wallpaperRestored = false;
  String _appliedSignature = '';
  StreamSubscription<TrayAction>? _traySubscription;
  StreamSubscription<HotkeyAction>? _hotkeySubscription;
  StreamSubscription<MultiWindowCommand>? _windowCommands;
  void Function()? _cancelSettingsChanged;

  @override
  DesktopState build() {
    // 仅由应用根 ref.read，需保活以持续接收托盘 / 领域事件。
    ref.keepAlive();
    // 标题栏 X / Alt+F4 由 window_manager 拦截后直接 hide，
    // 必须回写 visible，否则托盘 toggle 的第一次点击方向是反的。
    final window = ref.read(windowGatewayProvider);
    window.onCloseIntercepted = markHidden;
    final localizationScope = ref.read(appLocalizationScopeProvider);
    localizationScope.addListener(_onLocaleChanged);
    _traySubscription = ref.read(trayActionsProvider).listen(_onTrayAction);
    _hotkeySubscription = ref
        .read(hotkeyActionsProvider)
        .listen(_onHotkeyAction);
    _cancelSettingsChanged = ref
        .read(domainEventBusProvider)
        .on<SettingsChanged>(_onSettingsChanged);
    ref.listen<AppSettings>(settingsControllerProvider, (
      AppSettings? previous,
      AppSettings next,
    ) {
      if (previous != next) applySettings();
    });
    ref.listen<MonthData>(monthDataProvider, (
      MonthData? previous,
      MonthData next,
    ) {
      if (ref.read(settingsControllerProvider).wallpaperAutoRender) {
        _scheduleRefresh();
      }
    });
    _windowCommands = ref
        .read(multiWindowGatewayProvider)
        .incoming
        .listen(_onWindowCommand);
    ref.onDispose(() {
      _wallpaperTimer?.cancel();
      _refreshDebounce?.cancel();
      _traySubscription?.cancel();
      _hotkeySubscription?.cancel();
      _windowCommands?.cancel();
      _cancelSettingsChanged?.call();
      localizationScope.removeListener(_onLocaleChanged);
      window.onCloseIntercepted = null;
    });
    Future.microtask(applySettings);
    return const DesktopState();
  }

  void _onLocaleChanged() {
    if (state.message != null) state = state.copyWith(clearMessage: true);
    if (ref.read(settingsControllerProvider).wallpaperAutoRender) {
      _scheduleRefresh();
    }
  }

  Future<void> _onSettingsChanged(SettingsChanged event) => applySettings();

  Future<void> applySettings() async {
    final settings = ref.read(settingsControllerProvider);
    final window = ref.read(windowGatewayProvider);
    await window.setOpacity(settings.calendarTransparency);
    await ref
        .read(autoStartGatewayProvider)
        .setEnabled(settings.startWithWindow);
    await ref
        .read(appUpdaterGatewayProvider)
        .setAutoCheckEnabled(settings.autoCheckUpdate);

    await _syncDesktopWidget(settings.desktopWidgetEnabled);

    // 旧版曾把月历画成系统壁纸；现在默认关闭，并把原壁纸还回去。
    if (!settings.wallpaperAutoRender && !_wallpaperRestored) {
      _wallpaperRestored = true;
      await restoreSystemWallpaper();
    }

    final signature =
        '${settings.wallpaperAutoRender}|'
        '${settings.wallpaperIntervalMinutes}';
    if (signature != _appliedSignature) {
      _appliedSignature = signature;
      _wallpaperTimer?.cancel();
      if (settings.wallpaperAutoRender) {
        _wallpaperTimer = Timer.periodic(
          Duration(minutes: settings.wallpaperIntervalMinutes.clamp(1, 720)),
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
      if (_openingWidget) return;
      _openingWidget = true;
      try {
        if (_widgetWindowIds.isNotEmpty) {
          // 复用已隐藏的窗口：hide 并不销毁 engine，若每次都新建会累积
          // 多份 DataHub 订阅与存储镜像。
          var shown = false;
          for (final id in List<String>.from(_widgetWindowIds)) {
            try {
              await multiWindow.showWindow(id);
              shown = true;
            } catch (_) {
              _widgetWindowIds.remove(id);
            }
          }
          if (shown) {
            state = state.copyWith(
              widgetActive: true,
              message: _l10n.desktopWidgetShown,
            );
            return;
          }
        }
        final id = await multiWindow.openDesktopWidget();
        _widgetWindowIds.add(id);
        state = state.copyWith(
          widgetActive: true,
          message: _l10n.desktopWidgetShown,
        );
      } catch (error, stackTrace) {
        ref
            .read(loggerProvider)
            .warn('切换桌面小组件失败', error: error, stackTrace: stackTrace);
        state = state.copyWith(
          widgetActive: false,
          message: _l10n.desktopWidgetFailed(caughtErrorLabel(error, _l10n)),
        );
      } finally {
        _openingWidget = false;
      }
      return;
    }
    for (final id in List<String>.from(_widgetWindowIds)) {
      await multiWindow.closeWindow(id);
    }
    // 保留 id，下次显示时复用同一个 engine。
    state = state.copyWith(
      widgetActive: false,
      message: _l10n.desktopWidgetHidden,
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
    final locale = ref.read(appLocalizationScopeProvider).value;
    final result = await ref
        .read(wallpaperServiceProvider)
        .refresh(
          month: ref.read(monthDataProvider),
          settings: settings,
          today: DateKey.today(ref.read(clockProvider).now()),
          now: ref.read(clockProvider).now(),
        );
    if (locale != ref.read(appLocalizationScopeProvider).value) return;
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
      message: ok ? _l10n.wallpaperRestored : null,
    );
  }

  /// 托盘右键的一键显示 / 隐藏：改写设置项后由 applySettings 驱动窗口显隐。
  Future<void> setDesktopWidgetEnabled(bool enabled) async {
    final current = ref.read(settingsControllerProvider).desktopWidgetEnabled;
    await ref
        .read(settingsControllerProvider.notifier)
        .update((AppSettings s) => s.copyWith(desktopWidgetEnabled: enabled));
    // 值相同的时候 update 会短路、不触发 applySettings；但窗口可能已被
    // 子窗口的「收起桌面组件」按钮隐藏，此时必须主动补偿一次同步，
    // 否则托盘「显示桌面日历窗口」点了没反应。
    if (current == enabled) {
      await _syncDesktopWidget(enabled);
    }
  }

  Future<void> toggleDesktopWidget() async {
    final current = ref.read(settingsControllerProvider).desktopWidgetEnabled;
    await setDesktopWidgetEnabled(!current);
  }

  void _onHotkeyAction(HotkeyAction action) {
    switch (action) {
      case HotkeyAction.toggleMainWindow:
        state.visible ? hide() : show();
      case HotkeyAction.toggleDesktopWidget:
        toggleDesktopWidget();
    }
  }

  void _onTrayAction(TrayAction action) {
    switch (action) {
      case TrayAction.show:
        show();
      case TrayAction.hide:
        hide();
      case TrayAction.sync:
        state = state.copyWith(message: _l10n.traySync);
      case TrayAction.settings:
      case TrayAction.timetable:
      case TrayAction.notes:
        state = state.copyWith(
          message: switch (action) {
            TrayAction.settings => _l10n.traySettings,
            TrayAction.timetable => _l10n.timetableTitle,
            TrayAction.notes => _l10n.trayNotes,
            _ => action.name,
          },
        );
      case TrayAction.embedDesktop:
      case TrayAction.toggleDesktopWidget:
        toggleDesktopWidget();
      case TrayAction.showDesktopWidget:
        setDesktopWidgetEnabled(true);
      case TrayAction.hideDesktopWidget:
        setDesktopWidgetEnabled(false);
      case TrayAction.refreshWallpaper:
        refreshWallpaper();
      case TrayAction.about:
        state = state.copyWith(message: _l10n.appTitle);
      case TrayAction.exit:
        destroy();
    }
  }

  void _onWindowCommand(MultiWindowCommand command) {
    state = state.copyWith(message: _l10n.subWindowCommand(command.method));
  }

  /// 页面统一写入的轻量提示消息。
  void notify(String message) => state = state.copyWith(message: message);

  void show() {
    ref.read(windowGatewayProvider).show();
    state = state.copyWith(visible: true);
  }

  /// 主窗口已被原生层隐藏（X / Alt+F4），只同步状态不再重复调用 hide。
  void markHidden() {
    if (state.visible) state = state.copyWith(visible: false);
  }

  void hide() {
    ref.read(windowGatewayProvider).hide();
    markHidden();
  }

  /// 请求关闭主窗口：因已开启关闭拦截，实际会隐藏到托盘。
  void close() => ref.read(windowGatewayProvider).close();

  /// 托盘「退出」专用：绕过关闭拦截强制结束进程。
  void destroy() => ref.read(windowGatewayProvider).destroy();

  Future<void> openNoteWindow(String noteId) => ref
      .read(multiWindowGatewayProvider)
      .openNoteWindow(noteId)
      .then<void>((_) {});

  Future<void> openCountdownWindow() => ref
      .read(multiWindowGatewayProvider)
      .openCountdownWindow()
      .then<void>((_) {});
}
