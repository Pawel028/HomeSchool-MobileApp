/// Everything the app throws for a failed API call. Sealed so callers can handle the kinds exhaustively.
///
/// `code` is the stable machine-readable code from errors/errors.yaml, or `network` / `bad_response`.
sealed class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status, this.extras = const <String, dynamic>{}});

  final String code;

  /// For logs only. UI text comes from the code (see error_text.dart).
  final String message;
  final int? status;
  final Map<String, dynamic> extras;

  int? get retryAfterSeconds => _asInt(extras['retry_after_seconds']);
  int? get attemptsRemaining => _asInt(extras['attempts_remaining']);

  bool get isNetwork => this is NetworkException;
  bool get isUnauthenticated => code == 'unauthenticated';

  /// 409 with the code `conflict` (stale `version`). Note `email_taken` is also a 409, so test the code, not the status.
  bool get isConflict => code == 'conflict';

  @override
  String toString() => 'ApiException($code, status: $status)';
}

/// The server answered with an error body.
final class ServerException extends ApiException {
  const ServerException(super.code, super.message, {super.status, super.extras});
}

/// No answer: offline, DNS, TLS or timeout. Safe to retry.
final class NetworkException extends ApiException {
  const NetworkException([String message = 'No connection']) : super('network', message);
}

/// The server answered 2xx but the body was not what the contract says.
final class BadResponseException extends ApiException {
  const BadResponseException([String message = 'Unexpected response']) : super('bad_response', message);
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

/// Builds an exception from an HTTP status and a decoded JSON body of the shape
/// `{"error": {"code", "message", "request_id", ...extras}}`. Unknown shapes still give a usable exception.
ApiException parseErrorResponse(int? status, Object? body) {
  if (body is Map && body['error'] is Map) {
    final Map<dynamic, dynamic> err = body['error'] as Map<dynamic, dynamic>;
    final Object? code = err['code'];
    final Object? message = err['message'];
    final Map<String, dynamic> extras = <String, dynamic>{};
    err.forEach((Object? k, Object? v) {
      if (k is String && k != 'code' && k != 'message') extras[k] = v;
    });
    return ServerException(
      code is String ? code : _fallbackCode(status),
      message is String ? message : '',
      status: status,
      extras: extras,
    );
  }
  return ServerException(_fallbackCode(status), '', status: status);
}

String _fallbackCode(int? status) {
  switch (status) {
    case 401:
      return 'unauthenticated';
    case 403:
      return 'forbidden';
    case 404:
      return 'not_found';
    case 409:
      return 'conflict';
    case 422:
      return 'validation_error';
    case 429:
      return 'rate_limited';
    default:
      return 'internal_error';
  }
}
