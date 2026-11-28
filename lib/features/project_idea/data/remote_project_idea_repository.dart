library;

import 'package:core/result.dart';

import '../domain/project_idea.dart';
import '../domain/project_idea_repository.dart';
import 'planstar_project_idea_api.dart';

final class RemoteProjectIdeaRepository implements ProjectIdeaRepository {
  const RemoteProjectIdeaRepository({required PlanstarProjectIdeaApi api})
    : _api = api;

  final PlanstarProjectIdeaApi _api;

  @override
  Future<Result<ProjectIdeaFeedPage>> feed({String? cursor, int size = 10}) =>
      _api.feed(cursor: cursor, size: size);

  @override
  Future<Result<ProjectIdeaDetail>> detail(int ideaId) => _api.detail(ideaId);

  @override
  Future<Result<IdeaVoteResult>> vote(
    int ideaId, {
    required int voteType,
    int? coinTier,
    String? reasonCode,
    String? reasonText,
  }) => _api.vote(
    ideaId,
    voteType: voteType,
    coinTier: coinTier,
    reasonCode: reasonCode,
    reasonText: reasonText,
  );
}
