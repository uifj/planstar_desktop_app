/// 桌面小组件窗口：Vectra 式「真·桌面层」可编辑月历。
///
/// 原生窗口是覆盖整个虚拟屏、透明、常驻 Z 序最底的 `WS_POPUP`；
/// `SetWindowRgn` 把它裁成卡片圆角矩形的并集，因此卡片内的点击/输入
/// 全部由 Flutter 处理，卡片外则直接穿透到桌面图标。
///
/// 所有编辑都通过既有的 `CalendarController` 用例落到同一套仓储与领域事件，
/// 主窗口通过 `CrossEngineSync` 立即看到结果，数据流与页面内编辑完全一致。
library;

import 'dart:async';

import 'package:core/storage.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/core_providers.dart';
import '../core/ports.dart';
import '../core/value_objects.dart';
import '../features/calendar/application/calendar_controllers.dart';
import '../features/calendar/domain/day_cell.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/subscription/domain/subscription.dart';

final class DesktopWidgetApp extends ConsumerStatefulWidget {
  const DesktopWidgetApp({super.key});

  @override
  ConsumerState<DesktopWidgetApp> createState() => _DesktopWidgetAppState();
}

final class _DesktopWidgetAppState extends ConsumerState<DesktopWidgetApp>
    with WidgetsBindingObserver {
  static const double _cardWidth = 640;
  static const double _cardHeight = 508;
  static const double _editorWidth = 300;
  static const double _editorHeight = 340;
  static const double _cardRadius = 18;
  static const String _positionKey = 'planstar.desktop.card.v1';

  double _x = 128;
  double _y = 128;
  DateKey? _editingDate;
  bool _dragging = false;
  Offset _dragOrigin = Offset.zero;
  double _dragStartX = 0;
  double _dragStartY = 0;
  String _regionSignature = '';
  Timer? _saveTimer;
  final TextEditingController _input = TextEditingController();

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
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _regionSignature = '';
    _pushRegion();
  }

  Future<void> _loadPosition() async {
    final json = await ref.read(keyValueStoreProvider).readJson(_positionKey);
    if (json == null || !mounted) return;
    setState(() {
      _x = (json['x'] as num?)?.toDouble() ?? _x;
      _y = (json['y'] as num?)?.toDouble() ?? _y;
    });
    _regionSignature = '';
    _pushRegion();
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

  /// 把当前卡片的物理像素矩形推给原生层；用签名去重，避免每帧重设区域。
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
        if (_editingDate != null)
          DesktopCardRect(
            x: (_x + _cardWidth + 12) * dpr,
            y: _y * dpr,
            width: _editorWidth * dpr,
            height: _editorHeight * dpr,
            radius: _cardRadius * dpr,
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
      ref
          .read(desktopWallpaperGatewayProvider)
          .setRegion(rects: rects);
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
    // 8px 网格吸附（对齐 Vectra 的 snap 思路）。
    _x = (_x / 8).round() * 8.0;
    _y = (_y / 8).round() * 8.0;
    setState(() {});
    _regionSignature = '';
    _pushRegion();
    _scheduleSavePosition();
  }

  void _select(DateKey date) {
    setState(() => _editingDate = date);
    _regionSignature = '';
    _pushRegion();
  }

  void _closeEditor() {
    setState(() => _editingDate = null);
    _regionSignature = '';
    _pushRegion();
  }

  DateKey get _targetDate =>
      _editingDate ?? DateKey.today(ref.read(clockProvider).now());

  Future<void> _addLine() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final date = _targetDate;
    final month = ref.read(monthDataProvider);
    List<RichLine> lines = const <RichLine>[];
    for (final column in month.columns) {
      for (final day in column) {
        if (day.date == date) lines = day.cell?.lines ?? lines;
      }
    }
    await ref.read(calendarControllerProvider.notifier).saveCellLines(
          date,
          <RichLine>[
            ...lines,
            RichLine(
              id: ref.read(idGeneratorProvider).next(),
              text: text,
            ),
          ],
        );
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
              if (_editingDate != null)
                Positioned(
                  left: _x + _cardWidth + 12,
                  top: _y,
                  width: _editorWidth,
                  height: _editorHeight,
                  child: _editor(context),
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
  ) {
    final today = DateKey.today(ref.watch(clockProvider).now());
    return ClipRRect(
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: BasePalette.black3,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(
            color: BasePalette.white6,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(context, month),
            _weekdays(context, month),
            Expanded(child: _grid(context, month, settings, today)),
            _quickInput(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, MonthData month) => Listener(
        onPointerDown: (PointerDownEvent e) => _beginDrag(e.position),
        onPointerMove: (PointerMoveEvent e) => _updateDrag(e.position),
        onPointerUp: (_) => _endDrag(),
        onPointerCancel: (_) => _endDrag(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: BasePalette.white6),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.drag_indicator, size: 16,
                  color: BasePalette.grayLight5),
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
                Icons.chevron_left,
                '上一月',
                () => ref
                    .read(monthNavigationProvider.notifier)
                    .previous(),
              ),
              _iconButton(
                Icons.today,
                '回到今天',
                () => ref.read(monthNavigationProvider.notifier).today(),
              ),
              _iconButton(
                Icons.chevron_right,
                '下一月',
                () => ref.read(monthNavigationProvider.notifier).next(),
              ),
              _iconButton(
                Icons.close,
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
        height: 26,
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
    DateKey today,
  ) {
    final days = month.columns.isEmpty
        ? const <CalendarDayModel>[]
        : month.columns.first;
    final count = (days.length ~/ 7) * 7;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xxs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.32,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: count,
      itemBuilder: (BuildContext context, int index) =>
          _dayCell(context, days[index], settings, today),
    );
  }

  Widget _dayCell(
    BuildContext context,
    CalendarDayModel day,
    AppSettings settings,
    DateKey today,
  ) {
    final accent = day.isToday
        ? BasePalette.themeDark3
        : BasePalette.white7;
    final lines = <String>[
      ...(day.cell?.lines ?? const <RichLine>[])
          .where((RichLine l) => settings.showCompleted || !l.completed)
          .map((RichLine l) => l.text.trim())
          .where((String t) => t.isNotEmpty),
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
          color: accent,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: day.isToday
              ? Border.all(color: BasePalette.themeDark6, width: 1.4)
              : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${day.date.day}',
              style: TextStyle(
                fontSize: AppTypography.body,
                fontWeight: AppTypography.bold,
                color: day.isCurrentMonth
                    ? BasePalette.grayLight1
                    : BasePalette.white5,
              ),
            ),
            if (settings.showLunar)
              Text(
                day.meta.subtitle(
                  showLunar: settings.showLunar,
                  showSolarTerms: settings.showSolarTerms,
                  showFestival: settings.showFestival,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTypography.label,
                  color: BasePalette.grayLight6,
                ),
              ),
            for (final line in lines.take(2))
              Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTypography.label,
                  color: BasePalette.grayLight3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickInput(BuildContext context) => Container(
        height: 46,
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
                onSubmitted: (_) => _addLine(),
              ),
            ),
            IconButton(
              tooltip: '添加到选中日期',
              iconSize: 16,
              color: BasePalette.themeDark6,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _addLine,
            ),
          ],
        ),
      );

  Widget _editor(BuildContext context) {
    final date = _editingDate!;
    DayCell? cell;
    for (final candidate in ref.watch(calendarControllerProvider).cells) {
      if (candidate.date == date) cell = candidate;
    }
    final lines = cell?.lines ?? const <RichLine>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: BasePalette.black2,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(
            color: BasePalette.white6,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  date.cnFull,
                  style: const TextStyle(
                    fontSize: AppTypography.body,
                    fontWeight: AppTypography.bold,
                    color: BasePalette.grayLight1,
                  ),
                ),
                const Spacer(),
                _iconButton(Icons.close, '关闭编辑', _closeEditor),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            TextField(
              controller: _input,
              autofocus: true,
              style: const TextStyle(
                fontSize: AppTypography.caption,
                color: BasePalette.grayLight1,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '输入内容后回车',
                hintStyle: TextStyle(
                  fontSize: AppTypography.caption,
                  color: BasePalette.grayLight7,
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addLine(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: lines.isEmpty
                  ? const Center(
                      child: Text(
                        '这一天还没有内容',
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          color: BasePalette.grayLight7,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: lines.length,
                      itemBuilder: (BuildContext context, int index) {
                        final line = lines[index];
                        return Row(
                          children: <Widget>[
                            Checkbox(
                              value: line.completed,
                              visualDensity: VisualDensity.compact,
                              onChanged: (_) => ref
                                  .read(calendarControllerProvider.notifier)
                                  .toggleLineCompleted(date, line.id),
                            ),
                            Expanded(
                              child: Text(
                                line.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTypography.caption,
                                  decoration: line.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: BasePalette.grayLight2,
                                ),
                              ),
                            ),
                            IconButton(
                              iconSize: 14,
                              color: BasePalette.redLight4,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(calendarControllerProvider.notifier)
                                  .removeLine(date, line.id),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  ThemeMode _toMaterialThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };
}
