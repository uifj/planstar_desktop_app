library;

import 'package:core/result.dart';

import 'show_summary.dart';

abstract interface class ProjectRepository {
  Future<Result<List<ShowCategory>>> categories();
  Future<Result<List<ShowSummary>>> projects({
    int? categoryId,
    ProjectSort sort,
    int page,
    int pageSize,
  });
  Future<Result<ShowSummary>> projectDetail(String id);
}
