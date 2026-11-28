library;

import 'dart:async';

import 'package:core/domain.dart';
import 'package:core/storage.dart';

import '../domain/auth_models.dart';
import '../network/planstar_request_context.dart';

final class AuthSessionStore {
  AuthSessionStore({
    required AppStore store,
    required PlanstarRequestContext context,
    required IdGenerator idGenerator,
  }) : _store = store,
       _context = context,
       _idGenerator = idGenerator {
    _context.onDeviceIdChanged = (String value) {
      unawaited(
        _serialized(() => _store.preferences.write(deviceIdKey, value)),
      );
    };
  }

  static const String tokenKey = 'psSession';
  static const String profileKey = 'planstar.auth.profile.v1';
  static const String deviceIdKey = 'planstar.auth.dvid.v1';
  static const String loggedOutKey = 'planstar.auth.logged_out.v1';
  static const String _legacyTokenKey = 'planstar.token';
  static const String _legacyAccountKey = 'planstar.sync.account.v1';

  final AppStore _store;
  final PlanstarRequestContext _context;
  final IdGenerator _idGenerator;
  Future<void> _queue = Future<void>.value();
  int _mutationRevision = 0;
  String? _activeToken;

  int get mutationRevision => _mutationRevision;
  String? get activeToken => _activeToken;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<AuthSession?> read() {
    final revision = _mutationRevision;
    return _serialized(() async {
      try {
        var deviceId = await _store.preferences.read(deviceIdKey);
        if (deviceId == null || deviceId.isEmpty) {
          deviceId = _idGenerator.next();
          _context.dvid = deviceId;
          await _store.preferences.write(deviceIdKey, deviceId);
        } else {
          _context.dvid = deviceId;
        }
        final loggedOut = await _store.preferences.read(loggedOutKey) == 'true';
        final token = await _store.secure.read(tokenKey);
        final profile = await _store.preferences.readJson(profileKey);
        if (revision != _mutationRevision) {
          _context.psSession = _activeToken;
          return null;
        }
        if (loggedOut || token == null || token.isEmpty || profile == null) {
          return null;
        }
        final user = AuthUser.fromJson(profile);
        if (!user.isValid) return null;
        final storedMobile = user.toStoredJson()['mobileNo'];
        if (profile['mobileNo'] != storedMobile) {
          await _store.preferences.writeJson(profileKey, user.toStoredJson());
        }
        _activeToken = token;
        _context.psSession = token;
        return AuthSession(user: user, token: token);
      } catch (_) {
        return null;
      }
    });
  }

  Future<void> write(AuthSession session) {
    _mutationRevision++;
    return _serialized(() async {
      try {
        await _store.secure.write(tokenKey, session.token);
        await _store.preferences.writeJson(
          profileKey,
          session.user.toStoredJson(),
        );
        await _store.preferences.delete(loggedOutKey);
      } catch (_) {
        _activeToken = null;
        _context.clearSession();
        try {
          await _clearStoredSession();
        } catch (_) {
          // Preserve the original write failure; cleanup is best effort.
        }
        rethrow;
      }
      _activeToken = session.token;
      _context.psSession = session.token;
    });
  }

  Future<void> writeProfile(
    AuthUser user, {
    String? expectedSession,
    int? expectedRevision,
  }) => _serialized(() async {
    if ((expectedSession != null && _context.psSession != expectedSession) ||
        (expectedRevision != null && _mutationRevision != expectedRevision)) {
      throw StateError('authentication session changed');
    }
    _mutationRevision++;
    await _store.preferences.writeJson(profileKey, user.toStoredJson());
  });

  Future<void> clear() {
    _mutationRevision++;
    _activeToken = null;
    _context.clearSession();
    _context.clearCaptcha();
    return _serialized(_clearStoredSession);
  }

  Future<void> _clearStoredSession() async {
    try {
      await _store.secure.delete(tokenKey);
      await _store.preferences.delete(loggedOutKey);
    } catch (_) {
      await _store.preferences.write(loggedOutKey, 'true');
    }
    await _store.preferences.delete(profileKey);
    await _store.preferences.delete(_legacyTokenKey);
    await _store.preferences.delete(_legacyAccountKey);
  }
}
