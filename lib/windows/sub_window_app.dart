/// `desktop_multi_window` 子窗口入口（便签 / 倒数日桌面卡片）。
///
/// 子窗口与主窗口是不同 engine，但共享同一份本地存储；实时变更通过
/// `MultiWindowGateway.incoming` 的 `refresh` 指令触发重新加载。
library;

import 'dart:async';

import 'package:core_design_system/core_design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/core_providers.dart';
import '../core/ports.dart';
import '../core/value_objects.dart';
import '../features/countdown/application/countdown_controller.dart';
import '../features/history/application/history_controller.dart';
import '../features/notes/application/notes_controller.dart';
import '../features/notes/domain/note.dart';
import '../features/sync/application/cross_engine_sync_controller.dart';
import '../shared/widgets/common.dart';
import 'desktop_widget_app.dart';

final class SubWindowApp extends ConsumerStatefulWidget {
  const SubWindowApp({super.key, required this.arguments});

  final Map<String, Object?> arguments;

  @override
  ConsumerState<SubWindowApp> createState() => _SubWindowAppState();
}

final class _SubWindowAppState extends ConsumerState<SubWindowApp> {
  StreamSubscription<MultiWindowCommand>? _commands;

  @override
  void initState() {
    super.initState();
    ref.read(crossEngineSyncControllerProvider);
    // 子窗口 engine 也要留痕：便签/倒数日的编辑在此 engine 内分发领域事件，
    // 不初始化 HistoryController 的话这些改动在主窗口历史页会「静默丢失」。
    ref.read(historyControllerProvider);
    _commands = ref
        .read(multiWindowGatewayProvider)
        .incoming
        .listen((MultiWindowCommand command) {
      if (command.method != 'refresh') return;
      ref.read(notesControllerProvider.notifier).load();
      ref.read(countdownControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _commands?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.arguments['kind'] as String? ?? 'note';
    if (kind == 'desktop') return const DesktopWidgetApp();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: AppTheme.withAppFont,
      home: Scaffold(
        body: Column(
          children: <Widget>[
            _SubWindowTitleBar(title: kind == 'note' ? '便签' : '倒数日'),
            Expanded(
              child: kind == 'note'
                  ? _NoteWindow(noteId: widget.arguments['noteId'] as String? ?? '')
                  : const _CountdownWindow(),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SubWindowTitleBar extends ConsumerWidget {
  const _SubWindowTitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => ref.read(windowGatewayProvider).startDragging(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.bgSubtle,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: AppTypography.body,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              onPressed: () => ref.read(windowGatewayProvider).close(),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NoteWindow extends ConsumerWidget {
  const _NoteWindow({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesControllerProvider);
    Note? note;
    for (final item in notes.items) {
      if (item.id == noteId) note = item;
    }
    final colors = context.appColors;
    if (note == null) {
      return Center(
        child: Text(
          '暂无便签',
          style: TextStyle(color: colors.textTertiary),
        ),
      );
    }
    final controllers = <TextEditingController>[
      for (final line in note.lines)
        TextEditingController(text: line.text),
    ];
    return Container(
      color: note.backgroundColor.toColor().withValues(alpha: 0.55),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            note.title,
            style: TextStyle(
              fontSize: AppTypography.subtitle,
              fontWeight: AppTypography.medium,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              itemCount: controllers.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.xxs),
              itemBuilder: (BuildContext context, int index) => TextField(
                controller: controllers[index],
                maxLines: null,
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (String value) {
                  final lines = <RichLine>[];
                  for (var i = 0; i < note!.lines.length; i++) {
                    lines.add(
                      i == index
                          ? note.lines[i].copyWith(text: value)
                          : note.lines[i],
                    );
                  }
                  ref
                      .read(notesControllerProvider.notifier)
                      .saveLines(note.id, lines);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _CountdownWindow extends ConsumerWidget {
  const _CountdownWindow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(countdownControllerProvider).items;
    final colors = context.appColors;
    if (items.isEmpty) {
      return Center(
        child: Text('暂无倒数日', style: TextStyle(color: colors.textTertiary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: item.color.toColor().withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.title,
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                item.displayText(
                  DateKey.today(ref.read(clockProvider).now()),
                ),
                style: TextStyle(
                  fontSize: AppTypography.title,
                  fontWeight: AppTypography.bold,
                  color: colors.brand,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
