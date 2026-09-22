import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/models/user.dart';
import 'package:homeschooling/state/environment.dart';

enum AuthStatus {
  /// Still checking whether a stored refresh token restores a session.
  restoring,
  signedOut,
  signedIn,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.restoring,
    this.user,
    this.memberships = const <Membership>[],
    this.pinSet = false,
    this.busy = false,
    this.error,
  });

  final AuthStatus status;
  final UserInfo? user;
  final List<Membership> memberships;
  final bool pinSet;

  /// True while a signup/login/logout call is in flight (drives a spinner on the submit button).
  final bool busy;

  /// Set by the last failed action; the screen reads and clears it.
  final ApiException? error;

  bool get isSignedIn => status == AuthStatus.signedIn;

  /// MVP: one family per account (the signup flow creates exactly one).
  Membership? get family => memberships.isEmpty ? null : memberships.first;

  AuthState copyWith({
    AuthStatus? status,
    UserInfo? user,
    List<Membership>? memberships,
    bool? pinSet,
    bool? busy,
    ApiException? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      memberships: memberships ?? this.memberships,
      pinSet: pinSet ?? this.pinSet,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Sign-up, sign-in and the restored-session check. Does not know about child mode or the PIN
/// (see `child_mode_providers.dart` and `pin_providers.dart`).
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Fire and forget: the initial state is "restoring" until this resolves.
    Future<void>.microtask(_restore);
    return const AuthState();
  }

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<void> _restore() async {
    if (!_env.tokenManager.hasSession) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }
    try {
      final Me me = await _env.authRepository.me();
      state = AuthState(status: AuthStatus.signedIn, user: me.user, memberships: me.memberships, pinSet: me.pinSet);
    } on ApiException {
      await _env.tokenManager.clearAll();
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  Future<bool> signup({
    required String email,
    required String password,
    required String fullName,
    required String timezone,
    String? familyName,
  }) {
    return _run(() => _env.authRepository.signup(
          email: email,
          password: password,
          fullName: fullName,
          timezone: timezone,
          familyName: familyName,
        ));
  }

  Future<bool> login({required String email, required String password}) {
    return _run(() => _env.authRepository.login(email: email, password: password));
  }

  Future<bool> _run(Future<AuthResult> Function() call) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final AuthResult result = await call();
      await _env.tokenManager.saveSession(result.accessToken, result.refreshToken);
      state = AuthState(
        status: AuthStatus.signedIn,
        user: result.user,
        memberships: result.memberships,
        pinSet: false,
        busy: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e);
      return false;
    }
  }

  Future<void> refreshMe() async {
    try {
      final Me me = await _env.authRepository.me();
      state = state.copyWith(
        status: AuthStatus.signedIn,
        user: me.user,
        memberships: me.memberships,
        pinSet: me.pinSet,
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e);
    }
  }

  Future<void> logout() async {
    final String? refreshToken = _env.tokenManager.refreshToken;
    state = state.copyWith(busy: true);
    if (refreshToken != null) {
      try {
        await _env.authRepository.logout(refreshToken);
      } on ApiException {
        // Best effort: still clear the local session below.
      }
    }
    await _env.tokenManager.clearAll();
    _env.elevationCache.clear();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Called by the root widget when [TokenManager] reports a rejected refresh token.
  void handleSessionExpired() {
    if (state.status == AuthStatus.signedOut) return;
    state = const AuthState(status: AuthStatus.signedOut);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final NotifierProvider<AuthNotifier, AuthState> authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
