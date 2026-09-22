import 'dart:async';

import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/core/secure_store.dart';
import 'package:homeschooling/models/child.dart';

/// Which token a request carries. `none` is for config, sign-up, login and refresh.
enum AuthKind { none, parent, child }

AuthKind authKindOf(Object? name) {
  for (final AuthKind k in AuthKind.values) {
    if (k.name == name) return k;
  }
  return AuthKind.parent;
}

enum RefreshOutcome {
  /// A fresh token is available: retry the request.
  refreshed,

  /// The server said no (refresh token rejected): the session was cleared.
  rejected,

  /// Could not find out (offline, 5xx): keep the session, surface the original error.
  unavailable,
}

/// What the HTTP layer needs from the token manager.
abstract class TokenSource {
  String? tokenFor(AuthKind kind);

  /// Gets a new token of [kind]. Concurrent calls share one network round trip (single flight).
  /// [staleToken] is the token the failed request used: if the current token differs, someone already refreshed.
  Future<RefreshOutcome> refresh(AuthKind kind, {String? staleToken});
}

class TokenPair {
  const TokenPair(this.accessToken, this.refreshToken);

  final String accessToken;
  final String refreshToken;
}

typedef RefreshCall = Future<TokenPair> Function(String refreshToken);
typedef ReopenChildCall = Future<ChildSessionGrant> Function(String childId);

/// Holds the parent access/refresh tokens and the child token, in memory and in secure storage.
///
/// Refresh-token rotation rules (docs/client-guide.md): the new pair is stored before it is used, an old refresh
/// token is never sent again, and only one refresh runs at a time. A 401 from /auth/refresh ends the session.
class TokenManager implements TokenSource {
  TokenManager({
    required SecureKeyValue store,
    required RefreshCall refreshCall,
    required ReopenChildCall reopenChildCall,
    void Function()? onSessionExpired,
  })  : _store = store,
        _refreshCall = refreshCall,
        _reopenChildCall = reopenChildCall,
        _onSessionExpired = onSessionExpired;

  static const String _kAccess = 'access_token';
  static const String _kRefresh = 'refresh_token';
  static const String _kChildToken = 'child_token';
  static const String _kChildId = 'active_child_id';

  final SecureKeyValue _store;
  final RefreshCall _refreshCall;
  final ReopenChildCall _reopenChildCall;
  final void Function()? _onSessionExpired;

  String? _access;
  String? _refresh;
  String? _childToken;
  String? _childId;
  Future<RefreshOutcome>? _parentFlight;
  Future<RefreshOutcome>? _childFlight;

  bool get hasSession => _refresh != null;
  String? get refreshToken => _refresh;

  /// Set while the device is in child mode (survives an app restart: the child cannot escape by killing the app).
  String? get activeChildId => _childId;

  Future<void> load() async {
    _access = await _store.read(_kAccess);
    _refresh = await _store.read(_kRefresh);
    _childToken = await _store.read(_kChildToken);
    _childId = await _store.read(_kChildId);
  }

  @override
  String? tokenFor(AuthKind kind) {
    switch (kind) {
      case AuthKind.none:
        return null;
      case AuthKind.parent:
        return _access;
      case AuthKind.child:
        return _childToken;
    }
  }

  Future<void> saveSession(String accessToken, String refreshToken) async {
    _access = accessToken;
    _refresh = refreshToken;
    await _store.write(_kAccess, accessToken);
    await _store.write(_kRefresh, refreshToken);
  }

  Future<void> setChildSession(String childId, String token) async {
    _childId = childId;
    _childToken = token;
    await _store.write(_kChildId, childId);
    await _store.write(_kChildToken, token);
  }

  Future<void> clearChildSession() async {
    _childId = null;
    _childToken = null;
    await _store.delete(_kChildId);
    await _store.delete(_kChildToken);
  }

  Future<void> clearAll() async {
    _access = null;
    _refresh = null;
    await _store.delete(_kAccess);
    await _store.delete(_kRefresh);
    await clearChildSession();
  }

  @override
  Future<RefreshOutcome> refresh(AuthKind kind, {String? staleToken}) {
    switch (kind) {
      case AuthKind.none:
        return Future<RefreshOutcome>.value(RefreshOutcome.rejected);
      case AuthKind.parent:
        return _singleFlight(
          alreadyFresh: staleToken != null && _access != null && _access != staleToken,
          running: _parentFlight,
          start: _doParentRefresh,
          remember: (Future<RefreshOutcome>? f) => _parentFlight = f,
        );
      case AuthKind.child:
        return _singleFlight(
          alreadyFresh: staleToken != null && _childToken != null && _childToken != staleToken,
          running: _childFlight,
          start: _doChildReopen,
          remember: (Future<RefreshOutcome>? f) => _childFlight = f,
        );
    }
  }

  Future<RefreshOutcome> _singleFlight({
    required bool alreadyFresh,
    required Future<RefreshOutcome>? running,
    required Future<RefreshOutcome> Function() start,
    required void Function(Future<RefreshOutcome>?) remember,
  }) {
    if (alreadyFresh) return Future<RefreshOutcome>.value(RefreshOutcome.refreshed);
    if (running != null) return running;
    final Completer<RefreshOutcome> completer = Completer<RefreshOutcome>();
    remember(completer.future);
    start().then((RefreshOutcome outcome) {
      remember(null);
      completer.complete(outcome);
    });
    return completer.future;
  }

  Future<RefreshOutcome> _doParentRefresh() async {
    final String? token = _refresh;
    if (token == null) return RefreshOutcome.rejected;
    try {
      final TokenPair pair = await _refreshCall(token);
      await saveSession(pair.accessToken, pair.refreshToken);
      return RefreshOutcome.refreshed;
    } on ApiException catch (e) {
      if (e.status == 401 || e.isUnauthenticated) {
        try {
          await clearAll();
        } catch (_) {
          // Nothing more to do: the in-memory session is already gone.
        }
        _onSessionExpired?.call();
        return RefreshOutcome.rejected;
      }
      return RefreshOutcome.unavailable;
    } catch (_) {
      return RefreshOutcome.unavailable;
    }
  }

  Future<RefreshOutcome> _doChildReopen() async {
    final String? childId = _childId;
    if (childId == null) return RefreshOutcome.rejected;
    try {
      final ChildSessionGrant grant = await _reopenChildCall(childId);
      await setChildSession(childId, grant.childToken);
      return RefreshOutcome.refreshed;
    } on ApiException catch (e) {
      if (e.status == 403 || e.status == 404) return RefreshOutcome.rejected;
      return RefreshOutcome.unavailable;
    } catch (_) {
      return RefreshOutcome.unavailable;
    }
  }
}
