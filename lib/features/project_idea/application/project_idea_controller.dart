library;

import 'dart:async';

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../l10n/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/auth_state.dart';
import '../data/planstar_project_idea_api.dart';
import '../data/remote_project_idea_repository.dart';
import '../domain/project_idea.dart';
import '../domain/project_idea_repository.dart';

final projectIdeaApiProvider = Provider<PlanstarProjectIdeaApi>(
  (Ref ref) =>
      PlanstarProjectIdeaApi(client: ref.watch(planstarApiClientProvider)),
);

final projectIdeaRepositoryProvider = Provider<ProjectIdeaRepository>(
  (Ref ref) =>
      RemoteProjectIdeaRepository(api: ref.watch(projectIdeaApiProvider)),
);

final class ProjectIdeaFeedState {
  const ProjectIdeaFeedState({
    this.items = const <ProjectIdea>[],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final List<ProjectIdea> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? cursor;
  final String? error;

  ProjectIdeaFeedState copyWith({
    List<ProjectIdea>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? cursor = _unset,
    Object? error = _unset,
  }) => ProjectIdeaFeedState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    cursor: identical(cursor, _unset) ? this.cursor : cursor as String?,
    error: identical(error, _unset) ? this.error : error as String?,
  );
}

const Object _unset = Object();

final class ProjectIdeaFeedController extends Notifier<ProjectIdeaFeedState> {
  static const int pageSize = 10;
  int _requestRevision = 0;
  bool _disposed = false;

  @override
  ProjectIdeaFeedState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(Future<void>.microtask(() => _loadInitial(initial: true)));
    return const ProjectIdeaFeedState(loading: true);
  }

  Future<void> loadInitial() => _loadInitial(initial: false);

  Future<void> _loadInitial({required bool initial}) async {
    if (_disposed || (!initial && state.loading)) return;
    final revision = ++_requestRevision;
    state = state.copyWith(loading: true, error: null);
    final result = await ref
        .read(projectIdeaRepositoryProvider)
        .feed(size: pageSize);
    if (_disposed || revision != _requestRevision) return;
    switch (result) {
      case Success<ProjectIdeaFeedPage>(:final data):
        state = ProjectIdeaFeedState(
          items: data.items,
          hasMore: data.hasMore,
          cursor: data.nextCursor,
        );
      case Fail<ProjectIdeaFeedPage>(:final failure):
        state = state.copyWith(loading: false, error: _label(failure));
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final revision = _requestRevision;
    final cursor = state.cursor;
    state = state.copyWith(loadingMore: true, error: null);
    final result = await ref
        .read(projectIdeaRepositoryProvider)
        .feed(cursor: cursor, size: pageSize);
    if (_disposed || revision != _requestRevision) return;
    switch (result) {
      case Success<ProjectIdeaFeedPage>(:final data):
        final existing = state.items
            .map((ProjectIdea idea) => idea.ideaId)
            .toSet();
        final additions = data.items
            .where((ProjectIdea idea) => existing.add(idea.ideaId))
            .toList(growable: false);
        state = state.copyWith(
          items: <ProjectIdea>[...state.items, ...additions],
          loadingMore: false,
          hasMore: data.hasMore && data.items.isNotEmpty,
          cursor: data.nextCursor,
        );
      case Fail<ProjectIdeaFeedPage>(:final failure):
        state = state.copyWith(loadingMore: false, error: _label(failure));
    }
  }

  String _label(Failure failure) => failureLabel(
    failure,
    ref.read(appLocalizationScopeProvider).localizations,
  );
}

final projectIdeaFeedProvider =
    NotifierProvider<ProjectIdeaFeedController, ProjectIdeaFeedState>(
      ProjectIdeaFeedController.new,
    );

final class ProjectIdeaDetailState {
  const ProjectIdeaDetailState({
    this.detail,
    this.loading = true,
    this.submitting = false,
    this.error,
  });

  final ProjectIdeaDetail? detail;
  final bool loading;
  final bool submitting;
  final String? error;

  ProjectIdeaDetailState copyWith({
    ProjectIdeaDetail? detail,
    bool? loading,
    bool? submitting,
    Object? error = _unset,
  }) => ProjectIdeaDetailState(
    detail: detail ?? this.detail,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    error: identical(error, _unset) ? this.error : error as String?,
  );
}

final class ProjectIdeaDetailController
    extends Notifier<ProjectIdeaDetailState> {
  ProjectIdeaDetailController(this.ideaId);

  final int ideaId;
  bool _disposed = false;
  int _requestRevision = 0;

  @override
  ProjectIdeaDetailState build() {
    _disposed = false;
    ref.watch(
      authControllerProvider.select(
        (AuthState auth) => auth.isLoggedIn ? auth.user?.userId : null,
      ),
    );
    ref.onDispose(() => _disposed = true);
    _requestRevision++;
    unawaited(Future<void>.microtask(load));
    return const ProjectIdeaDetailState();
  }

  Future<void> load() async {
    if (_disposed || (state.loading && state.detail != null)) return;
    final revision = ++_requestRevision;
    state = state.copyWith(loading: true, error: null);
    final result = await ref.read(projectIdeaRepositoryProvider).detail(ideaId);
    if (_disposed || revision != _requestRevision) return;
    switch (result) {
      case Success<ProjectIdeaDetail>(:final data):
        state = ProjectIdeaDetailState(detail: data);
      case Fail<ProjectIdeaDetail>(:final failure):
        state = state.copyWith(loading: false, error: _label(failure));
    }
  }

  Future<Result<IdeaVoteResult>> support({int tier = 5, String? reason}) =>
      _submit(
        () async {
          if (!ref.read(authControllerProvider).isLoggedIn) {
            return const Fail<IdeaVoteResult>(
              Failure(
                code: 'LOGIN_REQUIRED',
                message: 'LOGIN_REQUIRED',
                type: FailureType.authentication,
              ),
            );
          }
          return ref
              .read(projectIdeaRepositoryProvider)
              .vote(
                ideaId,
                voteType: IdeaVote.support,
                coinTier: tier,
                reasonText: reason,
              );
        },
        fallback: IdeaVote(
          voteType: IdeaVote.support,
          coinTier: tier,
          reasonText: reason,
        ),
      );

  Future<Result<IdeaVoteResult>> oppose({
    required String reasonCode,
    String? reasonText,
  }) => _submit(
    () async {
      if (!ref.read(authControllerProvider).isLoggedIn) {
        return const Fail<IdeaVoteResult>(
          Failure(
            code: 'LOGIN_REQUIRED',
            message: 'LOGIN_REQUIRED',
            type: FailureType.authentication,
          ),
        );
      }
      return ref
          .read(projectIdeaRepositoryProvider)
          .vote(
            ideaId,
            voteType: IdeaVote.oppose,
            reasonCode: reasonCode,
            reasonText: reasonText,
          );
    },
    fallback: IdeaVote(
      voteType: IdeaVote.oppose,
      reasonCode: reasonCode,
      reasonText: reasonText,
    ),
  );

  Future<Result<IdeaVoteResult>> _submit(
    Future<Result<IdeaVoteResult>> Function() action, {
    required IdeaVote fallback,
  }) async {
    if (state.submitting) {
      return const Fail<IdeaVoteResult>(
        Failure(
          code: 'VOTE_IN_PROGRESS',
          message: 'VOTE_IN_PROGRESS',
          type: FailureType.validation,
        ),
      );
    }
    final revision = _requestRevision;
    state = state.copyWith(submitting: true, error: null);
    final result = await action();
    if (_disposed || revision != _requestRevision) return result;
    switch (result) {
      case Success<IdeaVoteResult>(:final data):
        final current = state.detail;
        if (current != null) {
          final vote = data.myVote ?? fallback;
          state = state.copyWith(
            detail: current.withVoteResult(
              IdeaVoteResult(
                supportCount: data.supportCount,
                opposeCount: data.opposeCount,
                alreadyVoted: data.alreadyVoted,
                myVote: vote,
                tierDistribution: data.tierDistribution,
                supportRate: data.supportRate,
                reasonCounts: data.reasonCounts,
              ),
            ),
            submitting: false,
          );
        } else {
          state = state.copyWith(submitting: false);
        }
      case Fail<IdeaVoteResult>(:final failure):
        state = state.copyWith(submitting: false, error: _label(failure));
    }
    return result;
  }

  String _label(Failure failure) => failureLabel(
    failure,
    ref.read(appLocalizationScopeProvider).localizations,
  );
}

final projectIdeaDetailProvider = NotifierProvider.autoDispose
    .family<ProjectIdeaDetailController, ProjectIdeaDetailState, int>(
      ProjectIdeaDetailController.new,
    );

enum ProjectIdeaVoteIntent { support, oppose }

final class ProjectIdeaPendingVote {
  const ProjectIdeaPendingVote({required this.ideaId, required this.intent});

  final int ideaId;
  final ProjectIdeaVoteIntent intent;

  @override
  bool operator ==(Object other) =>
      other is ProjectIdeaPendingVote &&
      ideaId == other.ideaId &&
      intent == other.intent;

  @override
  int get hashCode => Object.hash(ideaId, intent);
}

final projectIdeaPendingVoteProvider =
    NotifierProvider<ProjectIdeaPendingVoteController, ProjectIdeaPendingVote?>(
      ProjectIdeaPendingVoteController.new,
    );

final class ProjectIdeaPendingVoteController
    extends Notifier<ProjectIdeaPendingVote?> {
  @override
  ProjectIdeaPendingVote? build() => null;

  void set(ProjectIdeaPendingVote pending) => state = pending;

  void clear(ProjectIdeaPendingVote pending) {
    if (state == pending) state = null;
  }

  ProjectIdeaPendingVote? take() {
    final pending = state;
    state = null;
    return pending;
  }
}
