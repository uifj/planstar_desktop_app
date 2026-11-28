import 'dart:async';

import 'package:core/result.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/features/catalog/application/catalog_controller.dart';
import 'package:planstar_desktop_app/features/catalog/domain/project_repository.dart';
import 'package:planstar_desktop_app/features/catalog/domain/show_summary.dart';
import 'package:planstar_desktop_app/features/catalog/presentation/project_detail_page.dart';
import 'package:planstar_desktop_app/features/catalog/presentation/projects_page.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

final class _Repository implements ProjectRepository {
  _Repository({required this.detail});

  final ShowSummary detail;
  final List<Result<List<ShowCategory>>> categoryResults =
      <Result<List<ShowCategory>>>[
        const Success<List<ShowCategory>>(<ShowCategory>[
          ShowCategory(
            id: 1,
            name: '剧场',
            enName: 'Theatre',
            pinyin: 'juchang',
            subTags: <SubCategoryTag>[],
          ),
        ]),
      ];
  final List<Result<List<ShowSummary>>> projectResults =
      <Result<List<ShowSummary>>>[
        const Success<List<ShowSummary>>(<ShowSummary>[]),
      ];
  final List<Completer<Result<List<ShowSummary>>>> pendingProjects =
      <Completer<Result<List<ShowSummary>>>>[];
  final List<Result<ShowSummary>> detailResults = <Result<ShowSummary>>[];
  final List<({int? categoryId, ProjectSort sort, int page})> queries =
      <({int? categoryId, ProjectSort sort, int page})>[];

  @override
  Future<Result<List<ShowCategory>>> categories() async {
    if (categoryResults.isEmpty) {
      throw StateError('missing categories response');
    }
    return categoryResults.removeAt(0);
  }

  @override
  Future<Result<List<ShowSummary>>> projects({
    int? categoryId,
    ProjectSort sort = ProjectSort.recommended,
    int page = 1,
    int pageSize = 20,
  }) async {
    queries.add((categoryId: categoryId, sort: sort, page: page));
    if (pendingProjects.isNotEmpty) {
      return pendingProjects.removeAt(0).future;
    }
    if (projectResults.isEmpty) {
      throw StateError('missing projects response');
    }
    return projectResults.removeAt(0);
  }

  @override
  Future<Result<ShowSummary>> projectDetail(String id) async {
    if (detailResults.isEmpty) return Success<ShowSummary>(detail);
    return detailResults.removeAt(0);
  }
}

ShowSummary _show(String id, {String title = '星海音乐会'}) =>
    ShowSummary.fromJson(<String, Object?>{
      'id': id,
      'title': title,
      'summary': '让好企划在桌面继续生长',
      'artist': 'Ada',
      'categoryId': 1,
      'categoryName': '剧场',
      'city': '上海',
      'venue': '星海剧场',
      'venueAddress': '上海市浦东新区',
      'firstSessionAt': '2026-12-01T12:00:00',
      'priceFrom': 68000,
      'goalAmount': 100000,
      'raisedAmount': 128000,
      'supporterCount': 24,
      'deadline': '2026-12-20T12:00:00',
      'intro': '这是一个完整的桌面端企划故事。',
      'tiers': <Object?>[
        <String, Object?>{
          'name': '早鸟档',
          'price': 68000,
          'items': <Object?>['演出票一张'],
          'estimatedDeliveryTime': '演出前邮寄',
        },
      ],
      'updates': <Object?>[
        <String, Object?>{
          'title': '筹备进展',
          'content': '舞台方案已经确认。',
          'publishTime': '2026-11-20T10:00:00',
        },
      ],
      'riskNote': '请仔细阅读风险说明。',
      'deliveryPlan': '将在演出前统一寄出。',
      'fundUsage': '用于舞台制作与演出执行。',
      'refundRule': '支持按规则申请退款。',
      'reviews': <Object?>[
        <String, Object?>{
          'userName': '观众',
          'rating': 5,
          'content': '值得支持',
          'isShow': true,
        },
      ],
      'faqs': <Object?>[
        <String, Object?>{'question': '何时演出？', 'answer': '十二月一日。'},
      ],
      'creatorBio': '持续创作优秀舞台作品。',
      'creatorProjectNum': 3,
      'purchaseNotice': <Object?>['请确认档位与配送信息。'],
    });

List<ShowSummary> _fullPage() => List<ShowSummary>.generate(
  20,
  (int index) => _show('${index + 1}', title: '企划 ${index + 1}'),
  growable: false,
);

Future<void> _pump(WidgetTester tester, _Repository repository) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final scope = AppLocalizationScope();
  addTearDown(scope.dispose);
  final router = GoRouter(
    initialLocation: '/projects',
    routes: <RouteBase>[
      GoRoute(
        path: '/projects',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: ProjectsPage()),
        routes: <RouteBase>[
          GoRoute(
            path: ':showId',
            builder: (BuildContext context, GoRouterState state) =>
                ProjectDetailPage(
                  id: state.pathParameters['showId']!,
                  initial: state.extra is ShowSummary
                      ? state.extra as ShowSummary
                      : null,
                ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      appLocalizationScopeProvider.overrideWithValue(scope),
      projectRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: scope.value,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: supportedLocales,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('catalog filters and sorting use server-side query parameters', (
    WidgetTester tester,
  ) async {
    final repository = _Repository(detail: _show('show-7'))
      ..projectResults.addAll(<Result<List<ShowSummary>>>[
        const Success<List<ShowSummary>>(<ShowSummary>[]),
        const Success<List<ShowSummary>>(<ShowSummary>[]),
      ]);
    await _pump(tester, repository);
    expect(repository.queries.single.categoryId, isNull);
    expect(repository.queries.single.sort, ProjectSort.recommended);

    await tester.tap(find.widgetWithText(ChoiceChip, '剧场'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.categoryId, 1);

    await tester.tap(find.byType(DropdownButton<ProjectSort>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最新').last);
    await tester.pumpAndSettle();
    expect(repository.queries.last.categoryId, 1);
    expect(repository.queries.last.sort, ProjectSort.newest);
  });

  testWidgets('project card opens read-only detail with server data', (
    WidgetTester tester,
  ) async {
    final detail = _show('show-7');
    final repository = _Repository(detail: detail);
    repository.projectResults[0] = Success<List<ShowSummary>>(<ShowSummary>[
      detail,
    ]);
    await _pump(tester, repository);
    expect(
      find.byKey(const ValueKey<String>('project-card-show-7')),
      findsOneWidget,
    );
    expect(find.text('已筹 128%'), findsOneWidget);
    expect(find.text('星币 680'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('project-card-show-7')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('project-detail-show-7')),
      findsOneWidget,
    );
    expect(find.text('当前为只读预览，桌面端暂不支持支付、选座和创建订单。'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('早鸟档'), 300);
    expect(find.text('早鸟档'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('这是一个完整的桌面端企划故事。'), 300);
    expect(find.text('这是一个完整的桌面端企划故事。'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('何时演出？'), 300);
    expect(find.text('何时演出？'), findsOneWidget);
    expect(find.text('立即支持'), findsNothing);
    expect(find.text('选座'), findsNothing);
  });

  testWidgets('detail keeps list fallback visible when refresh fails', (
    WidgetTester tester,
  ) async {
    final detail = _show('show-7');
    final repository = _Repository(detail: detail)
      ..projectResults[0] = Success<List<ShowSummary>>(<ShowSummary>[detail])
      ..detailResults.add(
        const Fail<ShowSummary>(
          Failure(
            code: 'NETWORK_ERROR',
            message: 'diagnostic-only',
            type: FailureType.network,
          ),
        ),
      );
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey<String>('project-card-show-7')));
    await tester.pumpAndSettle();

    expect(find.text('星海音乐会'), findsOneWidget);
    expect(find.text('网络连接失败，请检查网络后重试。'), findsOneWidget);
    expect(find.text('diagnostic-only'), findsNothing);
  });

  test('pagination deduplicates ids and stops after a short page', () async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final duplicate = _show('1', title: '重复页');
    final second = _show('21', title: '第二页');
    final repository = _Repository(detail: _show('detail'))
      ..projectResults.clear()
      ..projectResults.addAll(<Result<List<ShowSummary>>>[
        Success<List<ShowSummary>>(_fullPage()),
        Success<List<ShowSummary>>(<ShowSummary>[duplicate, second]),
        const Success<List<ShowSummary>>(<ShowSummary>[]),
      ]);
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(scope),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final query = const ProjectListQuery();
    final subscription = container.listen(
      projectListProvider(query),
      (_, _) {},
    );
    addTearDown(subscription.close);
    container.read(projectListProvider(query));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repository.queries.map((query) => query.page), <int>[1]);
    final controller = container.read(projectListProvider(query).notifier);

    await controller.loadMore();
    final items = container.read(projectListProvider(query)).items;
    expect(items.length, 21);
    expect(items.first.id, '1');
    expect(items.last.id, '21');
    expect(items.map((ShowSummary show) => show.id).toSet().length, 21);
    expect(container.read(projectListProvider(query)).hasMore, isFalse);
    await controller.loadMore();
    expect(repository.queries.map((query) => query.page), <int>[1, 2]);
  });

  test('refresh invalidates an older load-more response', () async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final repository = _Repository(detail: _show('detail'))
      ..projectResults[0] = Success<List<ShowSummary>>(_fullPage());
    final stalePage = Completer<Result<List<ShowSummary>>>();
    final refreshedPage = Completer<Result<List<ShowSummary>>>();
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(scope),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    const query = ProjectListQuery();
    final subscription = container.listen(projectListProvider(query), (_, _) {});
    addTearDown(subscription.close);
    container.read(projectListProvider(query));
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(projectListProvider(query)).loading, isFalse);
    expect(container.read(projectListProvider(query)).items, hasLength(20));
    repository.pendingProjects.addAll(<Completer<Result<List<ShowSummary>>>>[
      stalePage,
      refreshedPage,
    ]);
    final controller = container.read(projectListProvider(query).notifier);

    final loadingMore = controller.loadMore();
    final refreshing = controller.loadInitial();
    expect(repository.queries.map((query) => query.page), <int>[1, 2, 1]);
    expect(container.read(projectListProvider(query)).loading, isTrue);
    refreshedPage.complete(
      Success<List<ShowSummary>>(<ShowSummary>[_show('fresh')]),
    );
    await refreshing;
    expect(
      container.read(projectListProvider(query)).items.map((show) => show.id),
      <String>['fresh'],
    );
    stalePage.complete(
      Success<List<ShowSummary>>(<ShowSummary>[_show('stale')]),
    );
    await loadingMore;

    final state = container.read(projectListProvider(query));
    expect(state.items.map((ShowSummary show) => show.id), <String>['fresh']);
    expect(state.loadingMore, isFalse);
    expect(state.hasMore, isFalse);
  });

  test('load-more failure preserves projects and allows retry', () async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final repository = _Repository(detail: _show('detail'))
      ..projectResults.clear()
      ..projectResults.addAll(<Result<List<ShowSummary>>>[
        Success<List<ShowSummary>>(_fullPage()),
        const Fail<List<ShowSummary>>(
          Failure(
            code: 'NETWORK_ERROR',
            message: 'diagnostic-only',
            type: FailureType.network,
          ),
        ),
        const Success<List<ShowSummary>>(<ShowSummary>[]),
      ]);
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(scope),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final query = const ProjectListQuery();
    final subscription = container.listen(
      projectListProvider(query),
      (_, _) {},
    );
    addTearDown(subscription.close);
    container.read(projectListProvider(query));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repository.queries.map((query) => query.page), <int>[1]);
    final controller = container.read(projectListProvider(query).notifier);

    await controller.loadMore();
    final items = container.read(projectListProvider(query)).items;
    expect(items.length, 20);
    expect(items.first.id, '1');
    expect(container.read(projectListProvider(query)).hasMore, isTrue);
    expect(
      container.read(projectListProvider(query)).error,
      '网络连接失败，请检查网络后重试。',
    );

    await controller.loadMore();
    expect(container.read(projectListProvider(query)).hasMore, isFalse);
    expect(repository.queries.map((query) => query.page), <int>[1, 2, 2]);
  });
}
