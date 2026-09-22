import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where tokens and the device id live (Android Keystore backed). Behind an interface so tests can use a map.
abstract class SecureKeyValue {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValue implements SecureKeyValue {
  FlutterSecureKeyValue([FlutterSecureStorage? storage]) : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // An unreadable keystore entry (for example after a restore to another phone) means "not signed in".
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
