/// 账号与云同步领域模型（旧版 `syncui` / 登录 / VIP 模块）。
library;

import 'package:core/domain.dart';

final class Account extends Entity<String> {
  const Account({
    required String id,
    required this.email,
    required this.displayName,
    this.isVip = false,
    this.autoLogin = false,
    this.readOnly = false,
    this.teamAccount = false,
  }) : super(id);

  final String email;
  final String displayName;
  final bool isVip;
  final bool autoLogin;
  final bool readOnly;
  final bool teamAccount;

  bool get isLoggedIn => id.isNotEmpty;

  Account copyWith({
    String? email,
    String? displayName,
    bool? isVip,
    bool? autoLogin,
    bool? readOnly,
    bool? teamAccount,
  }) => Account(
    id: id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    isVip: isVip ?? this.isVip,
    autoLogin: autoLogin ?? this.autoLogin,
    readOnly: readOnly ?? this.readOnly,
    teamAccount: teamAccount ?? this.teamAccount,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'email': email,
    'displayName': displayName,
    'isVip': isVip,
    'autoLogin': autoLogin,
    'readOnly': readOnly,
    'teamAccount': teamAccount,
  };

  factory Account.fromJson(Map<String, Object?> json) => Account(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    isVip: json['isVip'] as bool? ?? false,
    autoLogin: json['autoLogin'] as bool? ?? false,
    readOnly: json['readOnly'] as bool? ?? false,
    teamAccount: json['teamAccount'] as bool? ?? false,
  );

  static const Account anonymous = Account(
    id: '',
    email: '',
    displayName: '未登录',
  );
}

enum SyncStatus { idle, syncing, success, failure }

final class SyncState {
  const SyncState({
    required this.account,
    this.status = SyncStatus.idle,
    this.lastSyncAt,
    this.uploaded = 0,
    this.downloaded = 0,
    this.dirtyCount = 0,
    this.autoSync = false,
    this.message,
  });

  final Account account;
  final SyncStatus status;
  final DateTime? lastSyncAt;
  final int uploaded;
  final int downloaded;
  final int dirtyCount;
  final bool autoSync;
  final String? message;

  SyncState copyWith({
    Account? account,
    SyncStatus? status,
    DateTime? lastSyncAt,
    int? uploaded,
    int? downloaded,
    int? dirtyCount,
    bool? autoSync,
    String? message,
    bool clearMessage = false,
  }) => SyncState(
    account: account ?? this.account,
    status: status ?? this.status,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    uploaded: uploaded ?? this.uploaded,
    downloaded: downloaded ?? this.downloaded,
    dirtyCount: dirtyCount ?? this.dirtyCount,
    autoSync: autoSync ?? this.autoSync,
    message: clearMessage ? null : (message ?? this.message),
  );

  static const SyncState initial = SyncState(account: Account.anonymous);
}
