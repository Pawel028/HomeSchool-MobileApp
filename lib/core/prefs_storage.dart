import 'package:homeschooling/core/pending_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// shared_preferences behind the queue's storage interface. Holds no tokens and no personal data.
class PrefsStorage implements KeyValueStorage {
  PrefsStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }
}
