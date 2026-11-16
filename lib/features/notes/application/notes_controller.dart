/// 便签应用服务 + Riverpod 状态。
library;

import 'package:core/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/list_state.dart';
import '../../../core/value_objects.dart';
import '../domain/note.dart';
import '../infrastructure/local_note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (Ref ref) => LocalNoteRepository(
    store: ref.watch(keyValueStoreProvider),
    bus: ref.watch(domainEventBusProvider),
    clock: ref.watch(clockProvider),
  ),
);

final notesControllerProvider =
    NotifierProvider<NotesController, AsyncListState<Note>>(
  NotesController.new,
);

final class NotesController extends Notifier<AsyncListState<Note>> {
  @override
  AsyncListState<Note> build() {
    Future.microtask(load);
    return AsyncListState<Note>();
  }

  NoteRepository get _repository => ref.read(noteRepositoryProvider);

  Future<void> load() async {
    final result = await _repository.all();
    switch (result) {
      case Success<List<Note>>(:final List<Note> data):
        state = state.copyWith(
          items: data,
          loading: false,
          clearError: true,
        );
      case Fail<List<Note>>(:final Failure failure):
        state = state.copyWith(loading: false, error: failure.message);
    }
  }

  Future<Note?> create({String title = '新建便签'}) async {
    final now = ref.read(clockProvider).now();
    final note = Note.create(
      id: ref.read(idGeneratorProvider).next(),
      occurredAt: now,
      title: title,
    );
    final result = await _repository.save(note);
    await load();
    return result.isSuccess ? note : null;
  }

  Future<void> save(Note note) async {
    await _repository.save(note);
    await load();
  }

  Future<void> saveLines(String id, List<RichLine> lines) async {
    final found = await _repository.byId(id);
    if (found is! Success<Note?> || found.data == null) return;
    await save(
      found.data!.changed(
        occurredAt: ref.read(clockProvider).now(),
        lines: lines,
      ),
    );
  }

  Future<void> rename(String id, String title) async {
    final found = await _repository.byId(id);
    if (found is! Success<Note?> || found.data == null) return;
    await save(
      found.data!.changed(
        occurredAt: ref.read(clockProvider).now(),
        title: title,
      ),
    );
  }

  Future<void> setBackground(String id, int index) async {
    final found = await _repository.byId(id);
    if (found is! Success<Note?> || found.data == null) return;
    await save(
      found.data!.changed(
        occurredAt: ref.read(clockProvider).now(),
        backgroundIndex: index,
      ),
    );
  }

  Future<void> toggleVisible(String id) async {
    final found = await _repository.byId(id);
    if (found is! Success<Note?> || found.data == null) return;
    final note = found.data!;
    await save(
      note.changed(
        occurredAt: ref.read(clockProvider).now(),
        visible: !note.visible,
      ),
    );
  }

  Future<void> toggleTopMost(String id) async {
    final found = await _repository.byId(id);
    if (found is! Success<Note?> || found.data == null) return;
    final note = found.data!;
    final next = note.changed(
      occurredAt: ref.read(clockProvider).now(),
      topMost: !note.topMost,
    );
    await save(next);
    await ref
        .read(windowGatewayProvider)
        .setAlwaysOnTop(next.topMost);
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    await load();
  }

  /// 桌面多窗口：一个便签一个独立 engine。
  Future<void> openDesktopWindow(String id) => ref
      .read(multiWindowGatewayProvider)
      .openNoteWindow(id)
      .then<void>((_) {});
}
