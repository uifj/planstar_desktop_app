/// 将 pub.dev 平台存储插件适配为 `packages/infras/core` 的存储端口。
///
/// 组合根之外没有任何地方直接 import `shared_preferences` /
/// `flutter_secure_storage`；仓储只认识 `KeyValueStore` / `SecureStore`。
library;

import 'package:core/storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ports.dart';

/// `SharedPreferences` → [KeyValueStore] + [StorageReloader]。
///
/// [onWrite] 是跨 engine 同步的唯一注入点：所有仓储最终都走 `write`，
/// 在这里发一次信号，其它 engine 就能刷新自己的内存缓存并重新载入。
final class SharedPreferencesStore implements KeyValueStore, StorageReloader {
  const SharedPreferencesStore(this._prefs, {this.onWrite});

  final SharedPreferences _prefs;
  final Future<void> Function()? onWrite;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
    await onWrite?.call();
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
    await onWrite?.call();
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
    await onWrite?.call();
  }

  @override
  Future<Set<String>> keys() async => _prefs.getKeys();

  @override
  Future<void> reload() => _prefs.reload();
}

/// `flutter_secure_storage` → [SecureStore]。
///
/// 与 [SharedPreferencesStore] 是**不同类型**：编译器会拦住
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
