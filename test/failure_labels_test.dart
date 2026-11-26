import 'dart:async';
import 'dart:io';

import 'package:core/result.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/core/result_x.dart';
import 'package:planstar_desktop_app/l10n/l10n.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('failure types have safe zh/en labels', () {
    const failures = <Failure>[
      Failure(
        code: 'UNKNOWN_REMOTE_CODE',
        message: 'private diagnostic',
        type: FailureType.server,
      ),
      Failure.network(message: 'private diagnostic'),
      Failure.unauthorized(message: 'private diagnostic'),
      Failure.timeout(message: 'private diagnostic'),
      Failure(
        code: 'UNKNOWN_REMOTE_CODE',
        message: 'private diagnostic',
        type: FailureType.data,
      ),
      Failure.input(message: 'private diagnostic'),
    ];
    const zhLabels = <String>[
      '服务暂时不可用，请稍后重试。',
      '网络连接失败，请检查网络后重试。',
      '登录状态无效，请重新登录。',
      '请求超时，请稍后重试。',
      '数据读取失败，请稍后重试。',
      '输入内容不符合要求，请检查后重试。',
    ];
    const enLabels = <String>[
      'The service is temporarily unavailable. Please try again later.',
      'Network connection failed. Check your connection and try again.',
      'Your sign-in is invalid. Please sign in again.',
      'The request timed out. Please try again.',
      'Unable to read the data. Please try again.',
      'The input is invalid. Check it and try again.',
    ];

    for (var i = 0; i < failures.length; i++) {
      expect(failureLabel(failures[i], zh), zhLabels[i]);
      expect(failureLabel(failures[i], en), enLabels[i]);
    }
  });

  test('stable business codes select specific localized categories', () {
    const cases = <(Failure, String, String)>[
      (
        Failure(
          code: 'TOKEN_EXPIRED',
          message: 'raw token response',
          type: FailureType.server,
        ),
        '登录已过期，请重新登录。',
        'Your session has expired. Please sign in again.',
      ),
      (
        Failure(
          code: 'BAD_CERTIFICATE',
          message: 'raw certificate detail',
          type: FailureType.network,
        ),
        '安全连接校验失败，请检查网络或证书。',
        'The secure connection could not be verified. Check your network or certificate.',
      ),
      (
        Failure(
          code: 'REQUEST_CANCELLED',
          message: 'raw cancellation detail',
          type: FailureType.network,
        ),
        '操作已取消。',
        'The operation was cancelled.',
      ),
      (
        Failure(
          code: 'CONFLICT',
          message: 'raw conflict detail',
          type: FailureType.server,
        ),
        '数据状态已变化，请刷新后重试。',
        'The data has changed. Refresh and try again.',
      ),
      (
        Failure(
          code: 'RATE_LIMITED',
          message: 'raw rate-limit detail',
          type: FailureType.server,
        ),
        '操作过于频繁，请稍后再试。',
        'Too many attempts. Please wait and try again.',
      ),
      (
        Failure(
          code: 'LOCAL_IO_ERROR',
          message: 'raw local path',
          type: FailureType.data,
        ),
        '本地数据读取失败，请稍后重试。',
        'Unable to read local data. Please try again.',
      ),
    ];

    for (final (failure, zhLabel, enLabel) in cases) {
      expect(failureLabel(failure, zh), zhLabel);
      expect(failureLabel(failure, en), enLabel);
    }
  });

  test('HTTP status overrides generic server codes in both locales', () {
    const cases = <(int, String, String)>[
      (
        400,
        '请求内容有误，请检查后重试。',
        'The request is invalid. Check your input and try again.',
      ),
      (401, '登录状态无效，请重新登录。', 'Your sign-in is invalid. Please sign in again.'),
      (403, '没有执行此操作的权限。', "You don't have permission to perform this action."),
      (
        404,
        '未找到所需内容，它可能已被删除。',
        'The requested content could not be found. It may have been removed.',
      ),
      (408, '请求超时，请稍后重试。', 'The request timed out. Please try again.'),
      (409, '数据状态已变化，请刷新后重试。', 'The data has changed. Refresh and try again.'),
      (
        418,
        '请求内容有误，请检查后重试。',
        'The request is invalid. Check your input and try again.',
      ),
      (
        422,
        '输入内容不符合要求，请检查后重试。',
        'The input is invalid. Check it and try again.',
      ),
      (429, '操作过于频繁，请稍后再试。', 'Too many attempts. Please wait and try again.'),
      (
        500,
        '服务暂时不可用，请稍后重试。',
        'The service is temporarily unavailable. Please try again later.',
      ),
      (
        503,
        '服务暂时不可用，请稍后重试。',
        'The service is temporarily unavailable. Please try again later.',
      ),
    ];

    for (final (status, zhLabel, enLabel) in cases) {
      final failure = Failure(
        code: 'HTTP_ERROR',
        message: 'PRIVATE_SERVER_STACK_9f31',
        type: FailureType.server,
        statusCode: status,
        cause: StateError('PRIVATE_EXCEPTION_7c20'),
        requestId: 'private-request-id',
      );
      expect(failureLabel(failure, zh), zhLabel);
      expect(failureLabel(failure, en), enLabel);
      expect(failureLabel(failure, zh), isNot(contains('PRIVATE_')));
      expect(failureLabel(failure, en), isNot(contains('PRIVATE_')));
    }
  });

  test('unknown codes and raw messages never surface', () {
    const secret = 'PRIVATE_SERVER_TOKEN_6a11 / internal/path';
    final failure = Failure(
      code: 'REMOTE_$secret',
      message: secret,
      type: FailureType.server,
      cause: StateError(secret),
    );

    expect(failureLabel(failure, zh), zh.failureServer);
    expect(failureLabel(failure, en), en.failureServer);
    expect(failureLabel(failure, zh), isNot(contains(secret)));
    expect(failureLabel(failure, en), isNot(contains(secret)));
  });

  test('caught exceptions are categorized without toString or details', () {
    const secret = 'PRIVATE_EXCEPTION_7c20 /Users/private/file';
    final cases = <(Object, String Function(AppLocalizations))>[
      (
        TimeoutException(secret),
        (AppLocalizations l10n) => l10n.failureTimeout,
      ),
      (
        HandshakeException(secret),
        (AppLocalizations l10n) => l10n.failureCertificate,
      ),
      (SocketException(secret), (AppLocalizations l10n) => l10n.failureNetwork),
      (
        FileSystemException(secret, '/Users/private/file'),
        (AppLocalizations l10n) => l10n.failureFile,
      ),
      (FormatException(secret), (AppLocalizations l10n) => l10n.failureData),
      (
        ArgumentError(secret),
        (AppLocalizations l10n) => l10n.failureValidation,
      ),
      (
        PlatformException(code: 'storage', message: secret),
        (AppLocalizations l10n) => l10n.failureLocalData,
      ),
      (
        PlatformException(code: 'unrecognized', message: secret),
        (AppLocalizations l10n) => l10n.failurePlatform,
      ),
      (StateError(secret), (AppLocalizations l10n) => l10n.failureData),
      (Exception(secret), (AppLocalizations l10n) => l10n.failureGeneric),
    ];

    for (final (error, expected) in cases) {
      expect(caughtErrorLabel(error, zh), expected(zh));
      expect(caughtErrorLabel(error, en), expected(en));
      expect(caughtErrorLabel(error, zh), isNot(contains('PRIVATE_')));
      expect(caughtErrorLabel(error, en), isNot(contains('PRIVATE_')));
    }
  });

  test('guardAsync keeps exception details only in cause', () async {
    final detail = FileSystemException('PRIVATE_FILE_DETAIL', '/private/path');
    final result = await guardAsync<int>(() async => throw detail);
    final failure = result.failure!;

    expect(failure.code, 'LOCAL_IO_ERROR');
    expect(failure.message, 'LOCAL_IO_ERROR');
    expect(failure.message, isNot(contains('PRIVATE_FILE_DETAIL')));
    expect(failure.cause, same(detail));
    expect(failureLabel(failure, zh), zh.failureLocalData);
    expect(failureLabel(failure, en), en.failureLocalData);
  });
}
