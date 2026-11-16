/// 便签仓储本地实现。
library;

import 'package:core/domain.dart';
import 'package:core/result.dart';
import 'package:core/storage.dart';

import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../../infrastructure/json_entity_store.dart';
import '../domain/note.dart';

final class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository({
    required KeyValueStore store,
    required DomainEventBus bus,
    required Clock clock,
  }) : _store = JsonEntityStore<Note>(
          store: store,
          key: 'planstar.notes.v1',
          bus: bus,
          clock: clock,
          fromJson: Note.fromJson,
          toJson: (Note n) => n.toJson(),
          idOf: (Note n) => n.id,
        );

  final JsonEntityStore<Note> _store;

  @override
  Future<Result<List<Note>>> all() => _store.all();

  @override
  Future<Result<Note?>> byId(String id) async {
    final result = await all();
    return result.map((List<Note> items) {
      for (final note in items) {
        if (note.id == id) return note;
      }
      return null;
    });
  }

  @override
  Future<Result<void>> save(Note note) => _store.upsert(
        note,
        events: note.pullDomainEvents().toList(),
      );

  @override
  Future<Result<void>> delete(String id) => _store.delete(
        id,
        events: <DomainEvent>[
          NoteRemoved(
            aggregateId: id,
            occurredAt: _store.clock.now(),
          ),
        ],
      );

  @override
  Future<Result<void>> clear() => _store.deleteAll();
}
