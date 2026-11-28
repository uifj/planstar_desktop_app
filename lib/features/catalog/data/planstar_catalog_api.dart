library;

import 'package:core/network.dart';
import 'package:core/result.dart';

import '../domain/show_summary.dart';

final class PlanstarCatalogApi {
  const PlanstarCatalogApi({required ApiClient client}) : _client = client;

  static const String categoriesPath = 'v1/categories';
  static const String projectsPath = 'v1/projects';
  static String projectDetailPath(String id) => 'v1/projects/$id';

  final ApiClient _client;

  Future<Result<List<ShowCategory>>> categories() =>
      _client.get<List<ShowCategory>>(
        categoriesPath,
        envelope: const PassthroughEnvelope(),
        parser: (Object? data) => _items(data)
            .map(ShowCategory.fromJson)
            .where((ShowCategory category) => category.isActive)
            .toList(growable: false),
      );

  Future<Result<List<ShowSummary>>> projects({
    int? categoryId,
    ProjectSort sort = ProjectSort.recommended,
    int page = 1,
    int pageSize = 20,
  }) => _client.get<List<ShowSummary>>(
    projectsPath,
    queryParameters: <String, Object?>{
      'page': page,
      'pageSize': pageSize,
      'categoryId': ?categoryId,
      'sort': sort.apiValue,
    },
    envelope: const PassthroughEnvelope(),
    parser: (Object? data) => _items(data)
        .map(ShowSummary.fromJson)
        .where((ShowSummary show) => show.isValid)
        .toList(growable: false),
  );

  Future<Result<ShowSummary>> projectDetail(String id) =>
      _client.get<ShowSummary>(
        projectDetailPath(id),
        envelope: const PassthroughEnvelope(),
        parser: (Object? data) {
          final json = _payload(data);
          final show = ShowSummary.fromJson(json);
          if (!show.isValid) throw const FormatException('Missing project id');
          return show;
        },
      );

  static List<Map<String, Object?>> _items(Object? data) {
    final payload = _payload(data);
    final raw =
        payload['items'] ??
        payload['list'] ??
        payload['records'] ??
        payload['data'];
    return raw is List
        ? raw
              .whereType<Map>()
              .map(_map)
              .whereType<Map<String, Object?>>()
              .toList(growable: false)
        : const <Map<String, Object?>>[];
  }

  static Map<String, Object?> _payload(Object? data) {
    if (data is List) return <String, Object?>{'data': data};
    final json = _map(data) ?? const <String, Object?>{};
    final inner = json['data'];
    if (inner is List) return <String, Object?>{'data': inner};
    return inner is Map ? _map(inner) ?? json : json;
  }

  static Map<String, Object?>? _map(Object? value) => value is Map
      ? value.map(
          (Object? key, Object? item) =>
              MapEntry<String, Object?>('$key', item),
        )
      : null;
}
