import 'package:dio/dio.dart';
import 'package:homeschooling/core/api_exception.dart';

/// Maps a Dio failure to the app's sealed [ApiException]. Never includes request or response bodies in messages.
ApiException mapDioException(DioException e) {
  final Response<dynamic>? response = e.response;
  if (response != null) return parseErrorResponse(response.statusCode, response.data);
  // No answer at all: timeouts, DNS, refused connection, TLS failure, cancelled. All are "try again later".
  return NetworkException(e.type.name);
}
