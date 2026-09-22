/// Keeps the last PIN-elevation token (valid 5 minutes on the server) in memory so that two sensitive actions in a
/// row do not ask for the PIN twice. Never persisted.
class ElevationCache {
  ElevationCache({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  String? _token;
  DateTime? _expiresAt;

  void store(String token, int expiresInSeconds) {
    _token = token;
    _expiresAt = _clock().add(Duration(seconds: expiresInSeconds));
  }

  /// The token if it stays valid for at least [margin] more.
  String? validToken({Duration margin = const Duration(seconds: 20)}) {
    final String? token = _token;
    final DateTime? expires = _expiresAt;
    if (token == null || expires == null) return null;
    return _clock().add(margin).isBefore(expires) ? token : null;
  }

  void clear() {
    _token = null;
    _expiresAt = null;
  }
}
