/// 把月历读模型绘制成与桌面同尺寸的 PNG，供 `SPI_SETDESKWALLPAPER` 使用。
///
/// 纯 `dart:ui` 离屏绘制，不依赖 Widget 树 / `RepaintBoundary`，因此可以
/// 在后台定时器里直接生成，也不会打断用户当前所在页面。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../core/ports.dart';
import '../../../core/value_objects.dart';
import '../../calendar/application/calendar_controllers.dart';
import '../../settings/domain/app_settings.dart';

final class WallpaperRenderer {
  const WallpaperRenderer();

  Future<Uint8List> render({
    required DesktopMetrics metrics,
    required MonthData month,
    required AppSettings settings,
    required DateKey today,
    ui.Image? background,
  }) async {
    final int width = _clampInt(metrics.width, 640, 7680);
    final int height = _clampInt(metrics.height, 480, 4320);
    final double w = width.toDouble();
    final double h = height.toDouble();
    final double scale = (h / 1080).clamp(0.75, 1.6).toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, w, h),
    );
    final full = ui.Rect.fromLTWH(0, 0, w, h);

    _drawBackground(canvas, full, settings, background);
    _drawPanel(
      canvas: canvas,
      bounds: ui.Rect.fromLTWH(
        w - w * 0.6 - w * 0.035,
        (h - h * 0.8) / 2,
        w * 0.6,
        h * 0.8,
      ),
      scale: scale,
      month: month,
      settings: settings,
      today: today,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return Uint8List.fromList(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  void _drawBackground(
    ui.Canvas canvas,
    ui.Rect bounds,
    AppSettings settings,
    ui.Image? background,
  ) {
    if (background != null) {
      _drawImageFit(
        canvas,
        background,
        bounds,
        settings.wallpaperFit,
      );
      // 压暗底图，保证白色日历文字可读。
      canvas.drawRect(
        bounds,
        ui.Paint()..color = const ui.Color(0x880A0D14),
      );
      return;
    }
    canvas.drawRect(
      bounds,
      ui.Paint()..color = ui.Color(settings.calendarBackgroundColor),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, bounds.width, bounds.height * 0.4),
      ui.Paint()..color = const ui.Color(0x14000000),
    );
  }

  void _drawImageFit(
    ui.Canvas canvas,
    ui.Image image,
    ui.Rect bounds,
    String fit,
  ) {
    final src = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    ui.Rect target = bounds;
    if (fit != 'stretch') {
      final double imageRatio = src.width / src.height;
      final double screenRatio = bounds.width / bounds.height;
      double drawW = bounds.width;
      double drawH = bounds.height;
      if (fit == 'fit') {
        if (imageRatio > screenRatio) {
          drawH = bounds.width / imageRatio;
        } else {
          drawW = bounds.height * imageRatio;
        }
      } else {
        // 默认 fill / cover：等比放大后居中裁切。
        if (imageRatio > screenRatio) {
          drawW = bounds.height * imageRatio;
        } else {
          drawH = bounds.width / imageRatio;
        }
      }
      target = ui.Rect.fromLTWH(
        bounds.left + (bounds.width - drawW) / 2,
        bounds.top + (bounds.height - drawH) / 2,
        drawW,
        drawH,
      );
    }
    canvas.drawImageRect(
      image,
      src,
      target,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  void _drawPanel({
    required ui.Canvas canvas,
    required ui.Rect bounds,
    required double scale,
    required MonthData month,
    required AppSettings settings,
    required DateKey today,
  }) {
    const ui.Color primaryText = ui.Color(0xFFF4F6FA);
    const ui.Color secondaryText = ui.Color(0xFFA9B2C4);

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        bounds,
        ui.Radius.circular(20 * scale),
      ),
      ui.Paint()..color = const ui.Color(0xDE10141E),
    );

    final double pad = 24 * scale;
    final double innerLeft = bounds.left + pad;
    final double innerWidth = bounds.width - pad * 2;
    final double titleHeight = 44 * scale;
    final double headerHeight = 30 * scale;
    final double footerHeight = 26 * scale;
    double cursorY = bounds.top + pad;

    _text(
      canvas,
      '${month.anchor.year}年${month.anchor.month}月   企划星 · 桌面日历清单',
      ui.Offset(innerLeft, cursorY),
      innerWidth,
      size: 24 * scale,
      color: primaryText,
      weight: ui.FontWeight.w600,
    );
    cursorY += titleHeight;

    final days = month.columns.isEmpty
        ? const <CalendarDayModel>[]
        : month.columns.first;
    final rows = _clampInt(settings.maxRows, 1, days.length ~/ 7);
    final cellWidth = innerWidth / 7;
    final gridHeight = bounds.height -
        pad * 2 -
        titleHeight -
        headerHeight -
        footerHeight;
    final cellHeight = gridHeight / (rows == 0 ? 1 : rows);

    for (var column = 0; column < 7; column++) {
      final label = column < month.weekdayHeaders.length
          ? month.weekdayHeaders[column]
          : '';
      _text(
        canvas,
        label,
        ui.Offset(innerLeft + column * cellWidth, cursorY),
        cellWidth,
        size: 14 * scale,
        color: secondaryText,
        align: ui.TextAlign.center,
      );
    }
    cursorY += headerHeight;

    final accent = ui.Color(settings.todayBorderColor);
    final holidayColor = ui.Color(settings.holidayTextColor);
    final lunarColor = ui.Color(settings.lunarTextColor);

    for (var index = 0; index < rows * 7 && index < days.length; index++) {
      final day = days[index];
      final double x = innerLeft + (index % 7) * cellWidth;
      final double y = cursorY + (index ~/ 7) * cellHeight;
      final cellRect = ui.Rect.fromLTWH(
        x + 2 * scale,
        y + 2 * scale,
        cellWidth - 4 * scale,
        cellHeight - 4 * scale,
      );
      final isRest = day.meta.isRestDay || day.meta.isMakeupWorkday;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          cellRect,
          ui.Radius.circular(8 * scale),
        ),
        ui.Paint()
          ..color = day.isToday
              ? accent.withAlpha(46)
              : (isRest
                  ? const ui.Color(0x1AFF5F5F)
                  : const ui.Color(0x12FFFFFF)),
      );
      if (day.isToday) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            cellRect,
            ui.Radius.circular(8 * scale),
          ),
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2 * scale
            ..color = accent,
        );
      }

      final numberColor = !day.isCurrentMonth
          ? const ui.Color(0x66A9B2C4)
          : (isRest ? holidayColor : primaryText);
      _text(
        canvas,
        '${day.date.day}',
        ui.Offset(cellRect.left + 8 * scale, cellRect.top + 6 * scale),
        cellWidth * 0.35,
        size: 18 * scale,
        color: numberColor,
        weight: ui.FontWeight.w600,
      );
      final subtitle = day.meta.subtitle(
        showLunar: settings.showLunar,
        showSolarTerms: settings.showSolarTerms,
        showFestival: settings.showFestival,
      );
      if (subtitle.isNotEmpty) {
        _text(
          canvas,
          subtitle,
          ui.Offset(
            cellRect.left + cellWidth * 0.42,
            cellRect.top + 10 * scale,
          ),
          cellWidth * 0.54,
          size: 11 * scale,
          color: lunarColor,
          align: ui.TextAlign.right,
        );
      }

      final lines = _contentLines(day, settings);
      var lineY = cellRect.top + 32 * scale;
      for (final line in lines.take(3)) {
        if (lineY + 14 * scale > cellRect.bottom - 4 * scale) break;
        _text(
          canvas,
          line,
          ui.Offset(cellRect.left + 8 * scale, lineY),
          cellRect.width - 12 * scale,
          size: 11 * scale,
          color: secondaryText,
        );
        lineY += 15 * scale;
      }
    }

    _text(
      canvas,
      '今天 ${today.cnFull} · 周${today.cnWeekday}    数据来自本地日历清单',
      ui.Offset(innerLeft, bounds.bottom - pad - 18 * scale),
      innerWidth,
      size: 12 * scale,
      color: secondaryText,
    );
  }

  List<String> _contentLines(CalendarDayModel day, AppSettings settings) {
    final lines = <String>[];
    final cellLines = day.cell?.lines ?? const <RichLine>[];
    for (final line in cellLines) {
      if (!settings.showCompleted && line.completed) continue;
      if (line.text.trim().isNotEmpty) lines.add(line.text.trim());
    }
    for (final occurrence in day.events) {
      if (settings.showCompleted && occurrence.completed) continue;
      final content = occurrence.event.content.trim();
      if (content.isNotEmpty) lines.add(content);
    }
    for (final item in day.subscriptionEvents) {
      if (item.title.trim().isNotEmpty) lines.add(item.title.trim());
    }
    for (final lesson in day.lessons) {
      if (lesson.name.trim().isNotEmpty) lines.add(lesson.name.trim());
    }
    return lines;
  }

  void _text(
    ui.Canvas canvas,
    String value,
    ui.Offset offset,
    double width, {
    required double size,
    required ui.Color color,
    ui.FontWeight? weight,
    ui.TextAlign align = ui.TextAlign.left,
  }) {
    if (value.isEmpty || width <= 0) return;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: size,
        fontWeight: weight,
        maxLines: 1,
        ellipsis: '…',
        textAlign: align,
      ),
    );
    builder.pushStyle(
      ui.TextStyle(color: color, fontSize: size, fontWeight: weight),
    );
    builder.addText(value);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, offset);
  }

  int _clampInt(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);
}
