library;

import 'package:core/result.dart';

import 'project_idea.dart';

abstract interface class ProjectIdeaRepository {
  Future<Result<ProjectIdeaFeedPage>> feed({String? cursor, int size = 10});
  Future<Result<ProjectIdeaDetail>> detail(int ideaId);
  Future<Result<IdeaVoteResult>> vote(
    int ideaId, {
    required int voteType,
    int? coinTier,
    String? reasonCode,
    String? reasonText,
  });
}
