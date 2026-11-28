library;

import 'package:core/network.dart';
import 'package:core/result.dart';

import '../domain/project_idea.dart';

final class PlanstarProjectIdeaApi {
  const PlanstarProjectIdeaApi({required ApiClient client}) : _client = client;

  static const String feedPath = 'v1/projectIdeas/feed';
  static const String votePath = 'v1/projectIdeas/{ideaId}/vote';
  static String detailPath(int ideaId) => 'v1/projectIdeas/$ideaId';
  static String votePathFor(int ideaId) =>
      votePath.replaceFirst('{ideaId}', '$ideaId');

  final ApiClient _client;

  Future<Result<ProjectIdeaFeedPage>> feed({String? cursor, int size = 10}) =>
      _client.get<ProjectIdeaFeedPage>(
        feedPath,
        queryParameters: <String, Object?>{
          'size': size,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
        envelope: const PassthroughEnvelope(),
        parser: (Object? data) => ProjectIdeaFeedPage.fromJson(_payload(data)),
      );

  Future<Result<ProjectIdeaDetail>> detail(int ideaId) =>
      _client.get<ProjectIdeaDetail>(
        detailPath(ideaId),
        envelope: const PassthroughEnvelope(),
        parser: (Object? data) => ProjectIdeaDetail.fromJson(_payload(data)),
      );

  Future<Result<IdeaVoteResult>> vote(
    int ideaId, {
    required int voteType,
    int? coinTier,
    String? reasonCode,
    String? reasonText,
  }) => _client.post<IdeaVoteResult>(
    votePathFor(ideaId),
    data: <String, Object?>{
      'voteType': voteType,
      'coinTier': ?coinTier,
      if (reasonCode != null && reasonCode.isNotEmpty) 'reasonCode': reasonCode,
      if (reasonText != null && reasonText.isNotEmpty) 'reasonText': reasonText,
    },
    envelope: const PassthroughEnvelope(),
    parser: (Object? data) => IdeaVoteResult.fromJson(_payload(data)),
  );

  static Map<String, Object?> _payload(Object? data) {
    final json = _map(data);
    final inner = json['data'];
    return inner is Map ? _map(inner) : json;
  }

  static Map<String, Object?> _map(Object? value) => value is Map
      ? value.map(
          (Object? key, Object? value) =>
              MapEntry<String, Object?>('$key', value),
        )
      : const <String, Object?>{};
}
