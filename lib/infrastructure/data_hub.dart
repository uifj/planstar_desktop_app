/// 跨 engine 的单一真相源（方案 A 的 Dart 侧）。
///
/// 背景：`shared_preferences_windows` 的 `getAll()` 返回每个 isolate 自己
/// 的 `_cachedPreferences`，而 legacy `SharedPreferences.reload()` 并不通知
/// 平台实现丢弃缓存——因此「写盘 + 标记文件 + reload」这条旧链路在 Windows
/// 上从来不会把另一个 engine 的数据读进来。
///
/// 现在所有写操作经 Pigeon（`pigeons/planstar_api.dart`）汇聚到同进程的原生
/// [DataHub] 串行执行，成功后由类型安全的 FlutterApi 回调广播带单调 revision
/// 的增量。本类同时实现 `KeyValueStore` / `StorageReloader` / `CrossEngineSync`
/// 三个端口，领域层与各 controller 无需改动。
///
/// Windows 与 macOS 使用同进程原生 DataHub；其他平台或原生通道缺失时
/// 自动降级为 [_LocalBackend]（独占文件锁 + 原子写 + revision 轮询）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/ports.dart';
import 'desktop_platform_config.dart';
import 'pigeon/planstar_api.g.dart';

const String dataHubFileName = 'planstar_data_hub.json';
const String legacyPrefsFileName = 'shared_preferences.json';

abstract interface class _Backend {
  Future<void> initialize();

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> clear();

  Future<Set<String>> keys();

  Future<void> reload();

  Stream<DataChange> get changes;

  void dispose();
}

/// 三个端口共用同一个实例，避免「缓存 A / 通知 B / 重载人 C」三份状态。
final class DataHubStore
    implements KeyValueStore, StorageReloader, CrossEngineSync {
  DataHubStore._(this._backend);

  final _Backend _backend;

  /// 组合根调用一次。平台能力探测 + 旧数据迁移都在这里完成。
  static Future<DataHubStore> create({
    bool forceLocal = false,
    String? supportDirectory,
  }) async {
    final useNative =
        !forceLocal &&
        !kIsWeb &&
        desktopUsesNativeDataHub(defaultTargetPlatform);
    if (useNative) {
      try {
        final backend = _NativeBackend(supportDirectory: supportDirectory);
        await backend.initialize();
        return DataHubStore._(backend);
      } on Object {
        // 原生通道未注册（单元测试 / 旧构建）时降级，不阻断启动。
      }
    }
    final backend = _LocalBackend(supportDirectory: supportDirectory);
    await backend.initialize();
    return DataHubStore._(backend);
  }

  @override
  Future<String?> read(String key) => _backend.read(key);

  @override
  Future<void> write(String key, String value) => _backend.write(key, value);

  @override
  Future<void> delete(String key) => _backend.delete(key);

  @override
  Future<void> clear() => _backend.clear();

  @override
  Future<Set<String>> keys() => _backend.keys();

  @override
  Future<void> reload() => _backend.reload();

  /// 兼容旧端口：新架构的写本身就会产生广播，这里无需额外信号。
  @override
  Future<void> signalChange() async {}

  @override
  Stream<DataChange> get changes => _backend.changes;

  /// 应用退出时释放事件订阅与轮询定时器。
  void dispose() => _backend.dispose();
}

/// Windows：原生进程级 DataHub（Pigeon HostApi + FlutterApi）。
final class _NativeBackend implements _Backend, DataHubEventsFlutterApi {
  _NativeBackend({this.supportDirectory});

  final String? supportDirectory;
  final DataHubHostApi _api = DataHubHostApi();
  final StreamController<DataChange> _changes =
      StreamController<DataChange>.broadcast();
  final Map<String, String> _entries = <String, String>{};

  late final String _origin;
  int _lastRevision = 0;
  // 本 engine 自己提交的 revision。广播先于 method result 到达时用于
  // 补偿去重；但主过滤靠 origin，不依赖两条通道的到达顺序。
  final Set<int> _ownRevisions = <int>{};

  @override
  Stream<DataChange> get changes => _changes.stream;

  @override
  Future<void> initialize() async {
    _origin =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 31)}';
    final root =
        supportDirectory ?? (await getApplicationSupportDirectory()).path;
    final entries = await _loadInitialEntries(root);
    // 先挂上原生 → Dart 的回调，避免 configure 期间的广播丢失。
    DataHubEventsFlutterApi.setUp(this);
    try {
      final configured = await _api.configure(
        '$root/$dataHubFileName',
        entries.entries
            .map(
              (MapEntry<String, String> e) =>
                  DataHubEntryDto(key: e.key, value: e.value),
            )
            .toList(growable: false),
      );
      _adoptSnapshot(configured);
    } on PlatformException catch (error) {
      DataHubEventsFlutterApi.setUp(null);
      throw StateError('DataHub 初始化失败：${error.message ?? error.code}');
    }
  }

  /// Pigeon 生成的类型化回调（原 EventChannel 的动态 Map 解码已移除）。
  @override
  void onDataChanged(DataChangeDto change) {
    _onChange(
      key: change.key,
      revision: change.revision,
      origin: change.origin,
      deleted: change.deleted,
      value: change.value,
    );
  }

  void _adoptSnapshot(DataHubSnapshotDto snapshot) {
    _entries
      ..clear()
      ..addEntries(
        snapshot.entries.map(
          (DataHubEntryDto e) => MapEntry<String, String>(e.key, e.value),
        ),
      );
    if (snapshot.revision > _lastRevision) {
      _lastRevision = snapshot.revision;
    }
  }

  void _onChange({
    required String key,
    required int revision,
    required String origin,
    required bool deleted,
    required String? value,
  }) {
    // 单调推进：只丢弃重复的旧广播，不因 method result 跳过任何一次变更。
    if (revision <= _lastRevision) return;
    _lastRevision = revision;
    _ownRevisions.removeWhere((int r) => r < revision);
    // 必须放在应用 value 之前：自己的写入已由 _applyOk 乐观更新。
    if (origin.isNotEmpty && origin == _origin) return;
    if (deleted) {
      if (key.isEmpty) {
        _entries.clear();
      } else {
        _entries.remove(key);
      }
    } else if (value != null) {
      _entries[key] = value;
    }
    // 自己提交的写入：本地已乐观更新且副作用由领域事件处理，跳过广播，
    // 避免重复 load / 重复 dirty 计数。
    if (_ownRevisions.remove(revision)) return;
    _changes.add(
      DataChange(
        key: key,
        revision: revision,
        origin: origin,
        deleted: deleted,
      ),
    );
  }

  @override
  Future<String?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, String value) async {
    final int revision = await _guard(
      () => _api.write(key, value, _origin),
      'write($key)',
    );
    _applyOk(key, value, false, revision);
  }

  @override
  Future<void> delete(String key) async {
    final int revision = await _guard(
      () => _api.delete(key, _origin),
      'delete($key)',
    );
    _applyOk(key, null, true, revision);
  }

  @override
  Future<void> clear() async {
    final snapshot = await _guard(_api.clear, 'clear');
    _entries.clear();
    _adoptSnapshot(snapshot);
  }

  /// 原生写入失败会抛 `PlatformException`，这里统一转换为领域层使用的
  /// `StateError`，语义与改造前的动态 Map 结果完全一致。
  Future<T> _guard<T>(Future<T> Function() action, String label) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      throw StateError('DataHub $label 失败：${error.message ?? error.code}');
    }
  }

  void _applyOk(String key, String? value, bool deleted, int revision) {
    if (deleted) {
      _entries.remove(key);
    } else if (value != null) {
      _entries[key] = value;
    }
    _ownRevisions.add(revision);
  }

  @override
  Future<Set<String>> keys() async => _entries.keys.toSet();

  @override
  Future<void> reload() async {
    final snapshot = await _api.snapshot();
    _adoptSnapshot(snapshot);
  }

  @override
  void dispose() {
    DataHubEventsFlutterApi.setUp(null);
    _changes.close();
  }
}

/// 非 Windows / 原生通道缺失：跨进程文件锁 + 原子写 + revision 轮询降级。
final class _LocalBackend implements _Backend {
  _LocalBackend({this.supportDirectory});

  final String? supportDirectory;
  final StreamController<DataChange> _changes =
      StreamController<DataChange>.broadcast();
  final Map<String, String> _entries = <String, String>{};

  late File _file;
  int _seenRevision = 0;
  Timer? _timer;
  Future<void> _queue = Future<void>.value();
  bool _polling = false;

  @override
  Stream<DataChange> get changes => _changes.stream;

  @override
  Future<void> initialize() async {
    final root =
        supportDirectory ?? (await getApplicationSupportDirectory()).path;
    _file = File('$root/$dataHubFileName');
    final entries = await _loadInitialEntries(root);
    await _mutate((Map<String, String> current, int revision) {
      for (final entry in entries.entries) {
        current.putIfAbsent(entry.key, () => entry.value);
      }
    });
    _timer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(_poll()),
    );
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      if (!await _file.exists()) return;
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) return;
      final revision = (decoded['revision'] as num?)?.toInt() ?? 0;
      if (revision <= _seenRevision) return;
      _seenRevision = revision;
      final raw = decoded['entries'];
      if (raw is! Map) return;
      final next = raw.map(
        (Object? k, Object? v) => MapEntry<String, String>('$k', '$v'),
      );
      final changedKeys = <String>{
        ..._entries.keys.where((String k) => !next.containsKey(k)),
        ...next.keys.where((String k) => _entries[k] != next[k]),
      };
      _entries
        ..clear()
        ..addAll(next);
      for (final key in changedKeys) {
        _changes.add(
          DataChange(
            key: key,
            revision: revision,
            origin: '',
            deleted: !next.containsKey(key),
          ),
        );
      }
    } on Object {
      // 原子写保证不会读到半截 JSON；偶发 IO 错误留给下一轮补偿。
    } finally {
      _polling = false;
    }
  }

  Future<File> _acquireLock() async {
    final lock = File('${_file.path}.lock');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (true) {
      try {
        await lock.create(exclusive: true);
        return lock;
      } on FileSystemException {
        if (await lock.exists()) {
          try {
            final modified = (await lock.stat()).modified;
            if (DateTime.now().difference(modified) >
                const Duration(seconds: 30)) {
              await lock.delete();
              continue;
            }
          } on FileSystemException {
            // 另一个 writer 可能刚释放锁，下一轮重新尝试。
          }
        }
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('DataHub 文件锁等待超时');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  Future<void> _mutate(
    void Function(Map<String, String> entries, int revision) mutation,
  ) async {
    final lock = await _acquireLock();
    try {
      var diskEntries = <String, String>{};
      var diskRevision = 0;
      if (await _file.exists()) {
        try {
          final decoded = jsonDecode(await _file.readAsString());
          if (decoded is Map && decoded['entries'] is Map) {
            diskEntries = (decoded['entries'] as Map).map(
              (Object? k, Object? v) => MapEntry<String, String>('$k', '$v'),
            );
            diskRevision = (decoded['revision'] as num?)?.toInt() ?? 0;
          }
        } on Object {
          // 损坏文件由本次原子写重建，不复用另一个 engine 的内存快照。
        }
      }
      final revision = diskRevision + 1;
      mutation(diskEntries, revision);
      final tmp = File(
        '${_file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      try {
        await tmp.writeAsString(
          jsonEncode(<String, Object?>{
            'revision': revision,
            'entries': diskEntries,
          }),
          flush: true,
        );
        await tmp.rename(_file.path);
      } finally {
        if (await tmp.exists()) await tmp.delete();
      }
      _entries
        ..clear()
        ..addAll(diskEntries);
      _seenRevision = revision;
    } finally {
      if (await lock.exists()) await lock.delete();
    }
  }

  Future<void> _enqueue(String? key, String? value, bool deleted) =>
      _queue = _queue.then(
        (_) => _mutate((entries, revision) {
          if (deleted) {
            entries.remove(key);
          } else if (key != null && value != null) {
            entries[key] = value;
          } else {
            entries.clear();
          }
        }),
      );

  @override
  Future<String?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, String value) => _enqueue(key, value, false);

  @override
  Future<void> delete(String key) => _enqueue(key, null, true);

  @override
  Future<void> clear() => _enqueue(null, null, false);

  @override
  Future<Set<String>> keys() async => _entries.keys.toSet();

  @override
  Future<void> reload() async => _poll();

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _changes.close();
  }
}

/// 冷启动数据：优先读 DataHub 文件；不存在时从旧 shared_preferences.json
/// 一次性迁移（去掉 `flutter.` 前缀），原文件保留作为回滚备份。
Future<Map<String, String>> _loadInitialEntries(String dir) async {
  final hub = File('$dir/$dataHubFileName');
  if (await hub.exists()) {
    try {
      final decoded = jsonDecode(await hub.readAsString());
      if (decoded is Map && decoded['entries'] is Map) {
        return (decoded['entries'] as Map).map(
          (Object? k, Object? v) => MapEntry<String, String>('$k', '$v'),
        );
      }
    } on Object {
      // 落到迁移分支。
    }
  }
  final legacy = File('$dir/$legacyPrefsFileName');
  if (await legacy.exists()) {
    try {
      final decoded = jsonDecode(await legacy.readAsString());
      if (decoded is Map) {
        final result = <String, String>{};
        for (final entry in decoded.entries) {
          final rawKey = '${entry.key}';
          final key = rawKey.startsWith('flutter.')
              ? rawKey.substring('flutter.'.length)
              : rawKey;
          final value = entry.value;
          if (value is String) {
            result[key] = value;
          } else if (value != null) {
            result[key] = jsonEncode(value);
          }
        }
        return result;
      }
    } on Object {
      // 旧文件损坏时不阻断启动。
    }
  }
  return <String, String>{};
}
