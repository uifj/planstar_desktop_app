/// 将 pub.dev 平台存储插件适配为 `packages/infras/core` 的存储端口。
///
/// 组合根之外没有任何地方直接 import `flutter_secure_storage`；
/// 仓储只认识 `KeyValueStore` / `SecureStore`。普通键值存储由 DataHubStore
/// 承担（KeyValueStore + StorageReloader + 跨 engine 同步），不再走
/// shared_preferences（ADR-0002 子项 7 已移除该死代码适配器与依赖）。
library;

import 'package:core/storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// `flutter_secure_storage` → [SecureStore]。
///
/// 与普通键值存储是**不同类型**：编译器会拦住
///「把登录 token 写进普通偏好」这种错误。
final class FlutterSecureStorageAdapter implements SecureStore {
  const FlutterSecureStorageAdapter(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) async =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) async => _storage.delete(key: key);

  @override
  Future<void> clear() async => _storage.deleteAll();

  @override
  Future<Set<String>> keys() async => (await _storage.readAll()).keys.toSet();
}
