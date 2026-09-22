import 'package:uuid/uuid.dart';

final Uuid _uuid = Uuid();

/// A random (v4) UUID string. Used for client_op_id, X-Request-Id and the per-install device id.
String newUuid() => _uuid.v4();
