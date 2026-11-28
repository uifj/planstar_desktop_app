library;

import 'package:core/result.dart';

import 'auth_models.dart';

abstract interface class AuthRepository {
  Future<Result<SendCodeOutcome>> sendLoginCode(
    String phone, {
    String? captcha,
  });

  Future<Result<AuthSession>> loginWithCode(
    String phone,
    String code, {
    String? captcha,
  });

  Future<Result<AuthSession>> loginWithPassword(
    String phone,
    String password, {
    String? captcha,
  });

  Future<Result<List<int>>> fetchCaptchaImage();

  Future<AuthSession?> restoreSession();

  Future<void> logout();

  Future<Result<AuthUser>> refreshProfile();

  Future<Result<SignInResult>> fetchSignInStatus();

  Future<Result<SignInResult>> signIn();
}
