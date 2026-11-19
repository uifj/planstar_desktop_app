/// 存储与跨 engine 同步端口。
library;

import 'dart:async';

/// 跨 Flutter engine 的存储缓存刷新。
///
/// `desktop_multi_window` 的每个窗口都是独立 engine / isolate，
/// 别处的写入不会自动可见。
abstract interface class StorageReloader {
  Future<void> reload();
}

/// 一次跨 engine 的数据变更。
///
/// [revision] 由原生单一真相源单调递增，用于丢弃乱序/重复广播；
/// [origin] 是写入方 engine 标识，用于避免自反馈；
/// [key] 为空表示「全量重载」（非 Windows 降级路径）。
final class DataChange {
  const DataChange({
    required this.key,
    required this.revision,
    required this.origin,
    this.deleted = false,
  });

  final String key;
  final int revision;
  final String origin;
  final bool deleted;

  bool get isFullReload => key.isEmpty;
}

/// 持久化键 → 读模型重载分组的注册表。
///
/// core 不认识任何具体键名：各 feature 在自己的文件里声明映射并注册，
/// 组合根聚合（见 lib/bootstrap/reload_targets.dart）。查询返回 `null`
/// 表示未注册，调用方按全量重载兜底。
final class ReloadTargetRegistry {
  final Map<String, String> _byKey = <String, String>{};
  final Map<String, String> _byPrefix = <String, String>{};

  /// 注册精确键。
  void registerKey(String key, String target) => _byKey[key] = target;

  /// 注册键前缀（同一 feature 的多个键共享一个重载分组）。
  void registerPrefix(String prefix, String target) =>
      _byPrefix[prefix] = target;

  /// 查询重载分组；未注册返回 `null`。精确键优先于前缀。
  String? targetFor(String key) {
    final exact = _byKey[key];
    if (exact != null) return exact;
    for (final MapEntry<String, String> entry in _byPrefix.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return null;
  }
}

/// 跨 engine 的「数据已变更」信号。
///
/// Windows 走原生 DataHub 的 EventChannel 广播（事件驱动、带 revision）；
/// 其它平台走文件标记降级（key 为空 → 全量重载）。
abstract interface class CrossEngineSync {
  Future<void> signalChange();

  Stream<DataChange> get changes;
}
