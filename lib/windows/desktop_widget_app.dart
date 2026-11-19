/// 桌面小组件窗口：Vectra 式「真·桌面层」可编辑月历。
///
/// 原生窗口是覆盖整个虚拟屏、透明、常驻 Z 序最底的 `WS_POPUP`；
/// `SetWindowRgn` 把它裁成卡片圆角矩形，因此卡片内的点击/输入
/// 全部由 Flutter 处理，卡片外则直接穿透到桌面图标。
///
/// 对齐旧版桌面日历：卡片与格子更大、点击日期后直接在格子内逐行编辑，
/// 底部常驻编辑工具栏（文字颜色 / 单元格颜色 / 完成 / 清空等），
/// 不再弹出独立编辑卡片（弹窗会被 SetWindowRgn 裁掉）。
///
/// 所有编辑都通过既有的 `CalendarController` 用例落到同一套仓储与领域事件，
/// 主窗口通过 `CrossEngineSync` 立即看到结果，数据流与页面内编辑完全一致。
///
/// ADR-0006 步骤5：几何（位置/尺寸/浮层矩形）与编辑态分别收敛到独立
/// [ValueNotifier]，拖动/缩放只通知几何域，卡片内容作为缓存 child 不随
/// 几何重建；月历网格 / 编辑器浮层 / 调色板拆为独立 widget，各自只监听
/// 相关域。命中区域 / 拖动手势 / `_pushRegion` 链路逻辑保持原样。
library;

import 'dart:async';

import 'package:core/storage.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../bootstrap/core_providers.dart';
import '../core/ports.dart';
import '../core/value_objects.dart';
import '../features/calendar/application/calendar_controller.dart';
import '../features/calendar/domain/calendar_event.dart';
import '../features/calendar/domain/day_cell.dart';
import '../features/calendar/presentation/calendar_providers.dart';
import '../features/calendar/presentation/read_model/month_data.dart';
import '../features/history/application/history_controller.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/domain/app_settings.dart';
import '../shared/widgets/common.dart';
import 'popup_layout.dart';

/// 桌面卡片位置/尺寸的持久化键。
const String desktopCardPositionKey = 'planstar.desktop.card.v2';

/// 卡片位置键的重载分组注册（只有 overlay engine 自己消费）。
void registerDesktopPositionReloadTargets(ReloadTargetRegistry registry) =>
    registry.registerKey(desktopCardPositionKey, 'position');

enum _ColorTarget { none, text, cell }

/// 卡片八个方向的可拖拽调整区域。
enum _ResizeEdge {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// 卡片几何域：位置 / 尺寸 / 浮层矩形。拖动/缩放只改这里，
/// 与编辑态解耦，避免高频 pointer 移动重建整张月历网格。
final class _Geometry {
  const _Geometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.popupRect,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final Rect? popupRect;

  static const Object _unset = Object();

  _Geometry copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    Object? popupRect = _unset,
  }) => _Geometry(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    popupRect: identical(popupRect, _unset)
        ? this.popupRect
        : popupRect as Rect?,
  );
}

/// 编辑态域：选中 / 编辑 / 浮层日期 / 调色板目标 / 清空确认 / 最近用色。
/// 与几何域分离，编辑操作不触发卡片重定位。
///
/// 注意：`activeLineId`（当前聚焦行）不在此域内——它在输入框聚焦时静默更新、
/// 只被动作/调色板按需读取，若纳入通知会在打字聚焦时重建浮层、扰乱光标。
final class _Editing {
  const _Editing({
    this.selectedDate,
    this.editingDate,
    this.popupDate,
    this.paletteTarget = _ColorTarget.none,
    this.confirmClear = false,
    this.recentColors = const <EventColor>[],
  });

  final DateKey? selectedDate;
  final DateKey? editingDate;
  final DateKey? popupDate;
  final _ColorTarget paletteTarget;
  final bool confirmClear;
  final List<EventColor> recentColors;

  static const Object _unset = Object();

  _Editing copyWith({
    Object? selectedDate = _unset,
    Object? editingDate = _unset,
    Object? popupDate = _unset,
    _ColorTarget? paletteTarget,
    bool? confirmClear,
    List<EventColor>? recentColors,
  }) => _Editing(
    selectedDate: identical(selectedDate, _unset)
        ? this.selectedDate
        : selectedDate as DateKey?,
    editingDate: identical(editingDate, _unset)
        ? this.editingDate
        : editingDate as DateKey?,
    popupDate: identical(popupDate, _unset)
        ? this.popupDate
        : popupDate as DateKey?,
    paletteTarget: paletteTarget ?? this.paletteTarget,
    confirmClear: confirmClear ?? this.confirmClear,
    recentColors: recentColors ?? this.recentColors,
  );
}

final class DesktopWidgetApp extends ConsumerStatefulWidget {
  const DesktopWidgetApp({super.key});

  @override
  ConsumerState<DesktopWidgetApp> createState() => _DesktopWidgetAppState();
}

final class _DesktopWidgetAppState extends ConsumerState<DesktopWidgetApp>
    with WidgetsBindingObserver {
  static const double _defaultCardWidth = 1008;
  static const double _defaultCardHeight = 820;
  static const double _minCardWidth = 560;
  static const double _minCardHeight = 420;
  // 尺寸上限用固定值，不依赖任何单一来源的屏幕尺寸推断。
  static const double _maxCardWidth = 3840;
  static const double _maxCardHeight = 2160;
  static const double _resizeHit = 6;
  static const double _resizeCorner = 16;
  static const double _cardRadius = 18;
  // 浮层编辑器：锚定在被编辑格子右侧/左侧，矩形会一并推给 SetWindowRgn。
  static const double _popupWidth = 268;
  static const double _popupHeight = 368;
  static const double _popupGap = 6;
  static const double _popupRadius = 12;

  // 几何域：尺寸与位置一样是持久化状态；格子由 LayoutBuilder 自适应。
  final ValueNotifier<_Geometry> _geometry = ValueNotifier<_Geometry>(
    const _Geometry(
      x: 96,
      y: 96,
      width: _defaultCardWidth,
      height: _defaultCardHeight,
    ),
  );

  // 虚拟屏逻辑尺寸由多个来源取最大值：子窗口 engine 的 MediaQuery / view
  // 尺寸可能随启动时序偏小，原生 GetSystemMetrics 才是权威虚拟屏范围。
  Size _screen = const Size(1920, 1080);
  DesktopMetrics _nativeMetrics = DesktopMetrics.fallback;

  static const double _headerHeight = 48;
  static const double _weekdayHeight = 28;
  static const double _quickInputHeight = 48;
  static const double _toolbarHeight = 52;
  static const double _paletteHeight = 56;
  static const double _gridPadding = 6;
  static const double _gridSpacing = 4;
  // 默认卡片宽度下单格的宽度，用于把字号随格子尺寸等比缩放。
  static const double _referenceCellWidth = 140;

  // 编辑态域：单击只选中并高亮格子，编辑只在浮层里进行。
  final ValueNotifier<_Editing> _editing = ValueNotifier<_Editing>(
    const _Editing(),
  );
  // 桌面鼠标下 GestureDetector 的 onDoubleTap 常与 onTap 竞争失败，
  // 因此自己按「同一格 + 350ms 内两次点击」判定双击。
  DateTime? _lastCellTapAt;
  DateKey? _lastCellTapDate;
  // 当前聚焦行：聚焦时静默更新（不通知），只被动作/调色板按需读取。
  String? _activeLineId;
  bool _dragging = false;
  Offset _dragOrigin = Offset.zero;
  double _dragStartX = 0;
  double _dragStartY = 0;

  // 窗口创建/激活时 Windows 会投递一次孤立 pointer 事件，落在角手柄上会
  // 被误判成 resize；启动后短暂冷却，用户无感但能挡掉这类伪拖拽。
  final DateTime _resizeEnabledAt = DateTime.now().add(
    const Duration(milliseconds: 1500),
  );
  bool _resizing = false;
  bool _resizeActivated = false;
  _ResizeEdge? _resizeEdge;
  Offset _resizeOrigin = Offset.zero;
  double _resizeStartX = 0;
  double _resizeStartY = 0;
  double _resizeStartW = 0;
  double _resizeStartH = 0;
  String _regionSignature = '';
  late final KeyValueStore _store;
  // 读取完成前不允许写盘，避免启动期的生命周期回调覆盖已保存的位置/尺寸。
  bool _positionLoaded = false;
  // 启动期子窗口 view 还是创建尺寸（1920×1080 物理），先于全屏化到达的
  // clamp 若从「上一次 clamp 结果」出发会把存储坐标压扁且再也恢复不回来；
  // 故 clamp 始终从存储原值出发，直到用户拖拽/调整接管几何。
  Offset? _restoredOrigin;
  final TextEditingController _input = TextEditingController();
  final TextEditingController _cellInput = TextEditingController();
  final FocusNode _cellFocus = FocusNode();

  _Geometry get _geo => _geometry.value;
  _Editing get _ed => _editing.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 缓存端口引用，dispose / 生命周期回调里不再依赖 ref。
    _store = ref.read(keyValueStoreProvider);
    // 桌面格子编辑在此 engine 内分发 DayCellChanged，必须在此 engine 也
    // 初始化 HistoryController，否则桌面改动不会出现在主窗口历史页。
    ref.read(historyControllerProvider);
    _loadPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(desktopWallpaperGatewayProvider)
          .configureOverlay(enable: true);
      await _loadNativeMetrics();
      _pushRegion();
    });
  }

  @override
  void dispose() {
    // 进程可能随时被结束，退出前把最终位置/尺寸写盘。
    unawaited(_persistPosition());
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _cellInput.dispose();
    _cellFocus.dispose();
    _geometry.dispose();
    _editing.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _screen = MediaQuery.sizeOf(context);
    _clampToScreen();
    _regionSignature = '';
    _pushRegion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 隐藏桌面组件 / 切后台 / 应用退出时都补一次落盘。
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistPosition());
    }
  }

  Future<void> _loadPosition() async {
    final json = await _store.readJson(desktopCardPositionKey);
    var g = _geo;
    if (json != null) {
      g = g.copyWith(
        x: (json['x'] as num?)?.toDouble() ?? g.x,
        y: (json['y'] as num?)?.toDouble() ?? g.y,
        width: (json['width'] as num?)?.toDouble() ?? g.width,
        height: (json['height'] as num?)?.toDouble() ?? g.height,
      );
    }
    if (!mounted) return;
    _positionLoaded = true;
    _restoredOrigin = Offset(g.x, g.y);
    _geometry.value = g;
    _clampToScreen();
    _regionSignature = '';
    _pushRegion();
  }

  Future<void> _loadNativeMetrics() async {
    try {
      final metrics = await ref
          .read(desktopWallpaperGatewayProvider)
          .desktopMetrics();
      if (!mounted) return;
      _nativeMetrics = metrics;
      _clampToScreen();
      _regionSignature = '';
      _pushRegion();
    } on Object {
      // 原生通道不可用时保留默认 / MediaQuery 值。
    }
  }

  /// 卡片尺寸与位置都必须留在虚拟屏内，否则命中区域会被裁到屏幕外。
  void _clampToScreen() {
    final g = _geo;
    final w = g.width.clamp(_minCardWidth, _maxCardWidth).toDouble();
    final h = g.height.clamp(_minCardHeight, _maxCardHeight).toDouble();
    final size = _screenSize;
    final maxX = size.width - w;
    final maxY = size.height - h;
    final origin = _restoredOrigin ?? Offset(g.x, g.y);
    _geometry.value = g.copyWith(
      x: origin.dx.clamp(0.0, maxX > 0 ? maxX : 0.0).toDouble(),
      y: origin.dy.clamp(0.0, maxY > 0 ? maxY : 0.0).toDouble(),
      width: w,
      height: h,
    );
  }

  /// 取所有可用来源里最大的屏幕范围，避免子窗口 engine 的 view 尺寸偏小
  /// 导致卡片被错误缩小、位置被压到 (0,0)。
  Size get _screenSize {
    // 下限只保证「默认卡片 + 边距」，不能用 1920×1080 硬下限：
    // 1366×768 屏幕上会把卡片 clamp 到可视区外且再也拖不回来。
    var width = _screen.width > _defaultCardWidth + 64
        ? _screen.width
        : _defaultCardWidth + 64.0;
    var height = _screen.height > _defaultCardHeight + 64
        ? _screen.height
        : _defaultCardHeight + 64.0;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    for (final view in views) {
      final dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1.0;
      final vw = view.physicalSize.width / dpr;
      final vh = view.physicalSize.height / dpr;
      if (vw > width) width = vw;
      if (vh > height) height = vh;
    }
    // 原生 GetSystemMetrics 返回物理像素，按 overlay 所属 view 的 dpr 换算。
    // 用当前 engine 的 view dpr（与 setRegion 同一坐标系），避免混合 DPI 下
    // 逐个 view 换算把逻辑尺寸错误放大。
    final effectiveDpr = views.isNotEmpty && views.first.devicePixelRatio > 0
        ? views.first.devicePixelRatio
        : 1.0;
    final nativeWidth = _nativeMetrics.width / effectiveDpr;
    final nativeHeight = _nativeMetrics.height / effectiveDpr;
    if (nativeWidth > width) width = nativeWidth;
    if (nativeHeight > height) height = nativeHeight;
    return Size(width, height);
  }

  /// 立即落盘，不再用 300ms 去抖：调整完马上关闭应用也不会丢最后一次操作。
  /// DataHub 的写入是进程级串行 + 原子替换，拖拽/调整结束时各写一次即可。
  Future<void> _persistPosition() async {
    if (!_positionLoaded) return;
    final g = _geo;
    await _store.writeJson(desktopCardPositionKey, <String, Object?>{
      'x': g.x,
      'y': g.y,
      'width': g.width,
      'height': g.height,
    });
  }

  /// 把卡片矩形（以及浮层编辑器矩形）推给原生层。
  ///
  /// 原生 `SetRegion` 会把多个圆角矩形做 `CombineRgn(RGN_OR)`，因此弹窗即使
  /// 超出卡片范围也能接收点击，而卡片外仍保持穿透。签名遍历全部矩形去重，
  /// 避免每帧重设区域。
  void _pushRegion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final g = _geo;
      final rects = <DesktopCardRect>[
        DesktopCardRect(
          x: g.x * dpr,
          y: g.y * dpr,
          width: g.width * dpr,
          height: g.height * dpr,
          radius: _cardRadius * dpr,
        ),
        if (g.popupRect != null)
          DesktopCardRect(
            x: g.popupRect!.left * dpr,
            y: g.popupRect!.top * dpr,
            width: g.popupRect!.width * dpr,
            height: g.popupRect!.height * dpr,
            radius: _popupRadius * dpr,
          ),
      ];
      final signature = rects
          .map(
            (DesktopCardRect r) =>
                '${r.x},${r.y},${r.width},${r.height},${r.radius}',
          )
          .join('|');
      if (signature == _regionSignature) return;
      _regionSignature = signature;
      ref.read(desktopWallpaperGatewayProvider).setRegion(rects: rects);
    });
  }

  void _beginDrag(Offset globalPosition) {
    _closePopup(pushRegion: false);
    _dragging = true;
    _restoredOrigin = null;
    _dragOrigin = globalPosition;
    _dragStartX = _geo.x;
    _dragStartY = _geo.y;
    // 拖拽期间放开整窗命中，避免逐帧 SetWindowRgn 造成残影。
    ref
        .read(desktopWallpaperGatewayProvider)
        .setRegion(rects: const <DesktopCardRect>[], dragging: true);
  }

  void _updateDrag(Offset globalPosition) {
    if (!_dragging) return;
    _geometry.value = _geo.copyWith(
      x: _dragStartX + globalPosition.dx - _dragOrigin.dx,
      y: _dragStartY + globalPosition.dy - _dragOrigin.dy,
    );
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    _clampToScreen();
    // 8px 网格吸附（对齐 Vectra 的 snap 思路）。
    final g = _geo;
    _geometry.value = g.copyWith(
      x: (g.x / 8).round() * 8.0,
      y: (g.y / 8).round() * 8.0,
    );
    _regionSignature = '';
    _pushRegion();
    unawaited(_persistPosition());
  }

  bool _edgeHasLeft(_ResizeEdge edge) => switch (edge) {
    _ResizeEdge.left || _ResizeEdge.topLeft || _ResizeEdge.bottomLeft => true,
    _ => false,
  };

  bool _edgeHasRight(_ResizeEdge edge) => switch (edge) {
    _ResizeEdge.right ||
    _ResizeEdge.topRight ||
    _ResizeEdge.bottomRight => true,
    _ => false,
  };

  bool _edgeHasTop(_ResizeEdge edge) => switch (edge) {
    _ResizeEdge.top || _ResizeEdge.topLeft || _ResizeEdge.topRight => true,
    _ => false,
  };

  bool _edgeHasBottom(_ResizeEdge edge) => switch (edge) {
    _ResizeEdge.bottom ||
    _ResizeEdge.bottomLeft ||
    _ResizeEdge.bottomRight => true,
    _ => false,
  };

  void _beginResize(_ResizeEdge edge, Offset globalPosition) {
    if (DateTime.now().isBefore(_resizeEnabledAt)) return;
    _closePopup(pushRegion: false);
    _resizing = true;
    _restoredOrigin = null;
    // 启动/激活窗口时偶尔会带一次孤立的 pointer 事件，必须超过阈值才算
    // 真正开始调整，否则会把随机尺寸写进持久化。
    _resizeActivated = false;
    _resizeEdge = edge;
    _resizeOrigin = globalPosition;
    _resizeStartX = _geo.x;
    _resizeStartY = _geo.y;
    _resizeStartW = _geo.width;
    _resizeStartH = _geo.height;
    // 与拖动一样，调整期间放开整窗命中，避免逐帧 SetWindowRgn 造成残影。
    ref
        .read(desktopWallpaperGatewayProvider)
        .setRegion(rects: const <DesktopCardRect>[], dragging: true);
  }

  void _updateResize(Offset globalPosition) {
    if (!_resizing || _resizeEdge == null) return;
    final edge = _resizeEdge!;
    final dx = globalPosition.dx - _resizeOrigin.dx;
    final dy = globalPosition.dy - _resizeOrigin.dy;
    if (!_resizeActivated) {
      if (dx.abs() < 6 && dy.abs() < 6) return;
      _resizeActivated = true;
    }
    final hasLeft = _edgeHasLeft(edge);
    final hasTop = _edgeHasTop(edge);
    var x = _resizeStartX;
    var y = _resizeStartY;
    var w = _resizeStartW;
    var h = _resizeStartH;

    if (hasLeft) {
      x = _resizeStartX + dx;
      w = _resizeStartW - dx;
    } else if (_edgeHasRight(edge)) {
      w = _resizeStartW + dx;
    }
    if (hasTop) {
      y = _resizeStartY + dy;
      h = _resizeStartH - dy;
    } else if (_edgeHasBottom(edge)) {
      h = _resizeStartH + dy;
    }

    // 最小尺寸：从左侧/上侧缩小时保持对侧边缘不动。
    if (w < _minCardWidth) {
      w = _minCardWidth;
      if (hasLeft) x = _resizeStartX + _resizeStartW - w;
    }
    if (h < _minCardHeight) {
      h = _minCardHeight;
      if (hasTop) y = _resizeStartY + _resizeStartH - h;
    }

    // 不得越过虚拟屏边界。
    final screen = _screenSize;
    if (hasLeft) {
      if (x < 0) {
        w += x;
        x = 0;
      }
    } else if (x + w > screen.width) {
      w = screen.width - x;
    }
    if (hasTop) {
      if (y < 0) {
        h += y;
        y = 0;
      }
    } else if (y + h > screen.height) {
      h = screen.height - y;
    }
    final maxW = screen.width > _minCardWidth ? screen.width : _minCardWidth;
    final maxH = screen.height > _minCardHeight
        ? screen.height
        : _minCardHeight;
    w = w.clamp(_minCardWidth, maxW).toDouble();
    h = h.clamp(_minCardHeight, maxH).toDouble();

    _geometry.value = _geo.copyWith(x: x, y: y, width: w, height: h);
  }

  void _endResize() {
    if (!_resizing) return;
    final activated = _resizeActivated;
    _resizing = false;
    _resizeEdge = null;
    _resizeActivated = false;
    if (!activated) {
      // 没有真正拖动：恢复命中区域，不吸附、不落盘。
      _regionSignature = '';
      _pushRegion();
      return;
    }
    _clampToScreen();
    // 与拖动一致：8px 网格吸附，位置与尺寸都对齐。
    final g = _geo;
    _geometry.value = g.copyWith(
      x: (g.x / 8).round() * 8.0,
      y: (g.y / 8).round() * 8.0,
      width: (g.width / 8).round() * 8.0,
      height: (g.height / 8).round() * 8.0,
    );
    _clampToScreen();
    _regionSignature = '';
    _pushRegion();
    unawaited(_persistPosition());
  }

  /// 单击只选中；同一格 350ms 内第二次单击视为双击，打开浮层编辑器。
  /// 不依赖 GestureDetector.onDoubleTap —— 桌面鼠标下它常被 onTap 抢先。
  void _onCellTap(DateKey date, BuildContext cellContext) {
    final now = DateTime.now();
    final lastAt = _lastCellTapAt;
    if (isDesktopDoubleTap(now, lastAt, _lastCellTapDate, date)) {
      _lastCellTapAt = null;
      _lastCellTapDate = null;
      _openPopup(date, cellContext);
      return;
    }
    _lastCellTapAt = now;
    _lastCellTapDate = date;
    _select(date);
  }

  /// 单击只选中格子（高亮 + 作为底部工具栏的作用目标），不进入编辑态。
  /// 真正的编辑统一通过浮层编辑器，避免格子内输入框遮挡日期与农历。
  void _select(DateKey date) {
    _activeLineId = null;
    _editing.value = _ed.copyWith(
      selectedDate: date,
      paletteTarget: _ColorTarget.none,
      confirmClear: false,
    );
  }

  void _closeEditor() {
    _activeLineId = null;
    _editing.value = _ed.copyWith(
      editingDate: null,
      paletteTarget: _ColorTarget.none,
      confirmClear: false,
    );
    _cellInput.clear();
    if (_cellFocus.hasFocus) _cellFocus.unfocus();
  }

  /// 长按 / 双击格子：在该格子旁弹出完整编辑器（方案 C）。
  /// 原来的「点一下 = 格子内快速编辑」保持不变，两者互补而非替换。
  void _openPopup(DateKey date, BuildContext cellContext) {
    // 拿不到 RenderBox 时也不能静默失败：退回卡片中部作为锚点，
    // 保证浮层一定会出现（此前这里直接 return，是「点了没反应」的隐患）。
    final box = cellContext.findRenderObject();
    late final Rect cell;
    if (box is RenderBox && box.hasSize) {
      // overlay 窗口覆盖整个虚拟屏，view 坐标即窗口坐标（逻辑像素）。
      final origin = box.localToGlobal(Offset.zero);
      cell = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        box.size.width,
        box.size.height,
      );
    } else {
      cell = _fallbackCell();
    }
    _showPopup(date, cell);
  }

  /// 底部「浮层编辑」按钮 / 右键等没有格子 RenderBox 的入口使用。
  Rect _fallbackCell() {
    final g = _geo;
    return Rect.fromLTWH(
      g.x + g.width * 0.35,
      g.y + g.height * 0.3,
      g.width / 7,
      100,
    );
  }

  void _openPopupFromToolbar() => _showPopup(_targetDate, _fallbackCell());

  void _showPopup(DateKey date, Rect cell) {
    final popup = computeDesktopPopupRect(
      cell,
      _screenSize,
      width: _popupWidth,
      height: _popupHeight,
      gap: _popupGap,
    );
    _activeLineId = null;
    _editing.value = _ed.copyWith(
      popupDate: date,
      selectedDate: date,
      // 工具栏 / inlineEditor 仍复用 editingDate，避免引入第二套编辑状态。
      editingDate: date,
      paletteTarget: _ColorTarget.none,
      confirmClear: false,
    );
    _geometry.value = _geo.copyWith(popupRect: popup);
    _cellInput.clear();
    // 浮层已打开，清掉双击判定状态：避免长按/右键打开后，紧跟着的左键
    // 又落在 350ms 窗口内被误判成双击而重复打开。
    _lastCellTapAt = null;
    _lastCellTapDate = null;
    _regionSignature = '';
    _pushRegion();
    _focusNewLine();
  }

  void _closePopup({bool pushRegion = true}) {
    if (_ed.popupDate == null) return;
    _activeLineId = null;
    _editing.value = _ed.copyWith(
      popupDate: null,
      editingDate: null,
      paletteTarget: _ColorTarget.none,
      confirmClear: false,
    );
    _geometry.value = _geo.copyWith(popupRect: null);
    _cellInput.clear();
    if (_cellFocus.hasFocus) _cellFocus.unfocus();
    _regionSignature = '';
    // 拖动/缩放会立刻 setRegion(dragging: true) 放开整窗命中，
    // 此时若再推一次矩形会把放开状态覆盖掉，故由调用方决定。
    if (pushRegion) _pushRegion();
  }

  void _focusNewLine() {
    if (_ed.editingDate == null) {
      // 「添加一行」在只选中状态下也应打开浮层，而不是静默无反应。
      _openPopupFromToolbar();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cellFocus.requestFocus();
    });
  }

  void _openPalette(_ColorTarget target) {
    _editing.value = _ed.copyWith(
      paletteTarget: _ed.paletteTarget == target ? _ColorTarget.none : target,
      confirmClear: false,
    );
  }

  DateKey get _targetDate =>
      _ed.editingDate ??
      _ed.selectedDate ??
      DateKey.today(ref.read(clockProvider).now());

  DayCell? _cellOf(DateKey date) =>
      ref.read(calendarControllerProvider).cells[date];

  List<RichLine> _linesOf(DateKey date) =>
      _cellOf(date)?.lines ?? const <RichLine>[];

  Future<void> _appendLine(DateKey date, String text) async {
    if (text.trim().isEmpty) return;
    final lines = _linesOf(date);
    await ref.read(calendarControllerProvider.notifier).saveCellLines(
      date,
      <RichLine>[
        ...lines,
        RichLine(id: ref.read(idGeneratorProvider).next(), text: text.trim()),
      ],
    );
  }

  Future<void> _addFromQuickInput() async {
    final text = _input.text;
    _input.clear();
    await _appendLine(_targetDate, text);
  }

  Future<void> _addFromCell() async {
    final date = _ed.editingDate;
    if (date == null) return;
    final text = _cellInput.text;
    _cellInput.clear();
    await _appendLine(date, text);
    _focusNewLine();
  }

  Future<void> _updateLineText(DateKey date, String id, String value) async {
    await ref
        .read(calendarControllerProvider.notifier)
        .saveCellLines(
          date,
          _linesOf(date)
              .map(
                (RichLine line) =>
                    line.id == id ? line.copyWith(text: value) : line,
              )
              .toList(),
        );
  }

  Future<void> _toggleLine(DateKey date, String id) => ref
      .read(calendarControllerProvider.notifier)
      .toggleLineCompleted(date, id);

  Future<void> _removeLine(DateKey date, String id) =>
      ref.read(calendarControllerProvider.notifier).removeLine(date, id);

  Future<void> _toggleComplete() async {
    final date = _targetDate;
    final controller = ref.read(calendarControllerProvider.notifier);
    final id = _activeLineId;
    if (id != null) {
      await controller.toggleLineCompleted(date, id);
      return;
    }
    final lines = _linesOf(date);
    final allDone =
        lines.isNotEmpty && lines.every((RichLine l) => l.completed);
    await controller.saveCellLines(
      date,
      lines
          .map((RichLine l) => l.copyWith(completed: !allDone))
          .toList(growable: false),
    );
  }

  Future<void> _promoteActiveLine() async {
    final date = _ed.editingDate;
    final id = _activeLineId;
    if (date == null || id == null) return;
    await ref
        .read(calendarControllerProvider.notifier)
        .promoteLineToEvent(date, id, CalendarEventType.task);
    _activeLineId = null;
    _editing.value = _ed.copyWith();
  }

  Future<void> _clearCell() async {
    if (!_ed.confirmClear) {
      _editing.value = _ed.copyWith(confirmClear: true);
      return;
    }
    await ref
        .read(calendarControllerProvider.notifier)
        .saveCellLines(_targetDate, const <RichLine>[]);
    _editing.value = _ed.copyWith(confirmClear: false);
  }

  Future<void> _applyColor(EventColor color) async {
    final date = _targetDate;
    final controller = ref.read(calendarControllerProvider.notifier);
    if (_ed.paletteTarget == _ColorTarget.cell) {
      await controller.setCellBackgroundColor(date, color);
    } else {
      final id = _activeLineId;
      if (id != null) {
        await controller.setLineColor(date, id, color);
      } else {
        await controller.saveCellLines(
          date,
          _linesOf(date)
              .map((RichLine l) => l.copyWith(color: color))
              .toList(growable: false),
        );
      }
    }
    if (!mounted) return;
    final recent = <EventColor>[..._ed.recentColors]
      ..removeWhere((EventColor c) => c.argb == color.argb)
      ..insert(0, color);
    if (recent.length > 8) recent.removeRange(8, recent.length);
    _editing.value = _ed.copyWith(recentColors: recent);
  }

  /// 用户手动设置的单元格颜色可能很亮，默认文字自动取对比色。
  ///
  /// 默认格底是半透明白（white7），叠在 black3 深色卡片上实际是暗底；
  /// 而 [Color.computeLuminance] 忽略 alpha，直接算会把它当成纯白亮底并
  /// 返回黑字——这正是「桌面深底黑字」的根因。先合成到卡片底色再判亮度。
  /// 不透明的用户自定义色不受影响，仍保留「亮底黑字」的自动对比。
  Color _defaultTextOn(Color background) {
    final effective = background.a < 1.0
        ? Color.alphaBlend(background, BasePalette.black3)
        : background;
    return effective.computeLuminance() > 0.45
        ? BasePalette.grayDark1
        : BasePalette.grayLight1;
  }

  /// 桌面格子分层底色：今天 / 用户自定义色优先，其余按「本月 + 周末」分级。
  /// 全部由 BasePalette 派生，不写死十六进制；本月更亮、非本月更暗、
  /// 周末叠一层低饱和暖色，且绝不覆盖用户手动选的单元格颜色。
  Color _cellBackground(
    CalendarDayModel day,
    EventColor? custom,
    bool weekend,
  ) {
    if (custom != null && !custom.isTransparent) return custom.toColor();
    if (day.isToday) return BasePalette.themeDark3;
    final inMonth = day.isCurrentMonth;
    if (weekend) {
      return BasePalette.orangeLight3.withValues(alpha: inMonth ? 0.16 : 0.06);
    }
    return BasePalette.white1.withValues(alpha: inMonth ? 0.20 : 0.06);
  }

  Color _lineColor(RichLine line, Color defaultText) {
    if (line.color.isTransparent ||
        line.color.argb == EventColor.defaultText.argb) {
      return defaultText;
    }
    return line.color.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(
      settingsControllerProvider.select((AppSettings s) => s.themeMode),
    );
    // overlay 窗口覆盖整个虚拟屏，view 的逻辑尺寸就是可用的屏幕范围。
    _screen = MediaQuery.sizeOf(context);
    return MaterialApp(
      title: '桌面日历',
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _toMaterialThemeMode(themeMode),
      builder: AppTheme.withAppFont,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          // 点击浮层之外（卡片空白区 / 桌面穿透区）即关闭编辑器。
          onPointerDown: (PointerDownEvent e) {
            final popupRect = _geo.popupRect;
            if (popupRect == null) return;
            // 不用时间窗屏蔽：双击/长按都是从 up 事件触发，打开后到来的
            // pointer down 必然是新的手势，本就该按位置判断开关。时间窗会
            // 让紧接着点别的格子时浮层仍显示旧日期、且能被连续快点无限续期。
            // DPI 取整可能带来几像素偏差，留容差避免弹窗内点击被误判为外部。
            if (!popupRect.inflate(16).contains(e.position)) {
              _closePopup();
            }
          },
          // 几何域独立监听：拖动/缩放只重定位卡片，卡片内容（含 42 格网格）
          // 作为缓存 child 不随几何重建。
          child: ValueListenableBuilder<_Geometry>(
            valueListenable: _geometry,
            child: _DesktopCard(this),
            builder: (BuildContext context, _Geometry geo, Widget? card) =>
                Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      left: geo.x,
                      top: geo.y,
                      width: geo.width,
                      height: geo.height,
                      child: card!,
                    ),
                    // 放在最外层 Stack 而非 _card 的 ClipRRect 内，
                    // 否则最底行格子的弹窗会被卡片圆角裁掉。
                    if (geo.popupRect != null && _ed.popupDate != null)
                      Positioned(
                        left: geo.popupRect!.left,
                        top: geo.popupRect!.top,
                        width: geo.popupRect!.width,
                        height: geo.popupRect!.height,
                        child: _PopupEditor(this),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  /// 浮层编辑器：日期标题 + 逐行编辑 + 内嵌调色板 + 紧凑工具行。
  /// 复用 `_inlineEditor` / `_paletteStrip` 与现有工具动作，不引入第二套编辑状态。
  Widget _popupEditor() {
    final date = _ed.popupDate!;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          // 纯白卡片 + 黑字：与浅色输入框形成一致对比，避免白底浅字看不清。
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: BasePalette.grayLight3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: BasePalette.black5,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _popupHeader(date),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                child: _inlineEditor(
                  date,
                  Colors.white,
                  BasePalette.grayDark1,
                  1.0,
                ),
              ),
            ),
            if (_ed.paletteTarget != _ColorTarget.none)
              _PaletteStrip(this, light: true),
            _popupTools(),
          ],
        ),
      ),
    );
  }

  Widget _popupHeader(DateKey date) => Container(
    height: 40,
    padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.xxs),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: BasePalette.grayLight3)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: BasePalette.themeLight6,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '${date.year}年${date.month}月${date.day}日',
            style: const TextStyle(
              fontSize: AppTypography.body,
              color: BasePalette.grayDark1,
            ),
          ),
        ),
        _popupTool(LucideIcons.check, '完成编辑', _closePopup, light: true),
      ],
    ),
  );

  Widget _popupTools() => Container(
    height: 40,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: BasePalette.grayLight3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _popupTool(LucideIcons.plus, '添加一行', _focusNewLine, light: true),
        _popupTool(
          LucideIcons.type,
          '文字颜色',
          () => _openPalette(_ColorTarget.text),
          light: true,
        ),
        _popupTool(
          LucideIcons.paintBucket,
          '单元格颜色',
          () => _openPalette(_ColorTarget.cell),
          light: true,
        ),
        _popupTool(
          LucideIcons.checkCheck,
          '标记完成',
          _toggleComplete,
          light: true,
        ),
        _popupTool(LucideIcons.eraser, '清空本日', _clearCell, light: true),
      ],
    ),
  );

  Widget _popupTool(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool light = false,
  }) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 15,
        color: light ? BasePalette.grayDark4 : BasePalette.grayLight4,
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    ),
  );

  Widget _card(BuildContext context, MonthData month, AppSettings settings) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: BasePalette.black3,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(color: BasePalette.white6),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _header(context, month),
                    _weekdays(context, month, settings),
                    Expanded(child: _DesktopGrid(this, month, settings)),
                    if (_ed.paletteTarget != _ColorTarget.none &&
                        _ed.popupDate == null)
                      _PaletteStrip(this),
                    _quickInput(context),
                    _toolbar(context),
                  ],
                ),
              ),
              ..._resizeHandles(),
            ],
          ),
        ),
      );

  /// 四条边 + 四个角的透明热区；右下角显示可见握柄作为操作提示。
  /// 热区都在卡片矩形内，不会被 `SetWindowRgn` 裁掉。
  List<Widget> _resizeHandles() => <Widget>[
    _resizeHandle(
      _ResizeEdge.left,
      left: 0,
      top: _resizeCorner,
      bottom: _resizeCorner,
      width: _resizeHit,
    ),
    _resizeHandle(
      _ResizeEdge.right,
      right: 0,
      top: _resizeCorner,
      bottom: _resizeCorner,
      width: _resizeHit,
    ),
    _resizeHandle(
      _ResizeEdge.top,
      top: 0,
      left: _resizeCorner,
      right: _resizeCorner,
      height: _resizeHit,
    ),
    _resizeHandle(
      _ResizeEdge.bottom,
      bottom: 0,
      left: _resizeCorner,
      right: _resizeCorner,
      height: _resizeHit,
    ),
    _resizeHandle(
      _ResizeEdge.topLeft,
      left: 0,
      top: 0,
      width: _resizeCorner,
      height: _resizeCorner,
    ),
    _resizeHandle(
      _ResizeEdge.topRight,
      right: 0,
      top: 0,
      width: _resizeCorner,
      height: _resizeCorner,
    ),
    _resizeHandle(
      _ResizeEdge.bottomLeft,
      left: 0,
      bottom: 0,
      width: _resizeCorner,
      height: _resizeCorner,
    ),
    _resizeHandle(
      _ResizeEdge.bottomRight,
      right: 0,
      bottom: 0,
      width: _resizeCorner,
      height: _resizeCorner,
      showGrip: true,
    ),
  ];

  Widget _resizeHandle(
    _ResizeEdge edge, {
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
    bool showGrip = false,
  }) => Positioned(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    width: width,
    height: height,
    child: MouseRegion(
      cursor: _resizeCursor(edge),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (PointerDownEvent e) => _beginResize(edge, e.position),
        onPointerMove: (PointerMoveEvent e) => _updateResize(e.position),
        onPointerUp: (_) => _endResize(),
        onPointerCancel: (_) => _endResize(),
        child: showGrip
            ? Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BasePalette.white6,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xs),
                  ),
                ),
                child: const Icon(
                  LucideIcons.grip,
                  size: 11,
                  color: BasePalette.grayLight4,
                ),
              )
            : const SizedBox.expand(),
      ),
    ),
  );

  MouseCursor _resizeCursor(_ResizeEdge edge) => switch (edge) {
    _ResizeEdge.left || _ResizeEdge.right => SystemMouseCursors.resizeLeftRight,
    _ResizeEdge.top || _ResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
    _ResizeEdge.topLeft ||
    _ResizeEdge.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    _ResizeEdge.topRight ||
    _ResizeEdge.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
  };

  /// 收起桌面组件：不能只调本地 hide，否则子窗口隐藏了但共享设置里
  /// `desktopWidgetEnabled` 仍是 true，托盘「显示桌面日历窗口」改写设置时
  /// 因值未变化被 `SettingsController.update` 短路，永远不会触发重新显示。
  /// 这里改为写共享设置（经 DataHub 广播让主窗口同步状态并复用同一 engine）；
  /// 本地 hide 只作为即时反馈，主窗口随后再 hide 是幂等的。
  Future<void> _collapseDesktopWidget() async {
    await ref
        .read(settingsControllerProvider.notifier)
        .update((AppSettings s) => s.copyWith(desktopWidgetEnabled: false));
    await ref.read(multiWindowGatewayProvider).hideCurrentWindow();
  }

  Widget _header(BuildContext context, MonthData month) => Listener(
    onPointerDown: (PointerDownEvent e) => _beginDrag(e.position),
    onPointerMove: (PointerMoveEvent e) => _updateDrag(e.position),
    onPointerUp: (_) => _endDrag(),
    onPointerCancel: (_) => _endDrag(),
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BasePalette.white6)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(LucideIcons.grip, size: 16, color: BasePalette.grayLight5),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '${month.anchor.year}年${month.anchor.month}月',
            style: const TextStyle(
              fontSize: AppTypography.subtitle,
              fontWeight: AppTypography.bold,
              color: BasePalette.grayLight1,
            ),
          ),
          const Spacer(),
          _iconButton(
            LucideIcons.chevronLeft,
            '上一月',
            () => ref.read(monthNavigationProvider.notifier).previous(),
          ),
          _iconButton(
            LucideIcons.calendarCheck2,
            '回到今天',
            () => ref.read(monthNavigationProvider.notifier).today(),
          ),
          _iconButton(
            LucideIcons.chevronRight,
            '下一月',
            () => ref.read(monthNavigationProvider.notifier).next(),
          ),
          _iconButton(LucideIcons.x, '收起桌面组件', _collapseDesktopWidget),
        ],
      ),
    ),
  );

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton(
        tooltip: tooltip,
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        color: BasePalette.grayLight4,
        icon: Icon(icon),
        onPressed: onPressed,
      );

  Widget _weekdays(
    BuildContext context,
    MonthData month,
    AppSettings settings,
  ) => SizedBox(
    height: _weekdayHeight,
    child: Row(
      children: <Widget>[
        for (int i = 0; i < month.weekdayHeaders.length; i++)
          Expanded(
            child: Center(
              child: Text(
                month.weekdayHeaders[i],
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: _isWeekendColumn(i, settings)
                      ? BasePalette.orangeLight3
                      : BasePalette.grayLight5,
                  fontWeight: _isWeekendColumn(i, settings)
                      ? AppTypography.medium
                      : AppTypography.regular,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// 第 [index] 列表头对应的 weekday（1=周一…7=周日），按用户设置的
  /// 每周起始日旋转；不要在渲染里硬编码「第 6、7 列」。
  bool _isWeekendColumn(int index, AppSettings settings) =>
      settings.showRestDays &&
      settings.restDays.contains(((settings.startOfWeek - 1 + index) % 7) + 1);

  Widget _grid(BuildContext context, MonthData month, AppSettings settings) {
    final days = month.columns.isEmpty
        ? const <CalendarDayModel>[]
        : month.columns.first;
    final count = (days.length ~/ 7) * 7;
    if (count == 0) return const SizedBox.shrink();
    final rows = count ~/ 7;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final cellWidth =
            (constraints.maxWidth - 2 * _gridPadding - 6 * _gridSpacing) / 7;
        final cellHeight =
            (constraints.maxHeight -
                2 * _gridPadding -
                (rows - 1) * _gridSpacing) /
            rows;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(_gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: cellWidth / (cellHeight > 1 ? cellHeight : 1),
            crossAxisSpacing: _gridSpacing,
            mainAxisSpacing: _gridSpacing,
          ),
          itemCount: count,
          itemBuilder: (BuildContext context, int index) =>
              _dayCell(context, days[index], settings, cellWidth, cellHeight),
        );
      },
    );
  }

  Widget _dayCell(
    BuildContext context,
    CalendarDayModel day,
    AppSettings settings,
    double cellWidth,
    double cellHeight,
  ) {
    // 卡片被拉大/缩小时，格子本身由 LayoutBuilder 重算；字号同步等比缩放，
    // 同时限制上下限避免过窄卡片里文字挤爆或过宽卡片里文字过大。
    final scale = (cellWidth / _referenceCellWidth).clamp(0.85, 1.5).toDouble();
    // 单击只高亮选中；编辑态只存在于浮层里，格子内始终只读展示。
    final selected =
        _ed.selectedDate == day.date || _ed.editingDate == day.date;
    // MonthData 已把 DayCell 聚合进每个 CalendarDayModel，直接用它，
    // 避免 42 个格子各自线性扫描整个 cells 列表（N+1）。
    final cell = day.cell;
    final customColor = cell?.backgroundColor;
    final inMonth = day.isCurrentMonth;
    final weekend =
        settings.showRestDays && settings.restDays.contains(day.date.weekday);
    final background = _cellBackground(day, customColor, weekend);
    final defaultText = _defaultTextOn(background);
    final dimText = defaultText.withValues(alpha: 0.42);
    final subText = defaultText.withValues(alpha: inMonth ? 0.72 : 0.42);
    final lineText = defaultText.withValues(alpha: inMonth ? 1.0 : 0.62);
    final weekendText = Color.lerp(
      defaultText,
      BasePalette.orangeLight3,
      0.55,
    )!;
    final visibleLines = (cell?.lines ?? const <RichLine>[])
        .where((RichLine l) => settings.showCompleted || !l.completed)
        .where((RichLine l) => l.text.trim().isNotEmpty)
        .toList(growable: false);
    final extras = <String>[
      ...day.events
          .map((EventOccurrence e) => e.event.content.trim())
          .where((String t) => t.isNotEmpty),
      ...day.tags
          .where((TimelineTag t) => t.kind == TimelineTagKind.subscription)
          .map((TimelineTag t) => t.text.trim())
          .where((String t) => t.isNotEmpty),
    ];
    return GestureDetector(
      onTap: () => _onCellTap(day.date, context),
      // 长按 / 右键也打开浮层；双击由 _onCellTap 自己判定，
      // 不用 onDoubleTap，避免桌面鼠标下与 onTap 竞争失败。
      onLongPress: () => _openPopup(day.date, context),
      // 桌面端右键最稳定，作为长按/双击之外的第三条触发路径。
      onSecondaryTapDown: (TapDownDetails _) => _openPopup(day.date, context),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: selected
                ? BasePalette.themeDark6
                : day.isToday
                ? BasePalette.themeDark6
                : weekend
                ? BasePalette.orangeLight3.withValues(alpha: 0.42)
                : BasePalette.white6,
            width: selected ? 2 : 1,
          ),
        ),
        padding: EdgeInsets.all(
          AppSpacing.xxs * (cellHeight / 100).clamp(0.8, 1.4).toDouble(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: AppTypography.body * scale,
                    fontWeight: AppTypography.bold,
                    color: !inMonth
                        ? dimText
                        : weekend
                        ? weekendText
                        : defaultText,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                if (settings.showLunar)
                  Expanded(
                    child: Text(
                      day.meta.subtitle(
                        showLunar: settings.showLunar,
                        showSolarTerms: settings.showSolarTerms,
                        showFestival: settings.showFestival,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.label * scale,
                        color: subText,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 0; i < visibleLines.length; i++)
                      Text(
                        '${i + 1}. ${visibleLines[i].text.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTypography.label * scale,
                          color: _lineColor(visibleLines[i], lineText),
                          decoration: visibleLines[i].completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    for (final extra in extras)
                      Text(
                        '· $extra',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTypography.label * scale,
                          color: subText,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 格子内直接编辑：每行一个输入框 + 完成勾选 + 删除，底部回车新增。
  Widget _inlineEditor(
    DateKey date,
    Color background,
    Color defaultText,
    double scale,
  ) {
    final lines = _linesOf(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: lines.length,
            itemBuilder: (BuildContext context, int index) =>
                _editLineRow(date, lines[index], defaultText, scale),
          ),
        ),
        SizedBox(
          height: 26 * scale,
          child: TextField(
            controller: _cellInput,
            focusNode: _cellFocus,
            style: TextStyle(
              fontSize: AppTypography.label * scale,
              color: defaultText,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '回车新增一行…',
              hintStyle: TextStyle(
                fontSize: AppTypography.label * scale,
                color: defaultText.withValues(alpha: 0.45),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _addFromCell(),
          ),
        ),
      ],
    );
  }

  Widget _editLineRow(
    DateKey date,
    RichLine line,
    Color defaultText,
    double scale,
  ) => SizedBox(
    key: ValueKey<String>(line.id),
    height: 26 * scale,
    child: Row(
      children: <Widget>[
        InkWell(
          onTap: () => _toggleLine(date, line.id),
          child: Icon(
            line.completed ? LucideIcons.squareCheck : LucideIcons.square,
            size: 14 * scale,
            color: line.completed
                ? BasePalette.themeDark6
                : defaultText.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(width: 3 * scale),
        Expanded(
          child: Focus(
            onFocusChange: (bool focused) {
              if (focused) _activeLineId = line.id;
            },
            child: TextFormField(
              key: ValueKey<String>(line.id),
              initialValue: line.text,
              maxLines: 1,
              style: TextStyle(
                fontSize: AppTypography.label * scale,
                color: _lineTextColor(line, defaultText),
                decoration: line.completed ? TextDecoration.lineThrough : null,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (String value) =>
                  _updateLineText(date, line.id, value),
            ),
          ),
        ),
        InkWell(
          onTap: () => _removeLine(date, line.id),
          child: Icon(
            LucideIcons.x,
            size: 12 * scale,
            color: BasePalette.redLight4,
          ),
        ),
      ],
    ),
  );

  Color _lineTextColor(RichLine line, Color defaultText) {
    if (line.color.isTransparent ||
        line.color.argb == EventColor.defaultText.argb) {
      return defaultText;
    }
    return line.color.toColor();
  }

  Widget _quickInput(BuildContext context) => Container(
    height: _quickInputHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xxs,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: BasePalette.white6)),
    ),
    child: Row(
      children: <Widget>[
        Text(
          '${_targetDate.month}/${_targetDate.day}',
          style: const TextStyle(
            fontSize: AppTypography.caption,
            color: BasePalette.grayLight5,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: TextField(
            controller: _input,
            style: const TextStyle(
              fontSize: AppTypography.caption,
              color: BasePalette.grayLight1,
            ),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '直接在桌面输入待办，回车添加…',
              hintStyle: TextStyle(
                fontSize: AppTypography.caption,
                color: BasePalette.grayLight7,
              ),
              border: InputBorder.none,
            ),
            onSubmitted: (_) => _addFromQuickInput(),
          ),
        ),
        IconButton(
          tooltip: '添加到选中日期',
          iconSize: 18,
          color: BasePalette.themeDark6,
          icon: const Icon(LucideIcons.circlePlus),
          onPressed: _addFromQuickInput,
        ),
      ],
    ),
  );

  /// 底部常驻编辑栏：对齐旧版「文字颜色 / 单元格颜色」等一排按钮。
  Widget _toolbar(BuildContext context) => Container(
    height: _toolbarHeight,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: BasePalette.white6)),
    ),
    child: Row(
      children: <Widget>[
        Text(
          '编辑 ${_targetDate.month}/${_targetDate.day}',
          style: const TextStyle(
            fontSize: AppTypography.caption,
            color: BasePalette.grayLight5,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _toolButton(
          icon: LucideIcons.plus,
          label: '添加一行',
          tooltip: '在当前日期的格子内新增一行',
          onPressed: _focusNewLine,
        ),
        _toolButton(
          icon: LucideIcons.type,
          label: '文字颜色',
          tooltip: '选中行则改该行，否则改整格文字',
          active: _ed.paletteTarget == _ColorTarget.text,
          onPressed: () => _openPalette(_ColorTarget.text),
        ),
        _toolButton(
          icon: LucideIcons.paintBucket,
          label: '单元格颜色',
          tooltip: '设置当前日期的单元格背景色',
          active: _ed.paletteTarget == _ColorTarget.cell,
          onPressed: () => _openPalette(_ColorTarget.cell),
        ),
        _toolButton(
          icon: LucideIcons.checkCheck,
          label: '标记完成',
          tooltip: '切换选中行或整格的完成状态',
          onPressed: _toggleComplete,
        ),
        _toolButton(
          icon: LucideIcons.repeat,
          label: '提升为任务',
          tooltip: '把选中的一行提升为日历任务',
          onPressed: _promoteActiveLine,
        ),
        _toolButton(
          icon: LucideIcons.eraser,
          label: _ed.confirmClear ? '确认清空' : '清空本日',
          tooltip: '清空当前日期的全部行（需二次确认）',
          color: _ed.confirmClear
              ? BasePalette.redLight4
              : BasePalette.grayLight4,
          onPressed: _clearCell,
        ),
        _toolButton(
          icon: LucideIcons.maximize2,
          label: '浮层编辑',
          tooltip: '在格子旁弹出完整编辑器（也可长按 / 双击 / 右键格子）',
          active: _ed.popupDate != null,
          onPressed: _openPopupFromToolbar,
        ),
        _toolButton(
          icon: LucideIcons.check,
          label: '完成编辑',
          tooltip: '退出当前格子的编辑态',
          active: _ed.editingDate != null,
          onPressed: () {
            _closePopup();
            _closeEditor();
          },
        ),
      ],
    ),
  );

  Widget _toolButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = BasePalette.grayLight4,
    bool active = false,
  }) => Expanded(
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: active
                ? BasePalette.themeDark6.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: active ? BasePalette.themeDark8 : color,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? BasePalette.themeDark8 : color,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// 调色板内嵌在卡片底部，避免 showDialog 被 SetWindowRgn 裁掉。
  Widget _paletteStrip({bool light = false}) {
    final recentColors = _ed.recentColors;
    final swatches = <EventColor>[
      ...recentColors,
      ...EventColor.palette.where(
        (EventColor c) => !recentColors.any((EventColor r) => r.argb == c.argb),
      ),
    ];
    EventColor selected = EventColor.transparent;
    if (_ed.paletteTarget == _ColorTarget.cell) {
      selected =
          _cellOf(_targetDate)?.backgroundColor ?? EventColor.transparent;
    } else if (_activeLineId != null) {
      for (final line in _linesOf(_targetDate)) {
        if (line.id == _activeLineId) selected = line.color;
      }
    }
    return Container(
      height: _paletteHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: light ? BasePalette.grayLight3 : BasePalette.white6,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            _ed.paletteTarget == _ColorTarget.cell ? '单元格颜色' : '文字颜色',
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: light ? BasePalette.grayDark4 : BasePalette.grayLight5,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: swatches
                    .map(
                      (EventColor c) =>
                          _swatch(c, c.argb == selected.argb, light: light),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          _popupTool(
            LucideIcons.x,
            '关闭调色板',
            () =>
                _editing.value = _ed.copyWith(paletteTarget: _ColorTarget.none),
            light: light,
          ),
        ],
      ),
    );
  }

  Widget _swatch(EventColor color, bool selected, {bool light = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xxs),
        child: InkWell(
          onTap: () => _applyColor(color),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.isTransparent
                  ? (light ? BasePalette.grayLight3 : BasePalette.white7)
                  : color.toColor(),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: selected
                    ? (light ? BasePalette.themeLight6 : BasePalette.themeDark6)
                    : (light ? BasePalette.grayLight3 : BasePalette.white6),
                width: selected ? 2 : 1,
              ),
            ),
            child: color.isTransparent
                ? Icon(
                    LucideIcons.ban,
                    size: 14,
                    color: light
                        ? BasePalette.grayDark4
                        : BasePalette.grayLight4,
                  )
                : null,
          ),
        ),
      );

  ThemeMode _toMaterialThemeMode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}

/// 卡片内容（月历网格 + 工具栏）：监听月份/设置数据域与编辑态域，
/// 不监听几何域——作为几何 [ValueListenableBuilder] 的缓存 child，
/// 拖动/缩放时整张卡片（含 42 格）不重建。
final class _DesktopCard extends ConsumerWidget {
  const _DesktopCard(this.state);

  final _DesktopWidgetAppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(monthDataProvider);
    final settings = ref.watch(settingsControllerProvider);
    return ValueListenableBuilder<_Editing>(
      valueListenable: state._editing,
      builder: (BuildContext context, _Editing ed, Widget? child) =>
          state._card(context, month, settings),
    );
  }
}

/// 月历网格：独立 widget，由卡片在编辑态/数据变化时重建。
final class _DesktopGrid extends StatelessWidget {
  const _DesktopGrid(this.state, this.month, this.settings);

  final _DesktopWidgetAppState state;
  final MonthData month;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => state._grid(context, month, settings);
}

/// 编辑器浮层：独立 widget，只监听编辑态域。
final class _PopupEditor extends StatelessWidget {
  const _PopupEditor(this.state);

  final _DesktopWidgetAppState state;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_Editing>(
    valueListenable: state._editing,
    builder: (BuildContext context, _Editing ed, Widget? child) =>
        state._popupEditor(),
  );
}

/// 调色板：独立 widget，卡片底部与浮层内复用同一实现。
final class _PaletteStrip extends StatelessWidget {
  const _PaletteStrip(this.state, {this.light = false});

  final _DesktopWidgetAppState state;
  final bool light;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_Editing>(
    valueListenable: state._editing,
    builder: (BuildContext context, _Editing ed, Widget? child) =>
        state._paletteStrip(light: light),
  );
}
