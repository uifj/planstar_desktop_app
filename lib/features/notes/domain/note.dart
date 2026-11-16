/// 便签聚合根 + 仓储端口（旧版 `dkappnote` 模块）。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';

import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../../core/value_objects.dart';

final class Note extends AggregateRoot<String> {
  Note._({
    required String id,
    required this.title,
    required this.lines,
    required this.backgroundIndex,
    required this.fontColor,
    required this.visible,
    required this.topMost,
    required this.rect,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  factory Note.create({
    required String id,
    required DateTime occurredAt,
    String title = '新建便签',
    List<RichLine> lines = const <RichLine>[],
    int backgroundIndex = 0,
    EventColor fontColor = EventColor.defaultText,
    bool visible = true,
    bool topMost = false,
    WindowRect rect = const WindowRect(180, 160, 360, 420),
  }) {
    final note = Note._(
      id: id,
      title: title,
      lines: lines,
      backgroundIndex: backgroundIndex,
      fontColor: fontColor,
      visible: visible,
      topMost: topMost,
      rect: rect,
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );
    note.raiseDomainEvent(
      NoteChanged(aggregateId: id, occurredAt: occurredAt),
    );
    return note;
  }

  final String title;
  final List<RichLine> lines;
  final int backgroundIndex;
  final EventColor fontColor;
  final bool visible;
  final bool topMost;
  final WindowRect rect;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventColor get backgroundColor =>
      EventColor.palette[backgroundIndex.clamp(0, EventColor.palette.length - 1)];

  String get plainText => lines.map((RichLine l) => l.text).join('\n');

  Note changed({
    required DateTime occurredAt,
    String? title,
    List<RichLine>? lines,
    int? backgroundIndex,
    EventColor? fontColor,
    bool? visible,
    bool? topMost,
    WindowRect? rect,
  }) {
    final next = Note._(
      id: id,
      title: title ?? this.title,
      lines: lines ?? this.lines,
      backgroundIndex: backgroundIndex ?? this.backgroundIndex,
      fontColor: fontColor ?? this.fontColor,
      visible: visible ?? this.visible,
      topMost: topMost ?? this.topMost,
      rect: rect ?? this.rect,
      createdAt: createdAt,
      updatedAt: occurredAt,
    );
    next.raiseDomainEvent(
      NoteChanged(aggregateId: id, occurredAt: occurredAt),
    );
    return next;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'lines': lines.map((RichLine l) => l.toJson()).toList(),
        'backgroundIndex': backgroundIndex,
        'fontColor': fontColor.argb,
        'visible': visible,
        'topMost': topMost,
        'rect': rect.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, Object?> json) => Note._(
        id: json['id'] as String,
        title: json['title'] as String? ?? '新建便签',
        lines: (json['lines'] as List? ?? const <Object?>[])
            .map(
              (Object? l) => RichLine.fromJson(
                Map<String, Object?>.from(l! as Map),
              ),
            )
            .toList(),
        backgroundIndex: (json['backgroundIndex'] as num?)?.toInt() ?? 0,
        fontColor: EventColor(json['fontColor'] as int? ?? 0xFF1F2024),
        visible: json['visible'] as bool? ?? true,
        topMost: json['topMost'] as bool? ?? false,
        rect: WindowRect.fromJson(
          Map<String, Object?>.from(
            (json['rect'] as Map?) ?? const <String, Object?>{},
          ),
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

abstract interface class NoteRepository {
  Future<Result<List<Note>>> all();

  Future<Result<Note?>> byId(String id);

  Future<Result<void>> save(Note note);

  Future<Result<void>> delete(String id);

  Future<Result<void>> clear();
}
