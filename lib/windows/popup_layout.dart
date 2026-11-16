/// 桌面浮层编辑器的定位策略（纯函数，便于单元测试）。
library;

import 'dart:ui' show Rect, Size;

/// [cell] 是被编辑格子在 overlay 窗口坐标系（逻辑像素）中的矩形，
/// [screen] 是可用屏幕范围。
///
/// 优先把浮层放在格子右侧，空间不足时翻到左侧，最后整体夹进屏幕，
/// 避免最右列 / 最底行的弹窗越界后被 `SetWindowRgn` 裁到点不到。
Rect computeDesktopPopupRect(
  Rect cell,
  Size screen, {
  double width = 268,
  double height = 368,
  double gap = 6,
  double margin = 8,
}) {
  var x = cell.right + gap;
  if (x + width > screen.width) {
    x = cell.left - width - gap;
  }
  final maxX = screen.width - width - margin;
  final maxY = screen.height - height - margin;
  x = x.clamp(margin, maxX > margin ? maxX : margin).toDouble();
  final y = cell.top.clamp(margin, maxY > margin ? maxY : margin).toDouble();
  return Rect.fromLTWH(x, y, width, height);
}

/// 桌面鼠标下 `GestureDetector.onDoubleTap` 常与 `onTap` 竞争失败，
/// 因此由 `_onCellTap` 自己按「同一格 + 短时间内两次点击」判定双击。
bool isDesktopDoubleTap(
  DateTime now,
  DateTime? lastTapAt,
  Object? lastTapKey,
  Object? key, {
  Duration timeout = const Duration(milliseconds: 350),
}) =>
    lastTapAt != null &&
    lastTapKey == key &&
    now.difference(lastTapAt) < timeout;
