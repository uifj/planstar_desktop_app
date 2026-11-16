import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/infrastructure/data_hub.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('planstar_data_hub_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('端口契约', () {
    test('按 key 映射到对应读模型', () {
      expect(reloadTargetFor('planstar.calendar.cells.v1'), 'calendar');
      expect(reloadTargetFor('planstar.calendar.events.v1'), 'calendar');
      expect(reloadTargetFor('planstar.settings.v1'), 'settings');
      expect(reloadTargetFor('planstar.notes.v1'), 'notes');
      expect(reloadTargetFor('planstar.countdowns.v1'), 'countdown');
      expect(reloadTargetFor('planstar.subscriptions.v1'), 'subscription');
      expect(reloadTargetFor('planstar.timetables.v1'), 'timetable');
      expect(reloadTargetFor('planstar.history.v1'), 'history');
      expect(reloadTargetFor('planstar.desktop.card.v2'), 'position');
      expect(reloadTargetFor('unknown.key'), isNull);
    });

    test('空 key 表示全量重载', () {
      expect(const DataChange(key: '', revision: 1, origin: '').isFullReload,
          isTrue);
      expect(
        const DataChange(key: 'planstar.notes.v1', revision: 1, origin: 'a')
            .isFullReload,
        isFalse,
      );
    });
  });

  group('DataHubStore 本地降级实现', () {
    test('读写删清与 keys', () async {
      final hub = await DataHubStore.create(
        forceLocal: true,
        supportDirectory: temp.path,
      );
      addTearDown(hub.dispose);

      expect(await hub.read('a'), isNull);
      await hub.write('a', '1');
      await hub.write('b', '2');
      expect(await hub.read('a'), '1');
      expect(await hub.keys(), <String>{'a', 'b'});

      await hub.delete('a');
      expect(await hub.read('a'), isNull);
      expect(await hub.keys(), <String>{'b'});

      await hub.clear();
      expect(await hub.keys(), isEmpty);
    });

    test('每次写入都原子落盘，可解析且无 tmp 残留', () async {
      final hub = await DataHubStore.create(
        forceLocal: true,
        supportDirectory: temp.path,
      );
      addTearDown(hub.dispose);

      await hub.write('planstar.calendar.cells.v1', '中文"引号"与\n换行');
      final file = File('${temp.path}/$dataHubFileName');
      expect(await file.exists(), isTrue);
      expect(await File('${file.path}.tmp').exists(), isFalse);
      final decoded = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      expect(decoded['revision'], isA<int>());
      final entries = (decoded['entries'] as Map).cast<String, Object?>();
      expect(entries['planstar.calendar.cells.v1'], '中文"引号"与\n换行');
    });

    test('冷启动从 shared_preferences.json 迁移（去掉 flutter. 前缀）', () async {
      await File('${temp.path}/$legacyPrefsFileName').writeAsString(
        jsonEncode(<String, Object?>{
          'flutter.planstar.calendar.cells.v1': '[{"date":"2026-11-17"}]',
          'flutter.planstar.settings.v1': '{"themeMode":"dark"}',
        }),
      );
      final hub = await DataHubStore.create(
        forceLocal: true,
        supportDirectory: temp.path,
      );
      addTearDown(hub.dispose);

      expect(
        await hub.read('planstar.calendar.cells.v1'),
        '[{"date":"2026-11-17"}]',
      );
      expect(await hub.read('planstar.settings.v1'), '{"themeMode":"dark"}');
      // 原文件保留作为回滚备份。
      expect(await File('${temp.path}/$legacyPrefsFileName').exists(), isTrue);
    });

    test('外部修改（模拟另一 engine）能按 key 发出 DataChange', () async {
      final hub = await DataHubStore.create(
        forceLocal: true,
        supportDirectory: temp.path,
      );
      addTearDown(hub.dispose);
      await hub.write('planstar.notes.v1', 'v1');

      final file = File('${temp.path}/$dataHubFileName');
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      decoded['revision'] = 99;
      (decoded['entries'] as Map)['planstar.notes.v1'] = 'v2';
      await file.writeAsString(jsonEncode(decoded));

      final change = await hub.changes.first.timeout(
        const Duration(seconds: 3),
      );
      expect(change.key, 'planstar.notes.v1');
      expect(change.revision, 99);
      expect(await hub.read('planstar.notes.v1'), 'v2');
    });

    test('reload() 能重取快照', () async {
      final hub = await DataHubStore.create(
        forceLocal: true,
        supportDirectory: temp.path,
      );
      addTearDown(hub.dispose);
      await hub.write('planstar.calendar.cells.v1', 'initial');

      final file = File('${temp.path}/$dataHubFileName');
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      decoded['revision'] = 500;
      (decoded['entries'] as Map)['planstar.calendar.cells.v1'] = 'refreshed';
      await file.writeAsString(jsonEncode(decoded));

      await hub.reload();
      expect(await hub.read('planstar.calendar.cells.v1'), 'refreshed');
    });
  });
}
