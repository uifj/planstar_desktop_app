library;

import 'package:core/network.dart';
import 'package:core/result.dart';
import 'package:dio/dio.dart' show Options, ResponseType;

import '../domain/auth_models.dart';

final class PlanstarAccountApi {
  PlanstarAccountApi({required ApiClient client, this.clientType = 11})
    : _client = client;

  final ApiClient _client;
  final int clientType;

  static const String loginPath = 'v1/user/login';
  static const String sendLoginCodePath = 'v3/user/sendLoginCode';
  static const String captchaPath = 'v1/user/captcha';
  static const String profilePath = 'v1/user';
  static const String signInPath = 'v1/user/signIn';

  Future<Result<LoginResponse>> login({
    required String phone,
    String? password,
    String? code,
    String? captcha,
  }) {
    final body = <String, Object?>{
      'ua': phone,
      'ct': clientType,
      if (code != null && code.isNotEmpty) 'code': code,
      if (password != null && password.isNotEmpty) 'pw': password,
      if (captcha != null && captcha.isNotEmpty) 'captcha': captcha,
    };
    return _client.post<LoginResponse>(
      loginPath,
      data: body,
      envelope: const PassthroughEnvelope(),
      parser: (Object? data) => LoginResponse.fromJson(_asMap(data)),
    );
  }

  Future<Result<SendCodeResponse>> sendLoginCode({
    required String phone,
    String? captcha,
  }) => _client.post<SendCodeResponse>(
    sendLoginCodePath,
    data: <String, Object?>{
      'ua': phone,
      if (captcha != null && captcha.isNotEmpty) 'captcha': captcha,
    },
    envelope: const PassthroughEnvelope(),
    parser: (Object? data) => SendCodeResponse.fromJson(_asMap(data)),
  );

  Future<Result<List<int>>> fetchCaptchaImage() => _client.get<List<int>>(
    captchaPath,
    options: Options(responseType: ResponseType.bytes),
    envelope: const PassthroughEnvelope(),
    parser: (Object? data) {
      if (data is List<int>) return data;
      throw const FormatException('图形验证码不是二进制');
    },
  );

  Future<Result<AuthUser>> fetchProfile() => _client.get<AuthUser>(
    profilePath,
    envelope: const PassthroughEnvelope(),
    parser: (Object? data) => AuthUser.fromJson(_asMap(data)),
  );

  Future<Result<SignInResult>> fetchSignInStatus() => _client.get<SignInResult>(
    signInPath,
    envelope: const PassthroughEnvelope(),
    parser: (Object? data) => SignInResult.fromJson(_asMap(data)),
  );

  Future<Result<SignInResult>> signIn() => _client.post<SignInResult>(
    signInPath,
    envelope: const PassthroughEnvelope(),
    parser: (Object? data) => SignInResult.fromJson(_asMap(data)),
  );

  static Map<String, Object?> _asMap(Object? data) => data is Map
      ? data.map(
          (Object? key, Object? value) =>
              MapEntry<String, Object?>('$key', value),
        )
      : <String, Object?>{};
}

final class LoginResponse {
  const LoginResponse({
    required this.needCaptcha,
    required this.newUser,
    this.user,
  });

  final bool needCaptcha;
  final bool newUser;
  final AuthUser? user;

  factory LoginResponse.fromJson(Map<String, Object?> json) {
    final rawUser = json['user'];
    return LoginResponse(
      needCaptcha: _bool(json['needCaptcha']),
      newUser: _bool(json['newUser']),
      user: rawUser is Map
          ? AuthUser.fromJson(
              rawUser.map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>('$key', value),
              ),
            )
          : null,
    );
  }
}

final class SendCodeResponse {
  const SendCodeResponse({
    required this.success,
    required this.needCaptcha,
    this.errorMsg,
  });

  final bool success;
  final bool needCaptcha;
  final String? errorMsg;

  factory SendCodeResponse.fromJson(Map<String, Object?> json) {
    final error = json['errorMsg'];
    return SendCodeResponse(
      success: _bool(json['success']),
      needCaptcha: _bool(json['needCaptcha']),
      errorMsg: error is String && error.trim().isNotEmpty
          ? error.trim()
          : null,
    );
  }
}

bool _bool(Object? value) => switch (value) {
  final bool value => value,
  final num value => value != 0,
  final String value => value == 'true' || value == '1',
  _ => false,
};
