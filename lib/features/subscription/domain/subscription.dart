/// 订阅日历聚合 + 仓储端口（旧版 `subs_func.lua` 与第三方日历桥接）。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';

import '../../../core/value_objects.dart';

enum SubscriptionSource {
  local('本地订阅'),
  google('Google 日历'),
  outlook('Outlook 日历'),
  icloud('iCloud 日历'),
  caldav('CalDAV');

  const SubscriptionSource(this.label);

  final String label;

  static SubscriptionSource fromName(String? name) =>
      SubscriptionSource.values.firstWhere(
        (SubscriptionSource s) => s.name == name,
        orElse: () => SubscriptionSource.local,
      );
}

final class SubscriptionEvent extends ValueObject {
  const SubscriptionEvent({
    required this.id,
    required this.date,
    required this.title,
    this.description = '',
  });

  final String id;
  final DateKey date;
  final String title;
  final String description;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'date': date.key,
        'title': title,
        'description': description,
      };

  factory SubscriptionEvent.fromJson(Map<String, Object?> json) =>
      SubscriptionEvent(
        id: json['id'] as String? ?? '',
        date: DateKey.parse(json['date']! as String),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  @override
  List<Object?> get props => <Object?>[id, date, title, description];
}

final class Subscription extends AggregateRoot<String> {
  Subscription._({
    required String id,
    required this.name,
    required this.source,
    required this.shareLink,
    required this.enabled,
    required this.color,
    required this.lastSyncAt,
    required this.events,
  }) : super(id);

  factory Subscription.create({
    required String id,
    required String name,
    required String shareLink,
    SubscriptionSource source = SubscriptionSource.local,
    EventColor color = EventColor.defaultText,
    bool enabled = true,
    DateTime? lastSyncAt,
  }) =>
      Subscription._(
        id: id,
        name: name,
        source: source,
        shareLink: shareLink,
        enabled: enabled,
        color: color,
        lastSyncAt: lastSyncAt,
        events: const <SubscriptionEvent>[],
      );

  final String name;
  final SubscriptionSource source;
  final String shareLink;
  final bool enabled;
  final EventColor color;
  final DateTime? lastSyncAt;
  final List<SubscriptionEvent> events;

  Subscription withEvents(List<SubscriptionEvent> next, DateTime syncedAt) =>
      Subscription._(
        id: id,
        name: name,
        source: source,
        shareLink: shareLink,
        enabled: enabled,
        color: color,
        lastSyncAt: syncedAt,
        events: next,
      );

  Subscription copyWith({
    String? name,
    String? shareLink,
    SubscriptionSource? source,
    bool? enabled,
    EventColor? color,
  }) =>
      Subscription._(
        id: id,
        name: name ?? this.name,
        source: source ?? this.source,
        shareLink: shareLink ?? this.shareLink,
        enabled: enabled ?? this.enabled,
        color: color ?? this.color,
        lastSyncAt: lastSyncAt,
        events: events,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'source': source.name,
        'shareLink': shareLink,
        'enabled': enabled,
        'color': color.argb,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'events': events.map((SubscriptionEvent e) => e.toJson()).toList(),
      };

  factory Subscription.fromJson(Map<String, Object?> json) =>
      Subscription._(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        source: SubscriptionSource.fromName(json['source'] as String?),
        shareLink: json['shareLink'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        color: EventColor(json['color'] as int? ?? 0xFF1F2024),
        lastSyncAt: json['lastSyncAt'] == null
            ? null
            : DateTime.tryParse(json['lastSyncAt']! as String),
        events: (json['events'] as List? ?? const <Object?>[])
            .map(
              (Object? e) => SubscriptionEvent.fromJson(
                Map<String, Object?>.from(e! as Map),
              ),
            )
            .toList(),
      );
}

abstract interface class SubscriptionRepository {
  Future<Result<List<Subscription>>> all();

  Future<Result<void>> save(Subscription subscription);

  Future<Result<void>> delete(String id);

  /// 拉取远端订阅内容；远端不可用时返回结构化失败，由控制器决定降级。
  Future<Result<List<SubscriptionEvent>>> fetchRemote(
    Subscription subscription,
  );
}
