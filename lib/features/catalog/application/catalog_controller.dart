library;

import 'dart:async';

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../l10n/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../data/planstar_catalog_api.dart';
import '../data/remote_project_repository.dart';
import '../domain/project_repository.dart';
import '../domain/show_summary.dart';

final projectCatalogApiProvider = Provider<PlanstarCatalogApi>(
  (Ref ref) => PlanstarCatalogApi(client: ref.watch(planstarApiClientProvider)),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (Ref ref) =>
      RemoteProjectRepository(api: ref.watch(projectCatalogApiProvider)),
);

final class ProjectCategoriesState {
  const ProjectCategoriesState({
    this.items = const <ShowCategory>[],
    this.loading = true,
    this.error,
  });

  final List<ShowCategory> items;
  final bool loading;
  final String? error;
}

final class ProjectCategoriesController
    extends Notifier<ProjectCategoriesState> {
  bool _disposed = false;

  @override
  ProjectCategoriesState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(Future<void>.microtask(load));
    return const ProjectCategoriesState();
  }

  Future<void> load() async {
    if (_disposed || (!state.loading && state.items.isNotEmpty)) return;
    state = const ProjectCategoriesState(items: <ShowCategory>[], error: null);
    final result = await ref.read(projectRepositoryProvider).categories();
    if (_disposed) return;
    switch (result) {
      case Success<List<ShowCategory>>(:final data):
        state = ProjectCategoriesState(items: data, loading: false);
      case Fail<List<ShowCategory>>(:final failure):
        state = ProjectCategoriesState(error: _label(failure));
    }
  }

  String _label(Failure failure) => failureLabel(
    failure,
    ref.read(appLocalizationScopeProvider).localizations,
  );
}

final projectCategoriesProvider =
    NotifierProvider<ProjectCategoriesController, ProjectCategoriesState>(
      ProjectCategoriesController.new,
    );

final class ProjectListState {
  const ProjectListState({
    this.items = const <ShowSummary>[],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<ShowSummary> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  ProjectListState copyWith({
    List<ShowSummary>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error = _unset,
  }) => ProjectListState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: identical(error, _unset) ? this.error : error as String?,
  );
}

const Object _unset = Object();

final class ProjectListController extends Notifier<ProjectListState> {
  ProjectListController(this.query);

  final ProjectListQuery query;
  static const int pageSize = 20;
  int _page = 1;
  int _requestRevision = 0;
  bool _disposed = false;

  @override
  ProjectListState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(Future<void>.microtask(() => _loadInitial(initial: true)));
    return const ProjectListState();
  }

  Future<void> loadInitial() => _loadInitial(initial: false);

  Future<void> _loadInitial({required bool initial}) async {
    if (_disposed || (!initial && state.loading)) return;
    final revision = ++_requestRevision;
    _page = 1;
    state = const ProjectListState();
    final result = await ref
        .read(projectRepositoryProvider)
        .projects(
          categoryId: query.categoryId,
          sort: query.sort,
          page: 1,
          pageSize: pageSize,
        );
    if (_disposed || revision != _requestRevision) return;
    switch (result) {
      case Success<List<ShowSummary>>(:final data):
        state = ProjectListState(
          items: data,
          loading: false,
          hasMore: data.length == pageSize,
        );
      case Fail<List<ShowSummary>>(:final failure):
        state = ProjectListState(loading: false, error: _label(failure));
    }
  }

  Future<void> loadMore() async {
    if (_disposed || state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    final revision = _requestRevision;
    state = state.copyWith(loadingMore: true, error: null);
    final nextPage = _page + 1;
    final result = await ref
        .read(projectRepositoryProvider)
        .projects(
          categoryId: query.categoryId,
          sort: query.sort,
          page: nextPage,
          pageSize: pageSize,
        );
    if (_disposed || revision != _requestRevision) return;
    switch (result) {
      case Success<List<ShowSummary>>(:final data):
        final seen = state.items.map((ShowSummary show) => show.id).toSet();
        final additions = data
            .where((ShowSummary show) => seen.add(show.id))
            .toList(growable: false);
        _page = nextPage;
        state = state.copyWith(
          items: <ShowSummary>[...state.items, ...additions],
          loadingMore: false,
          hasMore: data.length == pageSize,
        );
      case Fail<List<ShowSummary>>(:final failure):
        state = state.copyWith(loadingMore: false, error: _label(failure));
    }
  }

  String _label(Failure failure) => failureLabel(
    failure,
    ref.read(appLocalizationScopeProvider).localizations,
  );
}

final projectListProvider = NotifierProvider.autoDispose
    .family<ProjectListController, ProjectListState, ProjectListQuery>(
      ProjectListController.new,
    );

final class ProjectDetailState {
  const ProjectDetailState({this.detail, this.loading = true, this.error});

  final ShowSummary? detail;
  final bool loading;
  final String? error;

  ProjectDetailState copyWith({
    ShowSummary? detail,
    bool? loading,
    Object? error = _unset,
  }) => ProjectDetailState(
    detail: detail ?? this.detail,
    loading: loading ?? this.loading,
    error: identical(error, _unset) ? this.error : error as String?,
  );
}

final class ProjectDetailController extends Notifier<ProjectDetailState> {
  ProjectDetailController(this.id);

  final String id;
  bool _disposed = false;

  @override
  ProjectDetailState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(Future<void>.microtask(load));
    return const ProjectDetailState();
  }

  Future<void> load() async {
    if (_disposed || (state.loading && state.detail != null)) return;
    state = state.copyWith(loading: true, error: null);
    final result = await ref.read(projectRepositoryProvider).projectDetail(id);
    if (_disposed) return;
    switch (result) {
      case Success<ShowSummary>(:final data):
        state = ProjectDetailState(detail: data, loading: false);
      case Fail<ShowSummary>(:final failure):
        state = state.copyWith(loading: false, error: _label(failure));
    }
  }

  String _label(Failure failure) => failureLabel(
    failure,
    ref.read(appLocalizationScopeProvider).localizations,
  );
}

final projectDetailProvider = NotifierProvider.autoDispose
    .family<ProjectDetailController, ProjectDetailState, String>(
      ProjectDetailController.new,
    );
