/// 云同步状态。账号身份由认证模块提供，此处只保存同步进度。
library;

enum SyncStatus { idle, syncing, success, failure }

final class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncAt,
    this.uploaded = 0,
    this.downloaded = 0,
    this.dirtyCount = 0,
    this.autoSync = false,
    this.message,
  });

  final SyncStatus status;
  final DateTime? lastSyncAt;
  final int uploaded;
  final int downloaded;
  final int dirtyCount;
  final bool autoSync;
  final String? message;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    int? uploaded,
    int? downloaded,
    int? dirtyCount,
    bool? autoSync,
    String? message,
    bool clearMessage = false,
  }) => SyncState(
    status: status ?? this.status,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    uploaded: uploaded ?? this.uploaded,
    downloaded: downloaded ?? this.downloaded,
    dirtyCount: dirtyCount ?? this.dirtyCount,
    autoSync: autoSync ?? this.autoSync,
    message: clearMessage ? null : (message ?? this.message),
  );

  static const SyncState initial = SyncState();
}
