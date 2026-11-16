import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/core/app_events.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/history/application/history_controller.dart';
import 'package:planstar_desktop_app/features/notes/domain/note.dart';

void main() {
  group('便签历史文案', () {
    test('标题与摘要不同时拼接显示', () {
      expect(
        noteHistoryContent(title: '购物清单', summary: '买牛奶'),
        '购物清单：买牛奶',
      );
    });

    test('摘要与标题相同（只有标题无正文）时不重复', () {
      expect(
        noteHistoryContent(title: '会议记录', summary: '会议记录'),
        '会议记录',
      );
    });

    test('无标题时用摘要', () {
      expect(noteHistoryContent(title: '', summary: '正文内容'), '正文内容');
    });

    test('删除便签带原始标题', () {
      expect(
        noteHistoryContent(title: '购物清单', summary: '', removed: true),
        '删除便签：购物清单',
      );
    });
  });

  group('Note 摘要', () {
    test('取第一条非空正文', () {
      final note = Note.create(
        id: 'n1',
        occurredAt: DateTime(2026, 11, 16, 10),
        title: '标题',
        lines: <RichLine>[
          RichLine(id: 'l1', text: ''),
          RichLine(id: 'l2', text: '第一条内容'),
          RichLine(id: 'l3', text: '第二条内容'),
        ],
      );
      expect(note.summary, '第一条内容');
    });

    test('没有正文时回退到标题', () {
      final note = Note.create(
        id: 'n2',
        occurredAt: DateTime(2026, 11, 16, 10),
        title: '只有标题',
      );
      expect(note.summary, '只有标题');
    });

    test('创建时发出的事件携带标题与摘要', () {
      final note = Note.create(
        id: 'n3',
        occurredAt: DateTime(2026, 11, 16, 10),
        title: '读书笔记',
        lines: <RichLine>[RichLine(id: 'l1', text: '第三章摘要')],
      );
      final events = note.pullDomainEvents();
      expect(events, hasLength(1));
      final event = events.single;
      expect(event, isA<NoteChanged>());
      expect((event as NoteChanged).title, '读书笔记');
      expect(event.summary, '第三章摘要');
    });
  });
}
