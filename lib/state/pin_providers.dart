import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/state/environment.dart';

class PinState {
  const PinState({this.busy = false, this.error, this.lockedUntil, this.attemptsRemaining});

  final bool busy;
  final ApiException? error;

  /// Set when the last `verify` answered `pin_locked`.
  final DateTime? lockedUntil;
  final int? attemptsRemaining;

  bool isLocked(DateTime now) => lockedUntil != null && lockedUntil!.isAfter(now);

  Duration remainingLockout(DateTime now) {
    final DateTime? until = lockedUntil;
    if (until == null) return Duration.zero;
    final Duration d = until.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  PinState copyWith({
    bool? busy,
    ApiException? error,
    bool clearError = false,
    DateTime? lockedUntil,
    bool clearLock = false,
    int? attemptsRemaining,
  }) {
    return PinState(
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
    );
  }
}

/// PIN set/verify/reset and the elevation-token cache (see docs/client-guide.md "Parent PIN and child mode").
class PinNotifier extends Notifier<PinState> {
  @override
  PinState build() => const PinState();

  AppEnvironment get _env => ref.read(environmentProvider);

  /// A still-valid elevation token from a recent [verify] call, if any: lets a second sensitive action in a
  /// row skip asking for the PIN again.
  String? cachedElevationToken() => _env.elevationCache.validToken();

  /// Returns the elevation token on success, or null on failure (state carries the reason: wrong PIN vs locked).
  Future<String?> verify(String pin) async {
    state = state.copyWith(busy: true, clearError: true, clearLock: true);
    try {
      final elevation = await _env.pinRepository.verify(pin);
      _env.elevationCache.store(elevation.token, elevation.expiresIn);
      state = const PinState();
      return elevation.token;
    } on ApiException catch (e) {
      final int? retryAfter = e.retryAfterSeconds;
      state = PinState(
        error: e,
        lockedUntil: retryAfter != null ? DateTime.now().add(Duration(seconds: retryAfter)) : null,
        attemptsRemaining: e.attemptsRemaining,
      );
      return null;
    }
  }

  Future<bool> setPin(String pin, {String? currentPin}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _env.pinRepository.setPin(pin, currentPin: currentPin);
      state = const PinState();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e);
      return false;
    }
  }

  Future<bool> resetWithPassword({required String password, required String newPin}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _env.pinRepository.reset(password: password, newPin: newPin);
      _env.elevationCache.clear();
      state = const PinState();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e);
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final NotifierProvider<PinNotifier, PinState> pinProvider = NotifierProvider<PinNotifier, PinState>(PinNotifier.new);
