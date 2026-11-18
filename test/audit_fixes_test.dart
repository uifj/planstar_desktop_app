import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/features/settings/domain/app_settings.dart';
import 'package:planstar_desktop_app/infrastructure/data_hub.dart';

void main() {
  group('ValueObject 深哈希契约', () {
    test('内容相等的设置对象 hashCode 相等且 Set 不重复', () {
      final a = AppSettings.defaults;
      final b = AppSettings.defaults.copyWith();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(<AppSettings>{a, b}, hasLength(1));
    });

    test('restDays 内容相同但实例不同的设置 hashCode 相等', () {
      final a = AppSettings.defaults.copyWith(restDays: <int>[6, 7]);
      final b = AppSettings.defaults.copyWith(restDays: <int>[6, 7]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('restDays 不同则 hashCode 不同', () {
      final a = AppSettings.defaults.copyWith(restDays: <int>[6, 7]);
      final b = AppSettings.defaults.copyWith(restDays: <int>[1, 2]);
      expect(a == b, isFalse);
    });
  });

  group('DataHub 降级 revision 连续性', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('planstar-hub-audit-');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('重启后写入的 revision 续用磁盘值而非从 0 开始', () async {
      final first = await DataHubStore.create(
        forceLocal: true,
        supportDirectory: temp.path,
      );
      await first.write('planstar.notes.v1', 'v1');
      final file = File('${temp.path}/$dataHubFileName');
      final decoded = jsonDecode(await file.readAsString()) as Map;
      final originalRevision = (decoded['revision'] as num).toInt();
      expect(originalRevision, greaterThan(0));
      first.dispose();

      // 模拟另一个 engine / 进程重启：磁盘已有 revision，本地计数应从它续起。
      final second = await DataHubStore.create(
        forceLocal: true,
        supportDirectory: temp.path,
      );
      addTearDown(second.dispose);
      await second.write('planstar.notes.v1', 'v2');
      final after = jsonDecode(await file.readAsString()) as Map;
      expect(
        (after['revision'] as num).toInt(),
        greaterThan(originalRevision),
      );
    });
  });
}
