library;

final class ProjectIdea {
  const ProjectIdea({
    required this.ideaId,
    required this.title,
    required this.summary,
    required this.cover,
    required this.categoryId,
    required this.categoryName,
    required this.creatorName,
    required this.creatorAvatar,
    required this.supportCount,
    required this.opposeCount,
    required this.createdAt,
  });

  factory ProjectIdea.fromJson(Map<String, Object?> json) => ProjectIdea(
    ideaId: _int(json['ideaId']) ?? 0,
    title: _text(json['title']),
    summary: _text(json['summary']),
    cover: _text(json['cover']),
    categoryId: _int(json['categoryId']) ?? 0,
    categoryName: _text(json['categoryName']),
    creatorName: _text(json['creatorName'] ?? json['userName']),
    creatorAvatar: _text(json['creatorAvatar'] ?? json['userAvatar']),
    supportCount: _int(json['supportCount']) ?? 0,
    opposeCount: _int(json['opposeCount']) ?? 0,
    createdAt: _dateTime(json['createdAt'] ?? json['gmtCreate']) ?? _epoch,
  );

  final int ideaId;
  final String title;
  final String summary;
  final String cover;
  final int categoryId;
  final String categoryName;
  final String creatorName;
  final String creatorAvatar;
  final int supportCount;
  final int opposeCount;
  final DateTime createdAt;

  bool get isValid => ideaId > 0;
}

final class ProjectIdeaDetail extends ProjectIdea {
  const ProjectIdeaDetail({
    required super.ideaId,
    required super.title,
    required super.summary,
    required super.cover,
    required super.categoryId,
    required super.categoryName,
    required super.creatorName,
    required super.creatorAvatar,
    required super.supportCount,
    required super.opposeCount,
    required super.createdAt,
    required this.description,
    required this.gallery,
    required this.myVote,
    required this.tierDistribution,
    required this.supportRate,
    required this.reasonCounts,
  });

  factory ProjectIdeaDetail.fromJson(Map<String, Object?> json) {
    final vote = _map(json['myVote']);
    return ProjectIdeaDetail(
      ideaId: _int(json['ideaId']) ?? 0,
      title: _text(json['title']),
      summary: _text(json['summary']),
      cover: _text(json['cover']),
      categoryId: _int(json['categoryId']) ?? 0,
      categoryName: _text(json['categoryName']),
      creatorName: _text(json['creatorName'] ?? json['userName']),
      creatorAvatar: _text(json['creatorAvatar'] ?? json['userAvatar']),
      supportCount: _int(json['supportCount']) ?? 0,
      opposeCount: _int(json['opposeCount']) ?? 0,
      createdAt: _dateTime(json['createdAt'] ?? json['gmtCreate']) ?? _epoch,
      description: _text(json['description']),
      gallery: _strings(json['gallery']),
      myVote: vote == null || vote.isEmpty ? null : IdeaVote.fromJson(vote),
      tierDistribution: IdeaTierDistribution.fromJson(
        _map(json['tierDistribution']) ?? const <String, Object?>{},
      ),
      supportRate: _double(json['supportRate']) ?? 0,
      reasonCounts: _reasonCounts(
        json['reasonCounts'] ?? json['opposeReasonCounts'],
      ),
    );
  }

  final String description;
  final List<String> gallery;
  final IdeaVote? myVote;
  final IdeaTierDistribution tierDistribution;
  final double supportRate;
  final Map<String, int> reasonCounts;

  ProjectIdeaDetail withVoteResult(IdeaVoteResult result) {
    final vote = result.myVote;
    return ProjectIdeaDetail(
      ideaId: ideaId,
      title: title,
      summary: summary,
      cover: cover,
      categoryId: categoryId,
      categoryName: categoryName,
      creatorName: creatorName,
      creatorAvatar: creatorAvatar,
      supportCount: result.supportCount,
      opposeCount: result.opposeCount,
      createdAt: createdAt,
      description: description,
      gallery: gallery,
      myVote: vote,
      tierDistribution: result.tierDistribution ?? _tiersAfter(result, vote),
      supportRate: result.supportRate ??
          (result.supportCount + result.opposeCount > 0
              ? result.supportCount / (result.supportCount + result.opposeCount)
              : supportRate),
      reasonCounts: result.reasonCounts ?? _reasonsAfter(result, vote),
    );
  }

  IdeaTierDistribution _tiersAfter(IdeaVoteResult result, IdeaVote? vote) {
    if (result.alreadyVoted || vote?.voteType != IdeaVote.support) {
      return tierDistribution;
    }
    return tierDistribution.increment(vote!.coinTier);
  }

  Map<String, int> _reasonsAfter(IdeaVoteResult result, IdeaVote? vote) {
    final code = vote?.reasonCode;
    if (result.alreadyVoted ||
        vote?.voteType != IdeaVote.oppose ||
        code == null ||
        code.isEmpty) {
      return reasonCounts;
    }
    return <String, int>{
      ...reasonCounts,
      code: (reasonCounts[code] ?? 0) + 1,
    };
  }
}

final class IdeaVote {
  const IdeaVote({
    required this.voteType,
    this.coinTier,
    this.reasonCode,
    this.reasonText,
  });

  factory IdeaVote.fromJson(Map<String, Object?> json) => IdeaVote(
    voteType: _int(json['voteType']) ?? 0,
    coinTier: _int(json['coinTier']),
    reasonCode: _textOrNull(json['reasonCode']),
    reasonText: _textOrNull(json['reasonText']),
  );

  static const int support = 1;
  static const int oppose = 2;

  final int voteType;
  final int? coinTier;
  final String? reasonCode;
  final String? reasonText;
}

final class IdeaVoteResult {
  const IdeaVoteResult({
    required this.supportCount,
    required this.opposeCount,
    required this.alreadyVoted,
    this.myVote,
    this.tierDistribution,
    this.supportRate,
    this.reasonCounts,
  });

  factory IdeaVoteResult.fromJson(Map<String, Object?> json) {
    final vote = _map(json['myVote']);
    final tiers = _map(json['tierDistribution']);
    final hasReasons =
        json.containsKey('reasonCounts') || json.containsKey('opposeReasonCounts');
    return IdeaVoteResult(
      supportCount: _int(json['supportCount']) ?? 0,
      opposeCount: _int(json['opposeCount']) ?? 0,
      alreadyVoted: _bool(json['alreadyVoted']) ?? false,
      myVote: vote == null || vote.isEmpty ? null : IdeaVote.fromJson(vote),
      tierDistribution: tiers == null
          ? null
          : IdeaTierDistribution.fromJson(tiers),
      supportRate: _double(json['supportRate']),
      reasonCounts: hasReasons
          ? _reasonCounts(json['reasonCounts'] ?? json['opposeReasonCounts'])
          : null,
    );
  }

  final int supportCount;
  final int opposeCount;
  final bool alreadyVoted;
  final IdeaVote? myVote;
  final IdeaTierDistribution? tierDistribution;
  final double? supportRate;
  final Map<String, int>? reasonCounts;
}

final class IdeaTierDistribution {
  const IdeaTierDistribution({this.five = 0, this.ten = 0, this.twenty = 0});

  factory IdeaTierDistribution.fromJson(Map<String, Object?> json) =>
      IdeaTierDistribution(
        five: _int(json['5']) ?? 0,
        ten: _int(json['10']) ?? 0,
        twenty: _int(json['20']) ?? 0,
      );

  final int five;
  final int ten;
  final int twenty;
  int get total => five + ten + twenty;

  IdeaTierDistribution increment(int? tier) => switch (tier) {
    5 => IdeaTierDistribution(five: five + 1, ten: ten, twenty: twenty),
    10 => IdeaTierDistribution(five: five, ten: ten + 1, twenty: twenty),
    20 => IdeaTierDistribution(five: five, ten: ten, twenty: twenty + 1),
    _ => this,
  };
}

final class ProjectIdeaFeedPage {
  const ProjectIdeaFeedPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ProjectIdeaFeedPage.fromJson(Map<String, Object?> json) {
    final rawItems =
        json['items'] ?? json['list'] ?? json['records'] ?? json['data'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (Map<Object?, Object?> item) =>
                    ProjectIdea.fromJson(_map(item)!),
              )
              .where((ProjectIdea idea) => idea.isValid)
              .toList(growable: false)
        : const <ProjectIdea>[];
    final cursor = _textOrNull(json['nextCursor'] ?? json['cursor']);
    return ProjectIdeaFeedPage(
      items: items,
      nextCursor: cursor,
      hasMore: _bool(json['hasMore']) ?? cursor != null,
    );
  }

  final List<ProjectIdea> items;
  final String? nextCursor;
  final bool hasMore;
}

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

int? _int(Object? value) => switch (value) {
  final int value => value,
  final num value => value.toInt(),
  final String value => num.tryParse(value)?.toInt(),
  _ => null,
};

double? _double(Object? value) => switch (value) {
  final double value => value.isFinite ? value : null,
  final num value => value.toDouble().isFinite ? value.toDouble() : null,
  final String value => num.tryParse(value)?.toDouble(),
  _ => null,
};

bool? _bool(Object? value) => switch (value) {
  final bool value => value,
  final num value => value != 0,
  'true' || '1' => true,
  'false' || '0' => false,
  _ => null,
};

String _text(Object? value) => value?.toString() ?? '';

String? _textOrNull(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

DateTime? _dateTime(Object? value) => switch (value) {
  final DateTime value => value,
  final num value => DateTime.fromMillisecondsSinceEpoch(value.toInt()),
  final String value =>
    int.tryParse(value) != null
        ? DateTime.fromMillisecondsSinceEpoch(int.parse(value))
        : DateTime.tryParse(value),
  _ => null,
};

List<String> _strings(Object? value) => value is List
    ? value.map(_textOrNull).whereType<String>().toList(growable: false)
    : const <String>[];

Map<String, int> _reasonCounts(Object? value) {
  final counts = <String, int>{};
  if (value is Map) {
    for (final entry in value.entries) {
      final count = _int(entry.value);
      if (count != null && count > 0) counts['${entry.key}'] = count;
    }
  } else if (value is List) {
    for (final item in value.whereType<Map>()) {
      final json = _map(item)!;
      final code = _textOrNull(
        json['reasonCode'] ?? json['code'] ?? json['reason'],
      );
      final count = _int(json['count'] ?? json['value']);
      if (code != null && count != null && count > 0) counts[code] = count;
    }
  }
  return counts;
}

Map<String, Object?>? _map(Object? value) => value is Map
    ? value.map(
        (Object? key, Object? item) => MapEntry<String, Object?>('$key', item),
      )
    : null;
