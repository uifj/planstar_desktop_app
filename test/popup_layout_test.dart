import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/windows/popup_layout.dart';

void main() {
  const screen = Size(1920, 1080);

  test('格子在左侧时浮层放到右侧并与格子顶部对齐', () {
    final rect = computeDesktopPopupRect(
      const Rect.fromLTWH(100, 100, 140, 105),
      screen,
    );
    expect(rect.left, 246);
    expect(rect.top, 100);
    expect(rect.width, 268);
    expect(rect.height, 368);
  });

  test('右侧空间不足时翻到格子左侧', () {
    final rect = computeDesktopPopupRect(
      const Rect.fromLTWH(1800, 100, 100, 105),
      screen,
    );
    expect(rect.left, 1526);
    expect(rect.right, lessThan(screen.width));
  });

  test('最底行浮层向上夹紧，不越出屏幕', () {
    final rect = computeDesktopPopupRect(
      const Rect.fromLTWH(100, 1000, 140, 60),
      screen,
    );
    expect(rect.top, 704);
    expect(rect.bottom, lessThanOrEqualTo(screen.height));
  });

  group('桌面双击判定', () {
    final now = DateTime(2026, 11, 16, 12, 0, 0);
    const a = '2026-11-16';
    const b = '2026-11-17';

    test('同一格 200ms 内再次点击算双击', () {
      expect(
        isDesktopDoubleTap(
          now.add(const Duration(milliseconds: 200)),
          now,
          a,
          a,
        ),
        isTrue,
      );
    });

    test('超过 350ms 不算双击', () {
      expect(
        isDesktopDoubleTap(
          now.add(const Duration(milliseconds: 500)),
          now,
          a,
          a,
        ),
        isFalse,
      );
    });

    test('不同格子不算双击', () {
      expect(
        isDesktopDoubleTap(
          now.add(const Duration(milliseconds: 100)),
          now,
          a,
          b,
        ),
        isFalse,
      );
    });

    test('没有上一次点击不算双击', () {
      expect(isDesktopDoubleTap(now, null, a, a), isFalse);
    });
  });

  test('负坐标或极小屏幕也返回屏幕内的有效矩形', () {
    final rect = computeDesktopPopupRect(
      const Rect.fromLTWH(-500, -200, 140, 105),
      const Size(300, 250),
    );
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.width, 268);
    expect(rect.height, 368);
  });
}
