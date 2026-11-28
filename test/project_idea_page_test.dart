import 'dart:async';

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/features/auth/application/auth_providers.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_models.dart';
import 'package:planstar_desktop_app/features/auth/domain/auth_repository.dart';
import 'package:planstar_desktop_app/features/auth/presentation/login_page.dart';
import 'package:planstar_desktop_app/features/project_idea/application/project_idea_controller.dart';
import 'package:planstar_desktop_app/features/project_idea/domain/project_idea.dart';
import 'package:planstar_desktop_app/features/project_idea/domain/project_idea_repository.dart';
import 'package:planstar_desktop_app/features/project_idea/presentation/project_idea_detail_page.dart';
import 'package:planstar_desktop_app/features/project_idea/presentation/project_ideas_page.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

final class _Repository implements ProjectIdeaRepository {
  _Repository({required ProjectIdeaDetail detail}) : _detail = detail;

  final ProjectIdeaDetail _detail;
  final List<String?> cursors = <String?>[];
  final List<Result<ProjectIdeaFeedPage>> feeds = <Result<ProjectIdeaFeedPage>>[
    Success<ProjectIdeaFeedPage>(
      ProjectIdeaFeedPage(
        items: <ProjectIdea>[
          ProjectIdea(
            ideaId: 42,
            title: '桌面企划',
            summary: '让桌面企划更易用',
            cover: '',
            categoryId: 1,
            categoryName: '效率',
            creatorName: 'Ada',
            creatorAvatar: '',
            supportCount: 8,
            opposeCount: 2,
            createdAt: _createdAt,
          ),
        ],
        nextCursor: 'next',
        hasMore: true,
      ),
    ),
  ];
  final List<Completer<Result<ProjectIdeaFeedPage>>> pendingFeeds =
      <Completer<Result<ProjectIdeaFeedPage>>>[];
  final List<Map<String, Object?>> votes = <Map<String, Object?>>[];
  Result<IdeaVoteResult> voteResult = const Success<IdeaVoteResult>(
    IdeaVoteResult(
      supportCount: 9,
      opposeCount: 2,
      alreadyVoted: false,
      myVote: IdeaVote(voteType: IdeaVote.support, coinTier: 5),
    ),
  );

  @override
  Future<Result<ProjectIdeaFeedPage>> feed({
    String? cursor,
    int size = 10,
  }) async {
    cursors.add(cursor);
    if (pendingFeeds.isNotEmpty) {
      return pendingFeeds.removeAt(0).future;
    }
    if (feeds.isEmpty) throw StateError('missing feed response');
    return feeds.removeAt(0);
  }

  @override
  Future<Result<ProjectIdeaDetail>> detail(int ideaId) async =>
      Success(_detail);

  @override
  Future<Result<IdeaVoteResult>> vote(
    int ideaId, {
    required int voteType,
    int? coinTier,
    String? reasonCode,
    String? reasonText,
  }) async {
    votes.add(<String, Object?>{
      'ideaId': ideaId,
      'voteType': voteType,
      'coinTier': ?coinTier,
      'reasonCode': ?reasonCode,
      'reasonText': ?reasonText,
    });
    return voteResult;
  }
}

final DateTime _createdAt = DateTime(2026, 11, 20, 12);

final ProjectIdeaDetail _detail = ProjectIdeaDetail(
  ideaId: 42,
  title: '桌面企划',
  summary: '让桌面企划更易用',
  cover: '',
  categoryId: 1,
  categoryName: '效率',
  creatorName: 'Ada',
  creatorAvatar: '',
  supportCount: 8,
  opposeCount: 2,
  createdAt: _createdAt,
  description: '这是一个完整的桌面端创意企划。',
  gallery: const <String>[],
  myVote: null,
  tierDistribution: const IdeaTierDistribution(five: 5, ten: 2, twenty: 1),
  supportRate: 0.8,
  reasonCounts: const <String, int>{'not_interested': 2},
);

final class _AuthRepository implements AuthRepository {
  _AuthRepository(this.session);

  final AuthSession? session;

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<Result<AuthSession>> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  }) async => const Success<AuthSession>(
    AuthSession(
      user: AuthUser(userId: 42, userName: 'Ada'),
      token: 'session',
    ),
  );

  @override
  Future<Result<AuthSession>> loginWithPassword(
    String phone,
    String password, {
    String? captcha,
  }) async => throw UnimplementedError();

  @override
  Future<Result<SendCodeOutcome>> sendLoginCode(
    String phone, {
    String? captcha,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<int>>> fetchCaptchaImage() async =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<Result<AuthUser>> refreshProfile() async => throw UnimplementedError();

  @override
  Future<Result<SignInResult>> fetchSignInStatus() async =>
      const Success<SignInResult>(
        SignInResult(
          signed: false,
          todayReward: 0,
          balance: Money.zero(),
          alreadySigned: false,
        ),
      );

  @override
  Future<Result<SignInResult>> signIn() async => throw UnimplementedError();
}

Future<({ProviderContainer container, GoRouter router, _Repository repository})>
_pump(
  WidgetTester tester, {
  required bool authenticated,
  String initialLocation = '/project-ideas',
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final scope = AppLocalizationScope();
  addTearDown(scope.dispose);
  final repository = _Repository(detail: _detail);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/project-ideas',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: ProjectIdeasPage()),
        routes: <RouteBase>[
          GoRoute(
            path: ':ideaId',
            builder: (BuildContext context, GoRouterState state) =>
                ProjectIdeaDetailPage(
                  ideaId: int.parse(state.pathParameters['ideaId']!),
                ),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginPage(),
      ),
      GoRoute(
        path: '/account',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('account-destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      appLocalizationScopeProvider.overrideWithValue(scope),
      projectIdeaRepositoryProvider.overrideWithValue(repository),
      authRepositoryProvider.overrideWithValue(
        _AuthRepository(
          authenticated
              ? const AuthSession(
                  user: AuthUser(userId: 42, userName: 'Ada'),
                  token: 'session',
                )
              : null,
        ),
      ),
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
  return (container: container, router: router, repository: repository);
}

Future<void> _completeLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('auth.phone')),
    '13800138000',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('auth.code')),
    '123456',
  );
  await tester.tap(find.byKey(const ValueKey<String>('auth.agreement')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('auth.submit')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('idea list loads real page shape and opens detail', (
    WidgetTester tester,
  ) async {
    await _pump(tester, authenticated: false);
    expect(find.byKey(const ValueKey<String>('idea-card-42')), findsOneWidget);
    expect(find.text('桌面企划'), findsOneWidget);
    expect(find.text('支持 8'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('idea-detail-42')),
      findsOneWidget,
    );
    expect(find.text('这是一个完整的桌面端创意企划。'), findsOneWidget);
    expect(find.text('支持率 80%'), findsOneWidget);
  });

  testWidgets('guest voting opens login with a safe return destination', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: false);
    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('idea-support')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    final loginUri = GoRouterState.of(
      tester.element(find.byType(LoginPage)),
    ).uri;
    expect(loginUri.queryParameters['from'], '/project-ideas/42');
    expect(
      result.container.read(projectIdeaPendingVoteProvider),
      const ProjectIdeaPendingVote(
        ideaId: 42,
        intent: ProjectIdeaVoteIntent.support,
      ),
    );
    expect(result.repository.votes, isEmpty);
  });

  testWidgets('cancelling login clears the pending vote intent', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: false);
    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('idea-support')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.byTooltip('返回账号页'));
    await tester.pumpAndSettle();

    expect(result.container.read(projectIdeaPendingVoteProvider), isNull);
    expect(result.repository.votes, isEmpty);
  });

  testWidgets('a pending vote never resumes on a different idea', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: true);
    result.container
        .read(projectIdeaPendingVoteProvider.notifier)
        .set(
          const ProjectIdeaPendingVote(
            ideaId: 99,
            intent: ProjectIdeaVoteIntent.support,
          ),
        );
    result.router.go('/project-ideas/42');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('support-submit')), findsNothing);
    expect(result.container.read(projectIdeaPendingVoteProvider)?.ideaId, 99);
    expect(result.repository.votes, isEmpty);
  });

  testWidgets('successful login resumes the pending support dialog', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: false);
    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('idea-support')));
    await tester.pumpAndSettle();
    expect(
      result.container.read(projectIdeaPendingVoteProvider),
      const ProjectIdeaPendingVote(
        ideaId: 42,
        intent: ProjectIdeaVoteIntent.support,
      ),
    );

    await _completeLogin(tester);

    expect(
      find.byKey(const ValueKey<String>('idea-detail-42')),
      findsOneWidget,
    );
    expect(result.container.read(projectIdeaPendingVoteProvider), isNull);
    expect(
      find.byKey(const ValueKey<String>('support-submit')),
      findsOneWidget,
    );
    expect(result.repository.votes, isEmpty);
  });

  testWidgets('support submits tier and reason then updates my vote', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: true);
    result.repository.voteResult = const Success<IdeaVoteResult>(
      IdeaVoteResult(
        supportCount: 9,
        opposeCount: 2,
        alreadyVoted: false,
        myVote: IdeaVote(voteType: IdeaVote.support, coinTier: 10),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('idea-support')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('support-disclaimer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('support-tier-10')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('support-reason-field')),
      '愿意参与',
    );
    await tester.tap(find.byKey(const ValueKey<String>('support-submit')));
    await tester.pumpAndSettle();

    expect(result.repository.votes.single, <String, Object?>{
      'ideaId': 42,
      'voteType': IdeaVote.support,
      'coinTier': 10,
      'reasonText': '愿意参与',
    });
    expect(find.byKey(const ValueKey<String>('idea-my-vote')), findsOneWidget);
    expect(find.text('已记录你的支持意愿'), findsOneWidget);
    expect(find.text('支持 9'), findsOneWidget);
    expect(find.text('支持率 82%'), findsOneWidget);
    final detail = result.container.read(projectIdeaDetailProvider(42)).detail!;
    expect(detail.tierDistribution.ten, 3);
  });

  testWidgets('logout clears the previous account vote from idea detail', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: true);
    result.repository.voteResult = const Success<IdeaVoteResult>(
      IdeaVoteResult(
        supportCount: 9,
        opposeCount: 2,
        alreadyVoted: false,
        myVote: IdeaVote(voteType: IdeaVote.support, coinTier: 5),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('idea-support')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('support-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('idea-my-vote')), findsOneWidget);

    await result.container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('idea-my-vote')), findsNothing);
    expect(
      result.container.read(projectIdeaDetailProvider(42)).detail?.myVote,
      isNull,
    );
  });

  testWidgets('opposition requires a reason and submits its backend code', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: true);
    result.repository.voteResult = const Success<IdeaVoteResult>(
      IdeaVoteResult(
        supportCount: 8,
        opposeCount: 3,
        alreadyVoted: false,
        myVote: IdeaVote(
          voteType: IdeaVote.oppose,
          reasonCode: 'not_enough_info',
          reasonText: '请补充执行计划',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('idea-oppose')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('oppose-submit')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('oppose-reason-not_enough_info')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('oppose-reason-field')),
      '请补充执行计划',
    );
    await tester.tap(find.byKey(const ValueKey<String>('oppose-submit')));
    await tester.pumpAndSettle();

    expect(result.repository.votes.single, <String, Object?>{
      'ideaId': 42,
      'voteType': IdeaVote.oppose,
      'reasonCode': 'not_enough_info',
      'reasonText': '请补充执行计划',
    });
    expect(find.text('我已提交反对意见'), findsOneWidget);
    expect(find.text('已提交你的反对意见'), findsOneWidget);
    expect(find.text('支持率 73%'), findsOneWidget);
    final detail = result.container.read(projectIdeaDetailProvider(42)).detail!;
    expect(detail.reasonCounts['not_enough_info'], 1);
  });

  testWidgets('other opposition reason requires custom text', (
    WidgetTester tester,
  ) async {
    final result = await _pump(tester, authenticated: true);
    await tester.tap(find.byKey(const ValueKey<String>('idea-card-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('idea-oppose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('oppose-reason-other')));
    await tester.pump();

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('oppose-submit')),
    );
    expect(submit.onPressed, isNull);
    expect(find.text('选择“其他原因”时请填写说明'), findsOneWidget);
    expect(result.repository.votes, isEmpty);
  });

  testWidgets('failed next page keeps loaded ideas and exposes retry state', (
    WidgetTester tester,
  ) async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final result = await _pump(tester, authenticated: false);
    result.repository.feeds.add(
      const Fail<ProjectIdeaFeedPage>(
        Failure(
          code: 'NETWORK_ERROR',
          message: 'diagnostic-only',
          type: FailureType.network,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '加载更多'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('idea-card-42')), findsOneWidget);
    expect(find.text(scope.localizations.failureNetwork), findsOneWidget);
    expect(find.text('diagnostic-only'), findsNothing);
  });

  for (final unsafeFrom in <String>[
    'https://example.test/project-ideas/42',
    '//example.test/project-ideas/42',
    r'/project-ideas/42\evil',
    '/wallet',
  ]) {
    testWidgets('login rejects unsafe return destination $unsafeFrom', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        authenticated: false,
        initialLocation: '/login?from=${Uri.encodeQueryComponent(unsafeFrom)}',
      );
      await _completeLogin(tester);
      expect(find.text('account-destination'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('idea-detail-42')),
        findsNothing,
      );
    });
  }

  test('refresh invalidates an older load-more response', () async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final repository = _Repository(detail: _detail);
    final stalePage = Completer<Result<ProjectIdeaFeedPage>>();
    final refreshedPage = Completer<Result<ProjectIdeaFeedPage>>();
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(scope),
        projectIdeaRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(projectIdeaFeedProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(projectIdeaFeedProvider).items.map((idea) => idea.ideaId),
      <int>[42],
    );
    repository.pendingFeeds.addAll(<Completer<Result<ProjectIdeaFeedPage>>>[
      stalePage,
      refreshedPage,
    ]);
    final controller = container.read(projectIdeaFeedProvider.notifier);

    final loadingMore = controller.loadMore();
    final refreshing = controller.loadInitial();
    expect(repository.cursors, <String?>[null, 'next', null]);
    expect(container.read(projectIdeaFeedProvider).loading, isTrue);
    refreshedPage.complete(
      Success<ProjectIdeaFeedPage>(
        ProjectIdeaFeedPage(
          items: <ProjectIdea>[
            ProjectIdea.fromJson(<String, Object?>{'ideaId': 99}),
          ],
          nextCursor: 'fresh-cursor',
          hasMore: false,
        ),
      ),
    );
    await refreshing;
    expect(
      container.read(projectIdeaFeedProvider).items.map((idea) => idea.ideaId),
      <int>[99],
    );
    stalePage.complete(
      Success<ProjectIdeaFeedPage>(
        ProjectIdeaFeedPage(
          items: <ProjectIdea>[
            ProjectIdea.fromJson(<String, Object?>{'ideaId': 100}),
          ],
          nextCursor: 'stale-cursor',
          hasMore: true,
        ),
      ),
    );
    await loadingMore;

    final state = container.read(projectIdeaFeedProvider);
    expect(state.items.map((ProjectIdea idea) => idea.ideaId), <int>[99]);
    expect(state.cursor, 'fresh-cursor');
    expect(state.loadingMore, isFalse);
    expect(state.hasMore, isFalse);
  });

  test('pagination deduplicates ids and stops after an empty page', () async {
    final scope = AppLocalizationScope();
    addTearDown(scope.dispose);
    final repository = _Repository(detail: _detail)
      ..feeds.addAll(<Result<ProjectIdeaFeedPage>>[
        Success<ProjectIdeaFeedPage>(
          ProjectIdeaFeedPage(
            items: <ProjectIdea>[
              ProjectIdea(
                ideaId: 42,
                title: '重复企划',
                summary: '',
                cover: '',
                categoryId: 1,
                categoryName: '',
                creatorName: '',
                creatorAvatar: '',
                supportCount: 0,
                opposeCount: 0,
                createdAt: _createdAt,
              ),
              ProjectIdea(
                ideaId: 43,
                title: '新企划',
                summary: '',
                cover: '',
                categoryId: 1,
                categoryName: '',
                creatorName: '',
                creatorAvatar: '',
                supportCount: 0,
                opposeCount: 0,
                createdAt: _createdAt,
              ),
            ],
            nextCursor: 'third',
            hasMore: true,
          ),
        ),
        const Success<ProjectIdeaFeedPage>(
          ProjectIdeaFeedPage(
            items: <ProjectIdea>[],
            nextCursor: null,
            hasMore: true,
          ),
        ),
      ]);
    final container = ProviderContainer(
      overrides: [
        appLocalizationScopeProvider.overrideWithValue(scope),
        projectIdeaRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(projectIdeaFeedProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(projectIdeaFeedProvider.notifier);

    await controller.loadMore();
    expect(
      container.read(projectIdeaFeedProvider).items.map((idea) => idea.ideaId),
      <int>[42, 43],
    );
    expect(container.read(projectIdeaFeedProvider).hasMore, isTrue);
    await controller.loadMore();
    expect(container.read(projectIdeaFeedProvider).hasMore, isFalse);
    await controller.loadMore();
    expect(repository.cursors, <String?>[null, 'next', 'third']);
  });
}
