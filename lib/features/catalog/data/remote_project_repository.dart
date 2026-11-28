library;

import 'package:core/result.dart';

import '../domain/project_repository.dart';
import '../domain/show_summary.dart';
import 'planstar_catalog_api.dart';

final class RemoteProjectRepository implements ProjectRepository {
  const RemoteProjectRepository({required PlanstarCatalogApi api}) : _api = api;

  final PlanstarCatalogApi _api;

  @override
  Future<Result<List<ShowCategory>>> categories() => _api.categories();

  @override
  Future<Result<List<ShowSummary>>> projects({
    int? categoryId,
    ProjectSort sort = ProjectSort.recommended,
    int page = 1,
    int pageSize = 20,
  }) => _api.projects(
    categoryId: categoryId,
    sort: sort,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<Result<ShowSummary>> projectDetail(String id) =>
      _api.projectDetail(id);
}
