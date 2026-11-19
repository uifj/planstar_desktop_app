import 'package:core_design_system/core_design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Row 给非 flex 子节点的宽度约束是无限的。按钮主题的 minimumSize 若用
  // Size.fromHeight，minWidth 就是 infinity，经 ConstrainedBox.enforce 后
  // 变成「紧约束无限宽」，子树布局抛异常；RenderObject.layout 捕获异常后仍把
  // _needsLayout 置 false，整条路由子树永远停在 size: MISSING（内容区空白）。
  testWidgets('Row 内的 OutlinedButton 能完成布局', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: <Widget>[
              OutlinedButton(onPressed: () {}, child: const Text('今天')),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final Size size = tester.getSize(find.byType(OutlinedButton));
    expect(size.width.isFinite, isTrue);
    expect(size.height.isFinite, isTrue);
  });

  testWidgets('Row 内的 FilledButton 能完成布局', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: <Widget>[
              FilledButton(onPressed: () {}, child: const Text('新建任务')),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final Size size = tester.getSize(find.byType(FilledButton));
    expect(size.width.isFinite, isTrue);
    expect(size.height.isFinite, isTrue);
  });
}
