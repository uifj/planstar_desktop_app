import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/core/app_events.dart';
import 'package:planstar_desktop_app/core/value_objects.dart';
import 'package:planstar_desktop_app/features/history/application/history_controller.dart';
import 'package:planstar_desktop_app/features/history/domain/history_entry.dart';
import 'package:planstar_desktop_app/features/history/presentation/history_localization.dart';
import 'package:planstar_desktop_app/features/notes/domain/note.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

HistoryEntry _historyEntry(
  String content, {
  String author = '本机',
  HistoryKind kind = HistoryKind.note,
}) => HistoryEntry(
  id: 'history-1',
  targetId: '2026-11-16',
  kind: kind,
  content: content,
  author: author,
  occurredAt: DateTime(2026, 11, 16, 10),
);

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('便签历史文案', () {
    test('标题与摘要不同时拼接显示', () {
      expect(noteHistoryContent(title: '购物清单', summary: '买牛奶'), '购物清单：买牛奶');
    });

    test('摘要与标题相同（只有标题无正文）时不重复', () {
      expect(noteHistoryContent(title: '会议记录', summary: '会议记录'), '会议记录');
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

  group('历史记录显示时本地化', () {
    test('中文内容快照保留原文，本机作者按当前语言渲染', () {
      final content = zh.historyNoteWithSummary('购物清单', '买牛奶');
      final entry = _historyEntry(content);

      final display = localizeHistoryEntry(entry, en);

      expect(display.content, content);
      expect(display.author, en.historyAuthorLocal);
    });

    test('英文内容快照保留原文，本机作者按当前语言渲染', () {
      final content = en.historyNoteWithSummary('Shopping list', 'Buy milk');
      final entry = _historyEntry(content, author: en.historyAuthorLocal);

      final display = localizeHistoryEntry(entry, zh);

      expect(display.content, content);
      expect(display.author, zh.historyAuthorLocal);
    });

    test('语言切换只改变本机作者，不改写持久化条目', () {
      final entry = _historyEntry(zh.historyNoteWithSummary('会议记录', '讨论发布'));
      final before = entry.toJson();

      final english = localizeHistoryEntry(entry, en);
      final chinese = localizeHistoryEntry(entry, zh);
      final englishAgain = localizeHistoryEntry(entry, en);

      expect(english.content, entry.content);
      expect(english.author, en.historyAuthorLocal);
      expect(chinese.content, entry.content);
      expect(chinese.author, zh.historyAuthorLocal);
      expect(englishAgain, english);
      expect(entry.toJson(), before);
    });

    test('旧版中文删除模板和摘要模板保持原语言快照', () {
      for (final content in <String>['删除便签', '删除便签：购物清单', '购物清单：买牛奶']) {
        final display = localizeHistoryEntry(_historyEntry(content), en);
        expect(display.content, content);
        expect(display.author, en.historyAuthorLocal);
      }
    });

    test('英文删除模板保持原语言快照', () {
      for (final content in <String>[
        en.historyNoteRemoved,
        en.historyNoteRemovedWithTitle('购物清单'),
      ]) {
        final display = localizeHistoryEntry(
          _historyEntry(content, author: en.historyAuthorLocal),
          zh,
        );
        expect(display.content, content);
        expect(display.author, zh.historyAuthorLocal);
      }
    });

    test('删除模板标题中的分隔符和中文保持原文', () {
      const title = 'Project: 删除便签阶段';
      for (final content in <String>[
        zh.historyNoteRemovedWithTitle(title),
        en.historyNoteRemovedWithTitle(title),
      ]) {
        expect(
          localizeHistoryEntry(_historyEntry(content), en).content,
          content,
        );
      }
    });

    test('仅标题和仅摘要内容保持原文', () {
      final titleOnly = noteHistoryContent(title: '只有标题', summary: '只有标题');
      final summaryOnly = noteHistoryContent(title: '', summary: '只有摘要');
      for (final content in <String>[titleOnly, summaryOnly, 'Custom title']) {
        expect(
          localizeHistoryEntry(_historyEntry(content), en).content,
          content,
        );
        expect(
          localizeHistoryEntry(_historyEntry(content), zh).content,
          content,
        );
      }
    });

    test('自定义作者、非模板内容和日历快照保持原文', () {
      const customContent = '自定义内容保留中文与 English，不含固定模板分隔符';
      final customAuthor = localizeHistoryEntry(
        _historyEntry(customContent, author: 'Alice'),
        en,
      );
      final cellSnapshot = localizeHistoryEntry(
        _historyEntry(
          zh.historyNoteWithSummary('日程', '内容'),
          kind: HistoryKind.cell,
        ),
        en,
      );
      final prefixLikeContent = localizeHistoryEntry(
        _historyEntry('备注 删除便签 购物清单'),
        en,
      );
      final repeatedSummary = localizeHistoryEntry(
        _historyEntry('Same: Same'),
        zh,
      );
      final empty = localizeHistoryEntry(_historyEntry(''), en);

      expect(customAuthor.content, customContent);
      expect(customAuthor.author, 'Alice');
      expect(cellSnapshot.content, zh.historyNoteWithSummary('日程', '内容'));
      expect(prefixLikeContent.content, '备注 删除便签 购物清单');
      expect(repeatedSummary.content, 'Same: Same');
      expect(empty.content, isEmpty);
    });

    test('用户动态文本中的中文、前缀和分隔符不被全局替换', () {
      const title = '删除便签项目: Roadmap: draft';
      const summary = '本机备注 Deleted note: 保留原文';
      final entry = _historyEntry(
        noteHistoryContent(title: title, summary: summary, l10n: zh),
      );

      expect(localizeHistoryEntry(entry, en).content, entry.content);
      expect(localizeHistoryEntry(entry, zh).content, entry.content);
    });

    test('标题或摘要含分隔符时不会移动可见边界', () {
      final cases = <String>[
        noteHistoryContent(title: 'Roadmap: draft', summary: '', l10n: en),
        noteHistoryContent(title: 'Roadmap: draft', summary: 'Ship', l10n: en),
        noteHistoryContent(title: '路线图：草稿', summary: '', l10n: zh),
        noteHistoryContent(title: '路线图：草稿', summary: '发布', l10n: zh),
      ];
      for (final content in cases) {
        expect(
          localizeHistoryEntry(_historyEntry(content), en).content,
          content,
        );
        expect(
          localizeHistoryEntry(_historyEntry(content), zh).content,
          content,
        );
      }
    });

    test('空标题或空摘要快照保持原文', () {
      for (final content in <String>[
        zh.historyNoteRemovedWithTitle(''),
        zh.historyNoteWithSummary('', '摘要'),
        zh.historyNoteWithSummary('标题', ''),
        en.historyNoteRemovedWithTitle(''),
        en.historyNoteWithSummary('', 'Summary'),
        en.historyNoteWithSummary('Title', ''),
      ]) {
        expect(
          localizeHistoryEntry(_historyEntry(content), en).content,
          content,
        );
      }
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
