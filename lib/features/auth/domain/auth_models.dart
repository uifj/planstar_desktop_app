library;

import 'package:core/domain.dart';
import 'package:core/result.dart';

final class AuthUser extends ValueObject {
  const AuthUser({
    required this.userId,
    this.userName,
    this.avatar = '',
    this.bio,
    this.gender = 0,
    this.birthday = 0,
    this.mobileNo,
    this.level = 0,
    this.levelLabel = '',
    this.followerNum = 0,
    this.followingNum = 0,
    this.wantWatchNum = 0,
    this.couponCount = 0,
    this.walletBalance = 0,
    this.isDouliUser = false,
    this.badgeIcon,
  });

  final int userId;
  final String? userName;
  final String avatar;
  final String? bio;
  final int gender;
  final int birthday;
  final String? mobileNo;
  final int level;
  final String levelLabel;
  final int followerNum;
  final int followingNum;
  final int wantWatchNum;
  final int couponCount;
  final int walletBalance;
  final bool isDouliUser;
  final String? badgeIcon;

  bool get isValid => userId > 0;

  String get displayName => (userName ?? '').trim();

  String? get maskedMobile {
    final mobile = (mobileNo ?? '').trim();
    if (mobile.length != 11) return mobile.isEmpty ? null : mobile;
    return '${mobile.substring(0, 3)}****${mobile.substring(7)}';
  }

  factory AuthUser.fromJson(Map<String, Object?> json) => AuthUser(
    userId: _int(json['userId'] ?? json['id']),
    userName: _string(json['userName'] ?? json['nickname']),
    avatar: _string(json['avatar'] ?? json['headImg']) ?? '',
    bio: _string(json['bio']),
    gender: _int(json['gender']),
    birthday: _int(json['birthday']),
    mobileNo: _string(json['mobileNo'] ?? json['mobile'] ?? json['phone']),
    level: _int(json['level'] ?? json['userLevel']),
    levelLabel: _string(json['levelLabel']) ?? '',
    followerNum: _int(json['followerNum']),
    followingNum: _int(
      json['followingNum'] ?? json['followCount'] ?? json['followUserCount'],
    ),
    wantWatchNum: _int(
      json['wantWatchNum'] ??
          json['wannaSeeCount'] ??
          json['followActivityCount'],
    ),
    couponCount: _int(json['couponCount']),
    walletBalance: _int(json['walletBalance'] ?? json['balance']),
    isDouliUser: _bool(json['isDouliUser']),
    badgeIcon: _string(json['badgeIcon']),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'userId': userId,
    'userName': userName,
    'avatar': avatar,
    'bio': bio,
    'gender': gender,
    'birthday': birthday,
    'mobileNo': mobileNo,
    'level': level,
    'levelLabel': levelLabel,
    'followerNum': followerNum,
    'followingNum': followingNum,
    'wantWatchNum': wantWatchNum,
    'couponCount': couponCount,
    'walletBalance': walletBalance,
    'isDouliUser': isDouliUser,
    'badgeIcon': badgeIcon,
  };

  Map<String, Object?> toStoredJson() => <String, Object?>{
    ...toJson(),
    'mobileNo': maskedMobile,
  };

  @override
  List<Object?> get props => <Object?>[toJson()];
}

final class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    this.isNewUser = false,
  });

  final AuthUser user;
  final String token;
  final bool isNewUser;
}

final class SendCodeOutcome {
  const SendCodeOutcome({this.cooldownSeconds = 60});

  final int cooldownSeconds;
}

final class SignInResult {
  const SignInResult({
    required this.signed,
    required this.todayReward,
    required this.balance,
    required this.alreadySigned,
    this.signedAt,
  });

  factory SignInResult.fromJson(Map<String, Object?> json) => SignInResult(
    signed: _bool(json['signed']),
    todayReward: _int(json['todayReward']),
    balance: Money.fromMinorUnits(_int(json['balance'])),
    alreadySigned: _bool(json['alreadySigned']),
    signedAt: switch (json['signedAt']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      final String value => DateTime.tryParse(value),
      _ => null,
    },
  );

  final bool signed;
  final int todayReward;

  /// 服务端返回的星币余额，单位为分。
  final Money balance;
  final bool alreadySigned;
  final DateTime? signedAt;
}

enum AuthFailureKind {
  business,
  accountLocked,
  needsCaptcha,
  network,
  timeout,
  unauthorized,
  storage,
  unknown,
}

final class AuthFailure {
  const AuthFailure({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
  });

  final AuthFailureKind kind;
  final String message;
  final String? code;
  final int? statusCode;

  factory AuthFailure.fromFailure(Failure failure) {
    final kind = switch (failure.code) {
      'AUTH_ACCOUNT_LOCKED' => AuthFailureKind.accountLocked,
      'AUTH_NEEDS_CAPTCHA' => AuthFailureKind.needsCaptcha,
      'AUTH_SESSION_WRITE_FAILED' => AuthFailureKind.storage,
      'AUTH_BUSINESS' => AuthFailureKind.business,
      _ => switch (failure.type) {
        FailureType.network => AuthFailureKind.network,
        FailureType.timeout => AuthFailureKind.timeout,
        FailureType.authentication => AuthFailureKind.unauthorized,
        FailureType.validation ||
        FailureType.server => AuthFailureKind.business,
        FailureType.data => AuthFailureKind.unknown,
      },
    };
    final rawMessage = failure.message.trim();
    final message = rawMessage.startsWith('AUTH_') && rawMessage == failure.code
        ? ''
        : rawMessage;
    return AuthFailure(
      kind: kind,
      message: message,
      code: failure.code,
      statusCode: failure.statusCode,
    );
  }

  bool get needsCaptcha => kind == AuthFailureKind.needsCaptcha;
  bool get isAccountLocked => kind == AuthFailureKind.accountLocked;
  bool get isRetryable =>
      kind == AuthFailureKind.network || kind == AuthFailureKind.timeout;
}

int _int(Object? value) => switch (value) {
  final int value => value,
  final num value => value.toInt(),
  final String value => int.tryParse(value) ?? 0,
  _ => 0,
};

bool _bool(Object? value) => switch (value) {
  final bool value => value,
  final num value => value != 0,
  final String value => value == 'true' || value == '1',
  _ => false,
};

String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
