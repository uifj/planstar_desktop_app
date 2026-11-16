/// 历史记录聚合 + 仓储端口（旧版「历史记录 / 恢复」）。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';

enum HistoryKind { cell, note }

final class HistoryEntry extends AggregateRoot<String> {
  HistoryEntry({
    required String id,
    required this.targetId,
    required this.kind,
    required this.content,
    required this.author,
    required this.occurredAt,
  }) : super(id);

  final String targetId;
  final HistoryKind kind;
  final String content;
  final String author;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'targetId': targetId,
        'kind': kind.name,
        'content': content,
        'author': author,
        'occurredAt': occurredAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, Object?> json) => HistoryEntry(
        id: json['id'] as String,
        targetId: json['targetId'] as String? ?? '',
        kind: HistoryKind.values.firstWhere(
          (HistoryKind k) => k.name == json['kind'],
          orElse: () => HistoryKind.cell,
        ),
        content: json['content'] as String? ?? '',
        author: json['author'] as String? ?? '本机',
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
                DateTime.now(),
      );
}

abstract interface class HistoryRepository {
  Future<Result<List<HistoryEntry>>> all();

  Future<Result<void>> append(HistoryEntry entry);

  Future<Result<void>> delete(String id);

  Future<Result<void>> clear();
}
