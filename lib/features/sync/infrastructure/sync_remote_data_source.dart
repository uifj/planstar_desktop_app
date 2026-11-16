/// 云同步远端数据源：只走 `core` 的 `ApiClient`（永不抛、统一 `Result`）。
library;

import 'package:core/network.dart';
import 'package:core/result.dart';

import '../domain/sync_models.dart';

final class SyncSummary {
  const SyncSummary({
    required this.uploaded,
    required this.downloaded,
    required this.syncedAt,
  });

  final int uploaded;
  final int downloaded;
  final DateTime syncedAt;
}

final class SyncRemoteDataSource {
  const SyncRemoteDataSource({
    required ApiClient api,
    required String endpoint,
  })  : _api = api,
        _endpoint = endpoint;

  final ApiClient _api;
  final String _endpoint;

  Future<Result<Account>> login(String email, String password) =>
      _api.post<Account>(
        '${_endpoint}login',
        data: <String, Object?>{'email': email, 'password': password},
        parser: (Object? data) => Account.fromJson(_asMap(data)),
      );

  Future<Result<SyncSummary>> sync(Map<String, Object?> payload) =>
      _api.post<SyncSummary>(
        '${_endpoint}sync',
        data: payload,
        parser: (Object? data) {
          final map = _asMap(data);
          return SyncSummary(
            uploaded: (map['uploaded'] as num?)?.toInt() ?? 0,
            downloaded: (map['downloaded'] as num?)?.toInt() ?? 0,
            syncedAt: DateTime.tryParse(map['syncedAt'] as String? ?? '') ??
                DateTime.now(),
          );
        },
      );

  static Map<String, Object?> _asMap(Object? data) => data is Map
      ? data.map(
          (Object? k, Object? v) => MapEntry<String, Object?>('$k', v),
        )
      : <String, Object?>{};
}
