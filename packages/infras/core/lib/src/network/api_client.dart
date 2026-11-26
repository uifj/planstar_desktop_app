/// `ApiClient`：包一层 Dio，**永不抛**，全部返回 `Result<T>`。
library;

import 'dart:convert';
import 'dart:io';

import 'package:core/result.dart';
import 'package:dio/dio.dart';

import 'failure_carrying_error.dart';
import 'response_envelope.dart';

/// 从错误响应体里抽出的统一信息。
final class _ErrorPayload {
  const _ErrorPayload({this.code, this.requestId});

  final String? code;
  final String? requestId;
}

/// 基于 [Dio] 的 API 客户端。
///
/// 契约：
/// - 所有方法返回 `Future<Result<T>>`，**不抛异常**（含解析失败与非法参数）；
/// - 失败统一归一为 [Failure]，携带 [FailureType] 与业务码；
/// - 信封两级注入：[ApiClient] 构造级默认 + 单次调用覆盖。
final class ApiClient {
  /// 用给定的 [Dio] 与可选构造级信封创建客户端。
  ApiClient(this._dio, {ResponseEnvelope? envelope})
    : _envelope = envelope ?? const PassthroughEnvelope();

  final Dio _dio;
  final ResponseEnvelope _envelope;

  /// 构造级信封（只读，便于诊断）。
  ResponseEnvelope get envelope => _envelope;

  /// GET。
  Future<Result<T>> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    T Function(Object? data)? parser,
    ResponseEnvelope? envelope,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onReceiveProgress,
  }) {
    return _send<T>(
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onReceiveProgress: onReceiveProgress,
      ),
      parser: parser,
      envelope: envelope,
      path: path,
    );
  }

  /// POST。
  Future<Result<T>> post<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    T Function(Object? data)? parser,
    ResponseEnvelope? envelope,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _send<T>(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      parser: parser,
      envelope: envelope,
      path: path,
    );
  }

  /// PUT。
  Future<Result<T>> put<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    T Function(Object? data)? parser,
    ResponseEnvelope? envelope,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _send<T>(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      ),
      parser: parser,
      envelope: envelope,
      path: path,
    );
  }

  /// PATCH。
  Future<Result<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    T Function(Object? data)? parser,
    ResponseEnvelope? envelope,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _send<T>(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      ),
      parser: parser,
      envelope: envelope,
      path: path,
    );
  }

  /// DELETE。
  Future<Result<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    T Function(Object? data)? parser,
    ResponseEnvelope? envelope,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _send<T>(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      ),
      parser: parser,
      envelope: envelope,
      path: path,
    );
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  Future<Result<T>> _send<T>(
    Future<Response<dynamic>> Function() run, {
    required T Function(Object? data)? parser,
    required ResponseEnvelope? envelope,
    required String path,
  }) async {
    try {
      final response = await run();
      return _resolve<T>(response, parser, envelope);
    } on DioException catch (e) {
      return Fail<T>(_handleDioException(e, path));
    } catch (error) {
      // 拦截器若直接抛出携带 Failure 的领域异常（见 FailureCarryingError），
      // 尊重它，不要改写成 UNEXPECTED。
      if (error is FailureCarryingError) {
        return Fail<T>(error.failure);
      }
      // 非 DioException 也不能逃逸：只 catch DioException 的话，
      // 非法 URL / 序列化错误会直接抛到调用方。
      return Fail<T>(
        Failure.server(
          code: 'UNEXPECTED',
          message: 'UNEXPECTED_ERROR',
          cause: error,
        ),
      );
    }
  }

  /// 信封解包 + 数据提取。调用级 [envelope] 覆盖构造级默认。
  Result<T> _resolve<T>(
    Response<dynamic> response,
    T Function(Object? data)? parser,
    ResponseEnvelope? envelope,
  ) {
    final active = envelope ?? _envelope;
    final Object? body = response.data;
    try {
      if (!active.isSuccess(body, response.statusCode)) {
        final err = active.extractError(body, response.statusCode);
        final payload = _errorOf(body);
        return Fail<T>(
          Failure(
            code: err.code ?? payload.code ?? 'BIZ_ERROR',
            // Presentation belongs to the application. Keep server text in
            // the envelope error (cause) for diagnostics only.
            message: 'BUSINESS_ERROR',
            type: FailureType.server,
            statusCode: response.statusCode,
            cause: err,
            requestId: err.requestId ?? payload.requestId,
          ),
        );
      }
      final data = active.extractData(body);
      if (parser != null) {
        return Success<T>(parser(data));
      }
      return Success<T>(data as T);
    } catch (error) {
      // 解析失败属于 data 类（不是服务端错，重试也没用）。
      return Fail<T>(
        Failure(
          code: 'PARSE_ERROR',
          message: 'PARSE_ERROR',
          type: FailureType.data,
          statusCode: response.statusCode,
          cause: error,
        ),
      );
    }
  }

  Failure _handleDioException(DioException e, String path) {
    // 拦截器通过 `error` 携带的领域失败优先——它比任何类型推断都准确。
    final carried = e.error;
    if (carried is FailureCarryingError) {
      return carried.failure;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // dio 5.10+ 新增：响应体 transform 阶段的超时。语义上仍是超时。
      case DioExceptionType.transformTimeout:
        return Failure.timeout(message: 'TIMEOUT', cause: e);
      case DioExceptionType.badCertificate:
        // 证书校验失败必须暴露，不能降级重试。
        return Failure(
          code: 'BAD_CERTIFICATE',
          message: 'BAD_CERTIFICATE',
          type: FailureType.network,
          cause: e,
        );
      case DioExceptionType.cancel:
        return Failure.network(
          code: 'REQUEST_CANCELLED',
          message: 'REQUEST_CANCELLED',
          cause: e,
        );
      case DioExceptionType.connectionError:
        return Failure.network(message: 'NETWORK_ERROR', cause: e);
      case DioExceptionType.badResponse:
        return _mapStatusCode(e.response?.statusCode, e.response?.data, e);
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return Failure.network(message: 'NETWORK_ERROR', cause: e);
        }
        return Failure.server(message: 'UNKNOWN', code: 'UNKNOWN', cause: e);
    }
  }

  Failure _mapStatusCode(int? statusCode, Object? data, DioException cause) {
    final payload = _errorOf(data);
    Failure failure({
      required String code,
      required String message,
      FailureType type = FailureType.server,
    }) => Failure(
      code: payload.code ?? code,
      message: message,
      type: type,
      statusCode: statusCode,
      cause: cause,
      requestId: payload.requestId,
    );

    switch (statusCode) {
      case 400:
        return failure(code: 'BAD_REQUEST', message: 'BAD_REQUEST');
      case 401:
        // 401 仍然交给上层登录失效流程处理；原始响应只保留在 cause。
        return failure(
          code: 'UNAUTHORIZED',
          message: 'UNAUTHORIZED',
          type: FailureType.authentication,
        );
      case 403:
        return failure(
          code: 'FORBIDDEN',
          message: 'FORBIDDEN',
          type: FailureType.authentication,
        );
      case 404:
        return failure(code: 'NOT_FOUND', message: 'NOT_FOUND');
      case 409:
        return failure(code: 'CONFLICT', message: 'CONFLICT');
      case 429:
        return failure(code: 'TOO_MANY_REQUESTS', message: 'TOO_MANY_REQUESTS');
      default:
        if (statusCode != null && statusCode >= 500) {
          return failure(code: 'SERVER_ERROR', message: 'SERVER_ERROR');
        }
        return failure(code: 'HTTP_ERROR', message: 'HTTP_ERROR');
    }
  }

  /// 统一解析错误体：JSON 信封 `{code,message,traceId}` 或旧 `text/plain`。
  ///
  /// JSON 可能是原始 Map，也可能是被 content-type 识别成字符串的正文
  /// （网关/后端混用），所以字符串会再尝试一次 JSON 解码。
  _ErrorPayload _errorOf(Object? data) {
    if (data is Map<Object?, Object?>) return _payloadFromMap(data);
    if (data is List<dynamic>) return const _ErrorPayload();
    if (data is String) {
      final text = data.trim();
      if (text.isEmpty || text.startsWith('<')) {
        return const _ErrorPayload();
      }
      if (text.startsWith('{') || text.startsWith('[')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<Object?, Object?>) return _payloadFromMap(decoded);
        } catch (_) {
          // 不是合法 JSON，按纯文本处理。
        }
      }
      // 非 JSON 响应不进入 Failure；原始 DioException 保留完整响应正文。
      return const _ErrorPayload();
    }
    return const _ErrorPayload();
  }

  _ErrorPayload _payloadFromMap(Map<Object?, Object?> map) {
    final rawCode = map['code'] ?? map['errorCode'];
    final rawTrace =
        map['traceId'] ?? map['trace_id'] ?? map['requestId'] ?? map['reqId'];
    final code = rawCode?.toString();
    return _ErrorPayload(
      code: code == null || code.isEmpty ? null : code,
      requestId: rawTrace?.toString(),
    );
  }
}
