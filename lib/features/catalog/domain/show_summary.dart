library;

import 'package:core/domain.dart';

final class ShowCategory {
  const ShowCategory({
    required this.id,
    required this.name,
    required this.enName,
    required this.pinyin,
    required this.subTags,
    this.status = 1,
  });

  factory ShowCategory.fromJson(Map<String, Object?> json) => ShowCategory(
    id: _int(json['id']) ?? 0,
    name: _text(json['name']),
    enName: _text(json['enName']),
    pinyin: _text(json['pinyin']),
    subTags: _list(json['subCategoryTags'])
        .map((Map<String, Object?> item) => SubCategoryTag.fromJson(item))
        .toList(growable: false),
    status: _int(json['status']) ?? 1,
  );

  final int id;
  final String name;
  final String enName;
  final String pinyin;
  final List<SubCategoryTag> subTags;
  final int status;

  bool get isActive => status == 1 && id > 0 && name.isNotEmpty;
}

final class SubCategoryTag {
  const SubCategoryTag({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  factory SubCategoryTag.fromJson(Map<String, Object?> json) => SubCategoryTag(
    id: _int(json['subCategoryId'] ?? json['id']) ?? 0,
    categoryId: _int(json['categoryId']) ?? 0,
    name: _text(json['name']),
  );

  final int id;
  final int categoryId;
  final String name;
}

final class TicketTier {
  const TicketTier({
    required this.name,
    required this.price,
    this.note,
    this.remaining,
    this.rewardType = '',
    this.items = const <String>[],
    this.estimatedDeliveryTime = '',
  });

  factory TicketTier.fromJson(Map<String, Object?> json) => TicketTier(
    name: _firstText(json, const <String>['title', 'name', 'tierName']),
    price: _moneyOrZero(json['price'] ?? json['supportAmount']),
    note: _textOrNull(json['note']),
    remaining: _int(json['remainingNum'] ?? json['remaining']),
    rewardType: _text(json['rewardType']),
    items: _strings(json['items']),
    estimatedDeliveryTime: _text(
      json['estimatedDeliveryTime'] ?? json['deliveryTime'],
    ),
  );

  final String name;
  final Money price;
  final String? note;
  final int? remaining;
  final String rewardType;
  final List<String> items;
  final String estimatedDeliveryTime;

  bool get soldOut => remaining != null && remaining! <= 0;
}

final class ProjectFaq {
  const ProjectFaq({
    required this.question,
    required this.answer,
    this.sort = 0,
  });

  factory ProjectFaq.fromJson(Map<String, Object?> json) => ProjectFaq(
    question: _text(json['question']),
    answer: _text(json['answer']),
    sort: _int(json['sort']) ?? 0,
  );

  final String question;
  final String answer;
  final int sort;
}

final class ProjectReview {
  const ProjectReview({
    required this.userName,
    required this.rating,
    this.content = '',
    this.images = const <String>[],
    this.isShow = false,
    this.isAnonymous = false,
    this.likeCount = 0,
    this.createdAt,
  });

  factory ProjectReview.fromJson(Map<String, Object?> json) => ProjectReview(
    userName: _text(json['userName']),
    rating: (_int(json['rating']) ?? 5).clamp(1, 5),
    content: _text(json['content']),
    images: _strings(json['images']),
    isShow: _bool(json['isShow']) ?? false,
    isAnonymous: _bool(json['isAnonymous']) ?? false,
    likeCount: _int(json['likeCount']) ?? 0,
    createdAt: _dateTime(json['gmtCreate'] ?? json['createdAt']),
  );

  final String userName;
  final int rating;
  final String content;
  final List<String> images;
  final bool isShow;
  final bool isAnonymous;
  final int likeCount;
  final DateTime? createdAt;

  String get displayName => isAnonymous ? '' : userName;
}

final class ProjectUpdate {
  const ProjectUpdate({
    required this.title,
    required this.content,
    this.publishTime,
  });

  factory ProjectUpdate.fromJson(Map<String, Object?> json) => ProjectUpdate(
    title: _text(json['title']),
    content: _text(json['content']),
    publishTime: _dateTime(json['publishTime'] ?? json['publish_time']),
  );

  final String title;
  final String content;
  final DateTime? publishTime;
}

final class ShowSession {
  const ShowSession({
    required this.startsAt,
    required this.tierSummary,
    this.soldOut = false,
  });

  factory ShowSession.fromJson(Map<String, Object?> json) => ShowSession(
    startsAt: _dateTime(json['startsAt'] ?? json['showTime']),
    tierSummary: _text(json['tierSummary']),
    soldOut: _bool(json['soldOut']) ?? false,
  );

  final DateTime? startsAt;
  final String tierSummary;
  final bool soldOut;
}

final class ShowSummary {
  const ShowSummary({
    required this.id,
    required this.title,
    required this.artist,
    required this.categoryId,
    required this.categoryName,
    required this.city,
    required this.venue,
    required this.venueAddress,
    required this.firstSessionAt,
    required this.priceFrom,
    this.listPriceFrom,
    this.discountPermille,
    this.tags = const <String>[],
    this.wishCount = 0,
    this.soldOut = false,
    this.proxyBuy = false,
    this.rating = 0,
    this.ratingCount = 0,
    this.duration = '',
    this.intro = '',
    this.summary = '',
    this.cover = '',
    this.gallery = const <String>[],
    this.sessions = const <ShowSession>[],
    this.tiers = const <TicketTier>[],
    this.lineup = const <String>[],
    this.purchaseNotice = const <String>[],
    this.goalAmount,
    this.raisedAmount,
    this.supporterCount = 0,
    this.deadline,
    this.fundingStatus = '',
    this.riskNote = '',
    this.deliveryPlan = '',
    this.fundUsage = '',
    this.refundRule = '',
    this.refundDays = 7,
    this.faqs = const <ProjectFaq>[],
    this.reviews = const <ProjectReview>[],
    this.ratingAvg = 0,
    this.reviewCount = 0,
    this.showCount = 0,
    this.updates = const <ProjectUpdate>[],
    this.creatorVerified = false,
    this.creatorProjectNum = 0,
    this.creatorSuccessNum = 0,
    this.creatorFulfillmentPermille = 0,
    this.creatorBio = '',
    this.creatorAvatar = '',
  });

  factory ShowSummary.fromJson(Map<String, Object?> json) {
    final creator = _map(json['creator']);
    final artist = _firstText(json, const <String>[
      'artist',
      'creatorName',
      'star',
    ]);
    final creatorBio = _textOrNull(json['creatorBio']);
    return ShowSummary(
      id: _firstText(json, const <String>['id', 'projectId', 'activityId']),
      title: _firstText(json, const <String>['title', 'name']),
      artist: artist.isNotEmpty
          ? artist
          : _text(creator?['displayName'] ?? creator?['name']),
      categoryId: _int(json['categoryId'] ?? json['category']) ?? 0,
      categoryName: _text(json['categoryName']),
      city: _text(json['city']),
      venue: _firstText(json, const <String>['venue', 'venueName']),
      venueAddress: _text(json['venueAddress']),
      firstSessionAt: _dateTime(json['firstSessionAt'] ?? json['showTime']),
      priceFrom: _moneyOrZero(
        json['priceFrom'] ?? json['minPrice'] ?? json['minSupportAmount'],
      ),
      listPriceFrom: _money(json['listPriceFrom'] ?? json['originalPrice']),
      discountPermille: _int(json['discountPermille'] ?? json['discount']),
      tags: _strings(json['tags']),
      wishCount: _int(json['wishCount'] ?? json['wannaSeeCount']) ?? 0,
      soldOut: _bool(json['soldOut']) ?? json['status'] == 0,
      proxyBuy: _bool(json['proxyBuy']) ?? false,
      rating: _double(json['rating']) ?? 0,
      ratingCount: _int(json['ratingCount']) ?? 0,
      duration: _text(json['duration']),
      intro: _firstText(json, const <String>['intro', 'story', 'description']),
      summary: _firstText(json, const <String>['summary', 'subtitle']),
      cover: _firstText(json, const <String>['cover', 'poster', 'image']),
      gallery: _strings(json['gallery'] ?? json['images']),
      sessions: _maps(
        json['sessions'],
      ).map(ShowSession.fromJson).toList(growable: false),
      tiers: _maps(
        json['tiers'] ?? json['rewardTiers'],
      ).map(TicketTier.fromJson).toList(growable: false),
      lineup: _strings(json['lineup']),
      purchaseNotice: _strings(json['purchaseNotice']),
      goalAmount: _money(json['goalAmount']),
      raisedAmount: _money(json['raisedAmount']),
      supporterCount: _int(json['supporterCount']) ?? 0,
      deadline: _dateTime(json['deadline']),
      fundingStatus: _text(json['fundingStatus']),
      riskNote: _text(json['riskNote']),
      deliveryPlan: _text(json['deliveryPlan']),
      fundUsage: _text(json['fundUsage']),
      refundRule: _text(json['refundRule']),
      refundDays: _int(json['refundDays']) ?? 7,
      faqs: _maps(
        json['faqs'] ?? json['faq'],
      ).map(ProjectFaq.fromJson).toList(growable: false),
      reviews: _maps(
        json['reviews'],
      ).map(ProjectReview.fromJson).toList(growable: false),
      ratingAvg: _double(json['ratingAvg']) ?? 0,
      reviewCount: _int(json['reviewCount']) ?? 0,
      showCount: _int(json['showCount']) ?? 0,
      updates: _maps(
        json['updates'],
      ).map(ProjectUpdate.fromJson).toList(growable: false),
      creatorVerified:
          _bool(json['creatorVerified']) ??
          (_bool(creator?['isVerified']) ?? false),
      creatorProjectNum:
          _int(json['creatorProjectNum'] ?? creator?['projectNum']) ?? 0,
      creatorSuccessNum:
          _int(json['creatorSuccessNum'] ?? creator?['successNum']) ?? 0,
      creatorFulfillmentPermille:
          _int(
            json['creatorFulfillmentPermille'] ?? creator?['fulfillmentRate'],
          ) ??
          0,
      creatorBio: creatorBio ?? _text(creator?['bio']),
      creatorAvatar: _text(json['creatorAvatar'] ?? creator?['avatar']),
    );
  }

  final String id;
  final String title;
  final String artist;
  final int categoryId;
  final String categoryName;
  final String city;
  final String venue;
  final String venueAddress;
  final DateTime? firstSessionAt;
  final Money priceFrom;
  final Money? listPriceFrom;
  final int? discountPermille;
  final List<String> tags;
  final int wishCount;
  final bool soldOut;
  final bool proxyBuy;
  final double rating;
  final int ratingCount;
  final String duration;
  final String intro;
  final String summary;
  final String cover;
  final List<String> gallery;
  final List<ShowSession> sessions;
  final List<TicketTier> tiers;
  final List<String> lineup;
  final List<String> purchaseNotice;
  final Money? goalAmount;
  final Money? raisedAmount;
  final int supporterCount;
  final DateTime? deadline;
  final String fundingStatus;
  final String riskNote;
  final String deliveryPlan;
  final String fundUsage;
  final String refundRule;
  final int refundDays;
  final List<ProjectFaq> faqs;
  final List<ProjectReview> reviews;
  final double ratingAvg;
  final int reviewCount;
  final int showCount;
  final List<ProjectUpdate> updates;
  final bool creatorVerified;
  final int creatorProjectNum;
  final int creatorSuccessNum;
  final int creatorFulfillmentPermille;
  final String creatorBio;
  final String creatorAvatar;

  bool get isValid => id.isNotEmpty;
  bool get isProject => goalAmount != null;
  DateTime? get projectDeadline => deadline ?? firstSessionAt;
  int get achievementPermille {
    final goal = goalAmount?.minorUnits ?? 0;
    if (goal <= 0) return 0;
    return ((raisedAmount?.minorUnits ?? 0) * 1000 / goal).round();
  }

  String get fundingStatusValue => fundingStatus.isNotEmpty
      ? fundingStatus
      : soldOut
      ? 'failed'
      : 'ongoing';

  String get venueLabel => city.isNotEmpty && venue.isNotEmpty
      ? '$city · $venue'
      : city.isNotEmpty
      ? city
      : venue;
}

enum ProjectSort {
  recommended('hot'),
  newest('new'),
  ending('ending'),
  achievement('achievement');

  const ProjectSort(this.apiValue);

  final String apiValue;
}

final class ProjectListQuery {
  const ProjectListQuery({
    this.categoryId,
    this.sort = ProjectSort.recommended,
  });

  final int? categoryId;
  final ProjectSort sort;

  @override
  bool operator ==(Object other) =>
      other is ProjectListQuery &&
      other.categoryId == categoryId &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(categoryId, sort);
}

String _firstText(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = _textOrNull(json[key]);
    if (value != null) return value;
  }
  return '';
}

String _text(Object? value) => value?.toString() ?? '';

String? _textOrNull(Object? value) {
  final text = _text(value).trim();
  return text.isEmpty ? null : text;
}

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

DateTime? _dateTime(Object? value) => switch (value) {
  final DateTime value => value,
  final num value => DateTime.fromMillisecondsSinceEpoch(value.toInt()),
  final String value =>
    int.tryParse(value) != null
        ? DateTime.fromMillisecondsSinceEpoch(int.parse(value))
        : DateTime.tryParse(value),
  _ => null,
};

Money? _money(Object? value) {
  final cents = _int(value);
  return cents == null ? null : Money.fromMinorUnits(cents);
}

Money _moneyOrZero(Object? value) => _money(value) ?? Money.zero();

List<String> _strings(Object? value) => value is List
    ? value.map(_textOrNull).whereType<String>().toList(growable: false)
    : const <String>[];

List<Map<String, Object?>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(_map)
          .whereType<Map<String, Object?>>()
          .toList(growable: false)
    : const <Map<String, Object?>>[];

List<Map<String, Object?>> _list(Object? value) => _maps(value);

Map<String, Object?>? _map(Object? value) => value is Map
    ? value.map(
        (Object? key, Object? item) => MapEntry<String, Object?>('$key', item),
      )
    : null;
