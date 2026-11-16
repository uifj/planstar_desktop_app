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
library;

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:core/storage.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../bootstrap/core_providers.dart';
import '../core/ports.dart';
import '../core/value_objects.dart';
import '../features/calendar/application/calendar_controllers.dart';
import '../features/calendar/domain/calendar_event.dart';
import '../features/calendar/domain/day_cell.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/subscription/domain/subscription.dart';
import '../shared/widgets/common.dart';

enum _ColorTarget { none, text, cell }

final class DesktopWidgetApp extends ConsumerStatefulWidget {
  const DesktopWidgetApp({super.key});

  @override
  ConsumerState<DesktopWidgetApp> createState() => _DesktopWidgetAppState();
}

final class _DesktopWidgetAppState extends ConsumerState<DesktopWidgetApp>
    with WidgetsBindingObserver {
  static const double _cardWidth = 1008;
  static const double _cardHeight = 820;
  static const double _cardRadius = 18;
  static const String _positionKey = 'planstar.desktop.card.v2';

  static const double _headerHeight = 48;
  static const double _weekdayHeight = 28;
  static const double _quickInputHeight = 48;
  static const double _toolbarHeight = 52;
  static const double _paletteHeight = 56;
  static const double _gridPadding = 6;
  static const double _gridSpacing = 4;

  double _x = 96;
  double _y = 96;
  DateKey? _editingDate;
  String? _activeLineId;
  _ColorTarget _paletteTarget = _ColorTarget.none;
  bool _confirmClear = false;
  bool _dragging = false;
  Offset _dragOrigin = Offset.zero;
  double _dragStartX = 0;
  double _dragStartY = 0;
  String _regionSignature = '';
  Timer? _saveTimer;
  final TextEditingController _input = TextEditingController();
  final TextEditingController _cellInput = TextEditingController();
  final FocusNode _cellFocus = FocusNode();
  final List<EventColor> _recentColors = <EventColor>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(desktopWallpaperGatewayProvider)
          .configureOverlay(enable: true);
      _pushRegion();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _input.dispose();
    _cellInput.dispose();
    _cellFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    setState(_clampToScreen);
    _regionSignature = '';
    _pushRegion();
  }

  Future<void> _loadPosition() async {
    final json = await ref.read(keyValueStoreProvider).readJson(_positionKey);
    if (json != null) {
      _x = (json['x'] as num?)?.toDouble() ?? _x;
      _y = (json['y'] as num?)?.toDouble() ?? _y;
    }
    if (!mounted) return;
    setState(_clampToScreen);
    _regionSignature = '';
    _pushRegion();
  }

  /// 放大后的卡片必须留在虚拟屏内，否则命中区域会被裁到屏幕外。
  void _clampToScreen() {
    final view = PlatformDispatcher.instance.views.first;
    final dpr = view.devicePixelRatio;
    final maxX = view.physicalSize.width / dpr - _cardWidth;
    final maxY = view.physicalSize.height / dpr - _cardHeight;
    _x = _x.clamp(0.0, maxX > 0 ? maxX : 0.0).toDouble();
    _y = _y.clamp(0.0, maxY > 0 ? maxY : 0.0).toDouble();
  }

  void _scheduleSavePosition() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      await ref.read(keyValueStoreProvider).writeJson(
            _positionKey,
            <String, Object?>{'x': _x, 'y': _y},
          );
    });
  }

  /// 把卡片的物理像素矩形推给原生层；用签名去重，避免每帧重设区域。
  void _pushRegion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final rects = <DesktopCardRect>[
        DesktopCardRect(
          x: _x * dpr,
          y: _y * dpr,
          width: _cardWidth * dpr,
          height: _cardHeight * dpr,
          radius: _cardRadius * dpr,
        ),
      ];
      final rect = rects.single;
      final signature =
          '${rect.x},${rect.y},${rect.width},${rect.height},${rect.radius}';
      if (signature == _regionSignature) return;
      _regionSignature = signature;
      ref.read(desktopWallpaperGatewayProvider).setRegion(rects: rects);
    });
  }

  void _beginDrag(Offset globalPosition) {
    _dragging = true;
    _dragOrigin = globalPosition;
    _dragStartX = _x;
    _dragStartY = _y;
    // 拖拽期间放开整窗命中，避免逐帧 SetWindowRgn 造成残影。
    ref
        .read(desktopWallpaperGatewayProvider)
        .setRegion(rects: const <DesktopCardRect>[], dragging: true);
  }

  void _updateDrag(Offset globalPosition) {
    if (!_dragging) return;
    setState(() {
      _x = _dragStartX + globalPosition.dx - _dragOrigin.dx;
      _y = _dragStartY + globalPosition.dy - _dragOrigin.dy;
    });
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    _clampToScreen();
    // 8px 网格吸附（对齐 Vectra 的 snap 思路）。
    _x = (_x / 8).round() * 8.0;
    _y = (_y / 8).round() * 8.0;
    setState(() {});
    _regionSignature = '';
    _pushRegion();
    _scheduleSavePosition();
  }

  void _select(DateKey date) {
    // 已经在该格子内编辑时不再重置，避免点击输入框时丢焦点或清空待提交内容。
    if (_editingDate == date) return;
    setState(() {
      _editingDate = date;
      _activeLineId = null;
      _paletteTarget = _ColorTarget.none;
      _confirmClear = false;
      _cellInput.clear();
    });
    _focusNewLine();
  }

  void _closeEditor() {
    setState(() {
      _editingDate = null;
      _activeLineId = null;
      _paletteTarget = _ColorTarget.none;
      _confirmClear = false;
      _cellInput.clear();
    });
    if (_cellFocus.hasFocus) _cellFocus.unfocus();
  }

  void _focusNewLine() {
    if (_editingDate == null) {
      _select(DateKey.today(ref.read(clockProvider).now()));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cellFocus.requestFocus();
    });
  }

  void _openPalette(_ColorTarget target) {
    setState(() {
      _paletteTarget = _paletteTarget == target ? _ColorTarget.none : target;
      _confirmClear = false;
    });
  }

  DateKey get _targetDate =>
      _editingDate ?? DateKey.today(ref.read(clockProvider).now());

  DayCell? _cellOf(DateKey date) {
    for (final cell in ref.read(calendarControllerProvider).cells) {
      if (cell.date == date) return cell;
    }
    return null;
  }

  List<RichLine> _linesOf(DateKey date) =>
      _cellOf(date)?.lines ?? const <RichLine>[];

  Future<void> _appendLine(DateKey date, String text) async {
    if (text.trim().isEmpty) return;
    final lines = _linesOf(date);
    await ref.read(calendarControllerProvider.notifier).saveCellLines(
          date,
          <RichLine>[
            ...lines,
            RichLine(
              id: ref.read(idGeneratorProvider).next(),
              text: text.trim(),
            ),
          ],
        );
  }

  Future<void> _addFromQuickInput() async {
    final text = _input.text;
    _input.clear();
    await _appendLine(_targetDate, text);
  }

  Future<void> _addFromCell() async {
    final date = _editingDate;
    if (date == null) return;
    final text = _cellInput.text;
    _cellInput.clear();
    await _appendLine(date, text);
    _focusNewLine();
  }

  Future<void> _updateLineText(DateKey date, String id, String value) async {
    await ref.read(calendarControllerProvider.notifier).saveCellLines(
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
    final allDone = lines.isNotEmpty && lines.every((RichLine l) => l.completed);
    await controller.saveCellLines(
      date,
      lines
          .map((RichLine l) => l.copyWith(completed: !allDone))
          .toList(growable: false),
    );
  }

  Future<void> _promoteActiveLine() async {
    final date = _editingDate;
    final id = _activeLineId;
    if (date == null || id == null) return;
    await ref
        .read(calendarControllerProvider.notifier)
        .promoteLineToEvent(date, id, CalendarEventType.task);
    setState(() => _activeLineId = null);
  }

  Future<void> _clearCell() async {
    if (!_confirmClear) {
      setState(() => _confirmClear = true);
      return;
    }
    await ref
        .read(calendarControllerProvider.notifier)
        .saveCellLines(_targetDate, const <RichLine>[]);
    setState(() => _confirmClear = false);
  }

  Future<void> _applyColor(EventColor color) async {
    final date = _targetDate;
    final controller = ref.read(calendarControllerProvider.notifier);
    if (_paletteTarget == _ColorTarget.cell) {
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
    setState(() {
      _recentColors.removeWhere((EventColor c) => c.argb == color.argb);
      _recentColors.insert(0, color);
      if (_recentColors.length > 8) _recentColors.removeRange(8, _recentColors.length);
    });
  }

  /// 用户手动设置的单元格颜色可能很亮，默认文字自动取对比色。
  Color _defaultTextOn(Color background) =>
      background.computeLuminance() > 0.45
          ? BasePalette.grayDark1
          : BasePalette.grayLight1;

  Color _lineColor(RichLine line, Color background) {
    if (line.color.isTransparent ||
        line.color.argb == EventColor.defaultText.argb) {
      return _defaultTextOn(background);
    }
    return line.color.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(monthDataProvider);
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp(
      title: '桌面日历',
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _toMaterialThemeMode(settings.themeMode),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: _x,
                top: _y,
                width: _cardWidth,
                height: _cardHeight,
                child: _card(context, month, settings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    MonthData month,
    AppSettings settings,
  ) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: BasePalette.black3,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(color: BasePalette.white6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _header(context, month),
              _weekdays(context, month),
              Expanded(child: _grid(context, month, settings)),
              if (_paletteTarget != _ColorTarget.none) _paletteStrip(),
              _quickInput(context),
              _toolbar(context),
            ],
          ),
        ),
      );

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
              const Icon(LucideIcons.grip,
                  size: 16, color: BasePalette.grayLight5),
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
                () =>
                    ref.read(monthNavigationProvider.notifier).previous(),
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
              _iconButton(
                LucideIcons.x,
                '收起桌面组件',
                () => ref
                    .read(multiWindowGatewayProvider)
                    .hideCurrentWindow(),
              ),
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

  Widget _weekdays(BuildContext context, MonthData month) => SizedBox(
        height: _weekdayHeight,
        child: Row(
          children: <Widget>[
            for (final label in month.weekdayHeaders)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: AppTypography.caption,
                      color: BasePalette.grayLight5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _grid(
    BuildContext context,
    MonthData month,
    AppSettings settings,
  ) {
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
            (constraints.maxHeight - 2 * _gridPadding - (rows - 1) * _gridSpacing) /
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
              _dayCell(context, days[index], settings),
        );
      },
    );
  }

  Widget _dayCell(
    BuildContext context,
    CalendarDayModel day,
    AppSettings settings,
  ) {
    final editing = _editingDate == day.date;
    final cell = _cellOf(day.date);
    final customColor = cell?.backgroundColor;
    var background = day.isToday ? BasePalette.themeDark3 : BasePalette.white7;
    if (customColor != null && !customColor.isTransparent) {
      background = customColor.toColor();
    }
    final defaultText = _defaultTextOn(background);
    final visibleLines = (cell?.lines ?? const <RichLine>[])
        .where((RichLine l) => settings.showCompleted || !l.completed)
        .where((RichLine l) => l.text.trim().isNotEmpty)
        .toList(growable: false);
    final extras = <String>[
      ...day.events
          .map((EventOccurrence e) => e.event.content.trim())
          .where((String t) => t.isNotEmpty),
      ...day.subscriptionEvents
          .map((SubscriptionEvent e) => e.title.trim())
          .where((String t) => t.isNotEmpty),
    ];
    return GestureDetector(
      onTap: () => _select(day.date),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: editing
                ? BasePalette.themeDark6
                : day.isToday
                    ? BasePalette.themeDark6
                    : BasePalette.white6,
            width: editing ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: AppTypography.body,
                    fontWeight: AppTypography.bold,
                    color: day.isCurrentMonth
                        ? defaultText
                        : defaultText.withValues(alpha: 0.45),
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
                        fontSize: AppTypography.label,
                        color: defaultText.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: editing
                  ? _inlineEditor(day.date, background, defaultText)
                  : SingleChildScrollView(
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
                                fontSize: AppTypography.label,
                                color: _lineColor(visibleLines[i], background),
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
                                fontSize: AppTypography.label,
                                color: defaultText.withValues(alpha: 0.6),
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
  Widget _inlineEditor(DateKey date, Color background, Color defaultText) {
    final lines = _linesOf(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: lines.length,
            itemBuilder: (BuildContext context, int index) =>
                _editLineRow(date, lines[index], defaultText),
          ),
        ),
        SizedBox(
          height: 26,
          child: TextField(
            controller: _cellInput,
            focusNode: _cellFocus,
            style: TextStyle(fontSize: AppTypography.label, color: defaultText),
            decoration: InputDecoration(
              isDense: true,
              hintText: '回车新增一行…',
              hintStyle: TextStyle(
                fontSize: AppTypography.label,
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

  Widget _editLineRow(DateKey date, RichLine line, Color defaultText) =>
      SizedBox(
        key: ValueKey<String>(line.id),
        height: 26,
        child: Row(
          children: <Widget>[
            InkWell(
              onTap: () => _toggleLine(date, line.id),
              child: Icon(
                line.completed ? LucideIcons.squareCheck : LucideIcons.square,
                size: 14,
                color: line.completed
                    ? BasePalette.themeDark6
                    : defaultText.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 3),
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
                    fontSize: AppTypography.label,
                    color: _lineTextColor(line, defaultText),
                    decoration: line.completed
                        ? TextDecoration.lineThrough
                        : null,
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
              child: const Icon(LucideIcons.x,
                  size: 12, color: BasePalette.redLight4),
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
              active: _paletteTarget == _ColorTarget.text,
              onPressed: () => _openPalette(_ColorTarget.text),
            ),
            _toolButton(
              icon: LucideIcons.paintBucket,
              label: '单元格颜色',
              tooltip: '设置当前日期的单元格背景色',
              active: _paletteTarget == _ColorTarget.cell,
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
              label: _confirmClear ? '确认清空' : '清空本日',
              tooltip: '清空当前日期的全部行（需二次确认）',
              color: _confirmClear
                  ? BasePalette.redLight4
                  : BasePalette.grayLight4,
              onPressed: _clearCell,
            ),
            _toolButton(
              icon: LucideIcons.check,
              label: '完成编辑',
              tooltip: '退出当前格子的编辑态',
              active: _editingDate != null,
              onPressed: _closeEditor,
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
  }) =>
      Expanded(
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
                  Icon(icon,
                      size: 16,
                      color: active ? BasePalette.themeDark8 : color),
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
  Widget _paletteStrip() {
    final swatches = <EventColor>[
      ..._recentColors,
      ...EventColor.palette.where(
        (EventColor c) =>
            !_recentColors.any((EventColor r) => r.argb == c.argb),
      ),
    ];
    EventColor selected = EventColor.transparent;
    if (_paletteTarget == _ColorTarget.cell) {
      selected = _cellOf(_targetDate)?.backgroundColor ??
          EventColor.transparent;
    } else if (_activeLineId != null) {
      for (final line in _linesOf(_targetDate)) {
        if (line.id == _activeLineId) selected = line.color;
      }
    }
    return Container(
      height: _paletteHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BasePalette.white6)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            _paletteTarget == _ColorTarget.cell ? '单元格颜色' : '文字颜色',
            style: const TextStyle(
              fontSize: AppTypography.caption,
              color: BasePalette.grayLight5,
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
                          _swatch(c, c.argb == selected.argb),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          _iconButton(
            LucideIcons.x,
            '关闭调色板',
            () => setState(() => _paletteTarget = _ColorTarget.none),
          ),
        ],
      ),
    );
  }

  Widget _swatch(EventColor color, bool selected) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xxs),
        child: InkWell(
          onTap: () => _applyColor(color),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.isTransparent ? BasePalette.white7 : color.toColor(),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: selected
                    ? BasePalette.themeDark6
                    : BasePalette.white6,
                width: selected ? 2 : 1,
              ),
            ),
            child: color.isTransparent
                ? const Icon(LucideIcons.ban,
                    size: 14, color: BasePalette.grayLight4)
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
