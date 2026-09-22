import 'package:homeschooling/core/api_client.dart';
import 'package:homeschooling/models/user.dart';

class PinRepository {
  PinRepository(this._api);

  final ApiClient _api;

  /// First PIN, or a change (then [currentPin] is required).
  Future<void> setPin(String pin, {String? currentPin}) async {
    final Map<String, dynamic> body = <String, dynamic>{'pin': pin};
    if (currentPin != null) body['current_pin'] = currentPin;
    await _api.put('/v1/me/pin', body: body);
  }

  /// Throws `pin_invalid` (attempts_remaining) or `pin_locked` (retry_after_seconds).
  Future<Elevation> verify(String pin) async {
    final Object? data = await _api.post('/v1/me/pin/verify', body: <String, dynamic>{'pin': pin});
    return parseObject(data, Elevation.fromJson);
  }

  /// "Forgot PIN": account password plus a new PIN. Also clears a lockout.
  Future<void> reset({required String password, required String newPin}) async {
    await _api.post('/v1/me/pin/reset', body: <String, dynamic>{'password': password, 'pin': newPin});
  }
}
