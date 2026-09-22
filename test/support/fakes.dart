import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/core/pending_queue.dart';
import 'package:homeschooling/core/secure_store.dart';

/// In-memory [SecureKeyValue] so tests never touch the Android Keystore.
class InMemorySecureStore implements SecureKeyValue {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// In-memory [KeyValueStorage] for [PendingQueue] in tests (no shared_preferences plugin available).
class InMemoryKeyValueStorage implements KeyValueStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  String? read(String key) => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

/// A [TokenManager] backed by in-memory storage, starting with no session (`hasSession == false`) — call
/// `await tm.saveSession('access', 'refresh')` in a test that needs a signed-in starting point.
TokenManager freshTokenManager({SecureKeyValue? store}) {
  final SecureKeyValue s = store ?? InMemorySecureStore();
  return TokenManager(
    store: s,
    refreshCall: (String _) async => throw UnimplementedError('not used in this test'),
    reopenChildCall: (String _) async => throw UnimplementedError('not used in this test'),
  );
}
