/// 回归：主窗口分支路由（StatefulShellRoute.indexedStack）的内容必须真正完成布局。
///
/// 现象：桌面运行时分支 Navigator 的 Overlay 路由子树永远停在 size: MISSING，
/// 日历内容区整块空白；根 Navigator 的路由却正常。本用例在测试环境复现同一
/// 结构（真实 AppTheme + indexedStack 分支 + GridView 内容），断言内容拿到尺寸。
library;

import 'package:core_design_system/core_design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

Widget _gridPage() => GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 7,
  ),
  itemCount: 42,
  itemBuilder: (BuildContext context, int index) =>
      Center(child: Text('$index')),
);

GoRouter _router() => GoRouter(
  initialLocation: '/calendar',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        body: Row(
          children: <Widget>[
            const SizedBox(width: 80),
            Expanded(child: shell),
          ],
        ),
      ),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/calendar',
              builder: (context, state) => _gridPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/notes',
              builder: (context, state) => const Text('notes'),
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('分支路由内容完成布局（真实 AppTheme）', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: _router(),
          builder: (BuildContext context, Widget? child) =>
              AppTheme.withAppFont(context, Stack(children: <Widget>[?child])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    final Size size = tester.getSize(find.byType(GridView));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
    expect(find.text('0'), findsOneWidget);
  });
}
