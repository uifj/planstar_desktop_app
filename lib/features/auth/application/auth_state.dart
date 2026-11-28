library;

import '../domain/auth_models.dart';

enum AuthStatus { restoring, guest, authenticated }

final class AuthState {
  const AuthState({
    this.status = AuthStatus.restoring,
    this.user,
    this.sendingCode = false,
    this.loggingIn = false,
    this.refreshingProfile = false,
    this.signingIn = false,
    this.cooldownSeconds = 0,
    this.failure,
    this.signInResult,
    this.isNewUser = false,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool sendingCode;
  final bool loggingIn;
  final bool refreshingProfile;
  final bool signingIn;
  final int cooldownSeconds;
  final AuthFailure? failure;
  final SignInResult? signInResult;
  final bool isNewUser;

  bool get isLoggedIn => status == AuthStatus.authenticated && user != null;
  bool get isRestoring => status == AuthStatus.restoring;
  bool get busy => sendingCode || loggingIn || refreshingProfile || signingIn;
  bool get inCooldown => cooldownSeconds > 0;
  bool get canSendCode => !inCooldown && !sendingCode && !loggingIn;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? sendingCode,
    bool? loggingIn,
    bool? refreshingProfile,
    bool? signingIn,
    int? cooldownSeconds,
    AuthFailure? failure,
    SignInResult? signInResult,
    bool? isNewUser,
    bool clearUser = false,
    bool clearFailure = false,
    bool clearSignInResult = false,
  }) => AuthState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    sendingCode: sendingCode ?? this.sendingCode,
    loggingIn: loggingIn ?? this.loggingIn,
    refreshingProfile: refreshingProfile ?? this.refreshingProfile,
    signingIn: signingIn ?? this.signingIn,
    cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    failure: clearFailure ? null : (failure ?? this.failure),
    signInResult: clearSignInResult
        ? null
        : (signInResult ?? this.signInResult),
    isNewUser: isNewUser ?? this.isNewUser,
  );
}
