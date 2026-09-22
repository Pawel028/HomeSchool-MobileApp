import 'package:homeschooling/core/ids.dart';
import 'package:homeschooling/core/secure_store.dart';

const String _deviceIdKey = 'device_id';

/// A random id, created once per install and kept in secure storage. It is not derived from any hardware id
/// (no advertising id, no Android id) and only tells the server which of the family's devices opened a child session.
/// The API needs 8 to 100 characters; a v4 UUID is 36.
Future<String> getOrCreateDeviceId(SecureKeyValue store) async {
  final String? existing = await store.read(_deviceIdKey);
  if (existing != null && existing.length >= 8 && existing.length <= 100) return existing;
  final String created = newUuid();
  await store.write(_deviceIdKey, created);
  return created;
}
