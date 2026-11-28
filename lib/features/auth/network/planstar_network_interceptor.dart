library;

import 'package:dio/dio.dart';

import 'planstar_request_context.dart';

final class PlanstarNetworkInterceptor extends Interceptor {
  PlanstarNetworkInterceptor({required this.context, required this.userAgent});

  final PlanstarRequestContext context;
  final String userAgent;

  static const String sessionHeader = 'psSession';
  static const String deviceHeader = 'dvid';
  static const String captchaHeader = 'psCaptcha';
  static const String loginPath = 'v1/user/login';
  static const String sendLoginCodePath = 'v3/user/sendLoginCode';
  static const String _requestSessionKey = 'planstar.request.session';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['User-Agent'] = userAgent;
    final dvid = context.dvid;
    if (dvid != null && dvid.isNotEmpty) options.headers[deviceHeader] = dvid;

    final cookies = <String>[];
    final existing = options.headers['Cookie'];
    if (existing is String && existing.trim().isNotEmpty) {
      cookies.add(existing.trim().replaceAll(RegExp(r';+$'), ''));
    }
    final session = context.psSession;
    options.extra[_requestSessionKey] = session;
    if (session != null && session.isNotEmpty) {
      cookies.add('$sessionHeader=$session');
    }
    final captcha = context.psCaptcha;
    if (captcha != null && captcha.isNotEmpty) {
      cookies.add('$captchaHeader=$captcha');
    }
    if (cookies.isNotEmpty) options.headers['Cookie'] = cookies.join('; ');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _capture(
      response.headers,
      requestSession: _requestSession(response.requestOptions),
    );
    if (_consumesCaptcha(response.requestOptions)) context.clearCaptcha();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      final requestSession = _requestSession(response.requestOptions);
      _capture(response.headers, requestSession: requestSession);
      if (_consumesCaptcha(response.requestOptions)) context.clearCaptcha();
      if (response.statusCode == 401 &&
          requestSession != null &&
          requestSession == context.psSession &&
          !_consumesCaptcha(response.requestOptions)) {
        context.onUnauthorized?.call();
      }
    }
    handler.next(err);
  }

  String? _requestSession(RequestOptions options) =>
      options.extra[_requestSessionKey] as String?;

  void _capture(Headers headers, {required String? requestSession}) {
    final session =
        _nonEmpty(headers.value(sessionHeader)) ??
        _cookieValue(headers, sessionHeader);
    final canReplaceSession = requestSession == null
        ? !context.hasSession
        : requestSession == context.psSession;
    if (session != null && session != context.psSession && canReplaceSession) {
      context.psSession = session;
    }
    final dvid =
        _nonEmpty(headers.value(deviceHeader)) ??
        _cookieValue(headers, deviceHeader);
    if (dvid != null && dvid != context.dvid) {
      context.dvid = dvid;
      context.onDeviceIdChanged?.call(dvid);
    }
    final captcha =
        _cookieValue(headers, captchaHeader) ??
        _nonEmpty(headers.value(captchaHeader));
    if (captcha != null) context.psCaptcha = captcha;
  }

  static bool _consumesCaptcha(RequestOptions options) {
    if (options.method.toUpperCase() != 'POST') return false;
    final path = Uri.tryParse(options.path)?.path ?? options.path;
    final normalized = path
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
    return normalized == loginPath || normalized == sendLoginCodePath;
  }

  static String? _cookieValue(Headers headers, String name) {
    for (final raw in headers['set-cookie'] ?? const <String>[]) {
      for (final part in raw.split(';')) {
        final item = part.trim();
        final equals = item.indexOf('=');
        if (equals > 0 && item.substring(0, equals) == name) {
          return _nonEmpty(item.substring(equals + 1));
        }
      }
    }
    return null;
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
