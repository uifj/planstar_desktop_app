import 'dart:async';
import 'dart:io';

import 'package:core/result.dart';
import 'package:flutter/services.dart';

import 'generated/app_localizations.dart';

/// Converts a structured [Failure] into safe, localized presentation text.
///
/// [Failure.message] is diagnostic data and is deliberately never read here.
/// Server-provided codes are matched only against this explicit allowlist;
/// unknown codes fall back to the HTTP status or failure type.
String failureLabel(Failure failure, AppLocalizations l10n) {
  final code = failure.code.trim().toUpperCase();
  switch (code) {
    case 'REQUEST_CANCELLED':
    case 'CANCELLED':
    case 'CANCELED':
      return l10n.failureCancelled;
    case 'TIMEOUT':
    case 'REQUEST_TIMEOUT':
      return l10n.failureTimeout;
    case 'BAD_CERTIFICATE':
    case 'CERTIFICATE_ERROR':
      return l10n.failureCertificate;
    case 'UNAUTHORIZED':
    case 'AUTHENTICATION_FAILED':
    case 'LOGIN_REQUIRED':
    case 'INVALID_CREDENTIALS':
      return l10n.failureAuthentication;
    case 'SESSION_EXPIRED':
    case 'TOKEN_EXPIRED':
      return l10n.failureSessionExpired;
  }

  // A concrete HTTP status is more specific than a generic server/business code.
  switch (failure.statusCode) {
    case 400:
      return l10n.failureBadRequest;
    case 401:
      return l10n.failureAuthentication;
    case 403:
      return l10n.failureForbidden;
    case 404:
      return l10n.failureNotFound;
    case 408:
      return l10n.failureTimeout;
    case 409:
      return l10n.failureConflict;
    case 422:
      return l10n.failureValidation;
    case 429:
      return l10n.failureRateLimit;
    default:
      if (failure.statusCode != null && failure.statusCode! >= 500) {
        return l10n.failureServer;
      }
      if (failure.statusCode != null && failure.statusCode! >= 400) {
        return l10n.failureBadRequest;
      }
  }

  switch (code) {
    case 'FORBIDDEN':
    case 'PERMISSION_DENIED':
    case 'ACCESS_DENIED':
      return l10n.failureForbidden;
    case 'NOT_FOUND':
      return l10n.failureNotFound;
    case 'CONFLICT':
    case 'VERSION_CONFLICT':
      return l10n.failureConflict;
    case 'TOO_MANY_REQUESTS':
    case 'RATE_LIMITED':
      return l10n.failureRateLimit;
    case 'BAD_REQUEST':
    case 'INVALID_ARGUMENT':
      return l10n.failureBadRequest;
    case 'VALIDATION_ERROR':
    case 'INPUT_ERROR':
    case 'INVALID_INPUT':
      return l10n.failureValidation;
    case 'PARSE_ERROR':
    case 'INVALID_RESPONSE':
    case 'MALFORMED_RESPONSE':
    case 'MISSING_ENVELOPE':
      return l10n.failureData;
    case 'LOCAL_IO_ERROR':
    case 'STORAGE_ERROR':
    case 'CONFIG_LOAD_FAILED':
      return l10n.failureLocalData;
    case 'FILE_ERROR':
    case 'IO_ERROR':
      return l10n.failureFile;
    case 'NETWORK_ERROR':
    case 'CONNECTION_ERROR':
      return l10n.failureNetwork;
    case 'OFFLINE':
    case 'NO_NETWORK':
    case 'CACHE_MISS':
      return l10n.failureOffline;
    case 'SERVER_ERROR':
    case 'HTTP_ERROR':
    case 'UNKNOWN':
      return l10n.failureServer;
    case 'BIZ_ERROR':
    case 'BUSINESS_ERROR':
    case 'UNEXPECTED':
    case 'UPLOAD_ERROR':
      return l10n.failureGeneric;
  }

  return switch (failure.type) {
    FailureType.server => l10n.failureServer,
    FailureType.network => l10n.failureNetwork,
    FailureType.authentication => l10n.failureAuthentication,
    FailureType.timeout => l10n.failureTimeout,
    FailureType.data => l10n.failureData,
    FailureType.validation => l10n.failureValidation,
  };
}

/// Categorizes a caught object without exposing its message or [toString].
String caughtErrorLabel(Object error, AppLocalizations l10n) {
  if (error is Failure) return failureLabel(error, l10n);
  if (error is TimeoutException) return l10n.failureTimeout;
  if (error is HandshakeException) return l10n.failureCertificate;
  if (error is SocketException) return l10n.failureNetwork;
  if (error is FileSystemException) return l10n.failureFile;
  if (error is IOException) return l10n.failureLocalData;
  if (error is FormatException) return l10n.failureData;
  if (error is ArgumentError) return l10n.failureValidation;
  if (error is PlatformException) {
    final code = error.code.trim().toUpperCase();
    if (code == 'NETWORK' || code == 'NETWORK_ERROR') {
      return l10n.failureNetwork;
    }
    if (code == 'TIMEOUT') return l10n.failureTimeout;
    if (code == 'CERTIFICATE' || code == 'BAD_CERTIFICATE') {
      return l10n.failureCertificate;
    }
    if (code == 'FILE' || code == 'FILE_ERROR') return l10n.failureFile;
    if (code == 'STORAGE' || code == 'STORAGE_ERROR') {
      return l10n.failureLocalData;
    }
    if (code == 'PERMISSION' || code == 'PERMISSION_DENIED') {
      return l10n.failureForbidden;
    }
    if (code == 'INVALID_INPUT' || code == 'INVALID_ARGUMENT') {
      return l10n.failureValidation;
    }
    return l10n.failurePlatform;
  }
  if (error is StateError) return l10n.failureData;
  return l10n.failureGeneric;
}
