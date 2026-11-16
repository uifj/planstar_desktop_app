/// 导入 / 导出应用服务：数据库 JSON / 文本 / CSV（Excel 兼容）。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/value_objects.dart';
import '../../calendar/application/calendar_controllers.dart';
import '../../calendar/domain/repositories.dart';

enum ExportFormat {
  database('数据库文件（可再导入）', 'json'),
  text('文本文件', 'txt'),
  csv('Excel 文件（CSV）', 'csv');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}

enum ExportRange { sixMonths, allTime, custom }

final class TransferState {
  const TransferState({this.busy = false, this.message});

  final bool busy;
  final String? message;

  TransferState copyWith({bool? busy, String? message}) => TransferState(
        busy: busy ?? this.busy,
        message: message ?? this.message,
      );
}

final transferControllerProvider =
    NotifierProvider<TransferController, TransferState>(
  TransferController.new,
);

final class TransferController extends Notifier<TransferState> {
  @override
  TransferState build() => const TransferState();

  CalendarRepository get _repository =>
      ref.read(calendarRepositoryProvider);

  Future<CalendarSnapshot> _snapshot() async {
    final events = await _repository.allEvents();
    final cells = await _repository.allCells();
    return CalendarSnapshot(
      events: events.requireData,
      cells: cells.requireData,
      exportedAt: ref.read(clockProvider).now(),
    );
  }

  String _render(
    ExportFormat format,
    CalendarSnapshot snapshot, {
    DateRange? range,
  }) {
    switch (format) {
      case ExportFormat.database:
        return const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
      case ExportFormat.text:
        final buffer = StringBuffer()
          ..writeln('企划星 · 桌面日历清单导出 ${snapshot.exportedAt}')
          ..writeln('────────────────────────────────');
        for (final cell in snapshot.cells) {
          if (range != null && !range.contains(cell.date)) continue;
          buffer.writeln('${cell.date.cnFull}：');
          for (final line in cell.lines) {
            buffer.writeln(
              '  ${line.completed ? "[完成] " : ""}${line.text}',
            );
          }
        }
        return buffer.toString();
      case ExportFormat.csv:
        final rows = <List<String>>[
          <String>['日期', '类型', '内容', '状态', '颜色'],
        ];
        for (final cell in snapshot.cells) {
          if (range != null && !range.contains(cell.date)) continue;
          for (final line in cell.lines) {
            rows.add(<String>[
              cell.date.key,
              '单元格',
              line.text,
              line.completed ? '完成' : '未完成',
              line.color.hex,
            ]);
          }
        }
        for (final event in snapshot.events) {
          if (range != null && !range.contains(event.startDate)) continue;
          rows.add(<String>[
            event.startDate.key,
            event.type.label,
            event.content,
            event.recurrence.kind.label,
            event.color.hex,
          ]);
        }
        return rows
            .map((List<String> row) => row.map(_escapeCsv).join(','))
            .join('\r\n');
    }
  }

  String _escapeCsv(String value) =>
      '"${value.replaceAll('"', '""')}"';

  Future<void> exportTo({
    required ExportFormat format,
    required ExportRange range,
    DateKey? customStart,
    DateKey? customEnd,
  }) async {
    state = state.copyWith(busy: true, message: '正在准备导出…');
    final snapshot = await _snapshot();
    DateRange? effectiveRange;
    final today = DateKey.today(ref.read(clockProvider).now());
    switch (range) {
      case ExportRange.sixMonths:
        effectiveRange = DateRange(today.addDays(-183), today);
      case ExportRange.allTime:
        effectiveRange = null;
      case ExportRange.custom:
        effectiveRange = (customStart != null && customEnd != null)
            ? DateRange(customStart, customEnd)
            : null;
    }
    final content = _render(format, snapshot, range: effectiveRange);
    final suggested =
        'planstar_${today.key}.${format.extension}';
    final path = await ref.read(fileGatewayProvider).pickSavePath(suggested);
    if (path == null) {
      state = state.copyWith(busy: false, message: '已取消导出');
      return;
    }
    final result = await _guardWrite(path, content);
    state = state.copyWith(busy: false, message: result);
  }

  Future<String> _guardWrite(String path, String content) async {
    try {
      await ref.read(fileGatewayProvider).writeText(path, content);
      return '导出成功：$path';
    } catch (error) {
      return '导出失败：$error';
    }
  }

  /// 导入数据库文件：同日期冲突时默认替换（旧版「所有冲突都选择该方法」）。
  Future<void> importFrom({
    bool replaceConflicts = true,
  }) async {
    state = state.copyWith(busy: true, message: '请选择要导入的文件…');
    final path = await ref.read(fileGatewayProvider).pickOpenPath();
    if (path == null) {
      state = state.copyWith(busy: false, message: '已取消导入');
      return;
    }
    try {
      final text = await ref.read(fileGatewayProvider).readText(path);
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        state = state.copyWith(busy: false, message: '导入失败：文件格式不正确');
        return;
      }
      final snapshot = CalendarSnapshot.fromJson(
        decoded.map(
          (Object? k, Object? v) => MapEntry<String, Object?>('$k', v),
        ),
      );
      var imported = 0;
      final existingCells = (await _repository.allCells()).requireData;
      final existingDates = existingCells
          .map((dynamic c) => (c as Object).toString())
          .toSet();
      for (final cell in snapshot.cells) {
        final conflict = existingCells.any((dynamic c) => c.date == cell.date);
        if (conflict && !replaceConflicts) continue;
        await _repository.saveCell(cell);
        imported++;
      }
      for (final event in snapshot.events) {
        await _repository.saveEvent(event);
        imported++;
      }
      await ref.read(calendarControllerProvider.notifier).load();
      state = state.copyWith(
        busy: false,
        message: '导入完成，共 $imported 条记录（冲突键：${existingDates.length}）',
      );
    } catch (error) {
      state = state.copyWith(busy: false, message: '导入失败：$error');
    }
  }
}
