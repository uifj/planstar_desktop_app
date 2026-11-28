/// 将 `flutter_secure_storage` 适配为 `packages/infras/core` 的存储端口。
library;

import 'package:core/storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// `flutter_secure_storage` → [SecureStore]。
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
