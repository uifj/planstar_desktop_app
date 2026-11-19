/// DataHub 跨 engine 同步的双端契约单一真实源（ADR-0007）。
///
/// 约束登记：Pigeon v30 的 native interop 模式是 preview 且仅支持
/// Android/iOS/macOS；Windows 走平台通道模式（CppOptions）。C++ 生成器
/// **不支持 @EventChannelApi**（仅 Swift/Kotlin/Dart 支持），因此广播流
/// 用 @FlutterApi（host → Dart 推送）建模，双端代码全部由 Pigeon 生成，
/// 彻底消除手写 MethodChannel/EventChannel 字符串分发。复查条件：Pigeon
/// 官方宣布 Windows interop 稳定且支持事件流时重评（见 ADR-0007）。
///
/// 生成命令（仓库根）：dart run pigeon --input pigeons/data_hub.dart
/// 生成物入库且不得手改（AGENTS.md §6 单一真实源）。
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/infrastructure/generated/data_hub.g.dart',
    dartOptions: DartOptions(),
    cppOptions: CppOptions(namespace: 'planstar_data_hub'),
    cppHeaderOut: 'windows/runner/generated/data_hub.g.h',
    cppSourceOut: 'windows/runner/generated/data_hub.g.cpp',
  ),
)
library;

import 'package:pigeon/pigeon.dart';

/// 全量快照：单调 revision + 键值表。configure/snapshot 的返回。
class DataHubSnapshot {
  DataHubSnapshot({required this.revision, required this.entries});

  int revision;
  Map<String, String> entries;
}

/// 写操作结果：ok=false 时原生层已回滚数据与 revision，error 携带原因。
class WriteResult {
  WriteResult({required this.ok, required this.revision, this.error});

  bool ok;
  int revision;
  String? error;
}

/// 广播载荷：一次变更的 key/revision/origin/deleted/value。
/// origin 是发起方 engine 标识，接收端据此跳过自反馈。
class DataChangePayload {
  DataChangePayload({
    required this.key,
    required this.revision,
    required this.origin,
    required this.deleted,
    this.value,
  });

  String key;
  int revision;
  String origin;
  bool deleted;
  String? value;
}

/// Dart → 原生：进程级 DataHub 单例的命令面。
@HostApi()
abstract class DataHubHostApi {
  /// 首次配置落盘路径与冷启动数据，返回当前快照（幂等，重复调用只回快照）。
  DataHubSnapshot configure(String filePath, Map<String, String> entries);

  /// 取当前全量快照（reload 用）。
  DataHubSnapshot snapshot();

  WriteResult write(String key, String value, String origin);

  WriteResult delete(String key, String origin);

  WriteResult clear();

  /// 释放本 engine 的广播订阅（dispose 时调用），避免向已销毁 engine 推送。
  void release();
}

/// 原生 → Dart：变更广播。每个 engine 注册一个接收器，原生层持有多 engine
/// 代理向量逐一推送（取代旧 EventChannel sinks）。
@FlutterApi()
abstract class DataHubFlutterApi {
  void dataChanged(DataChangePayload payload);
}
