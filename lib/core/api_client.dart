import 'package:dio/dio.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/core/dio_errors.dart';
import 'package:homeschooling/core/ids.dart';
import 'package:homeschooling/models/json.dart';

const String _kAuthExtra = 'auth';
const String _kSentTokenExtra = 'sentToken';
const String _kRetriedExtra = 'retried';

/// Thin JSON-over-HTTP client for the HomeSchooling API.
///
/// * Adds `X-Request-Id` to every call and `Authorization` for [AuthKind.parent] / [AuthKind.child].
/// * On 401 `unauthenticated`: refreshes once (single flight, see [TokenManager]) and retries the request once.
/// * Turns every failure into an [ApiException]. No request or response bodies are ever logged.
class ApiClient {
  ApiClient({required String baseUrl, TokenSource? tokens, HttpClientAdapter? adapter}) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: <String, dynamic>{'Accept': 'application/json'},
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(_RequestIdInterceptor());
    if (tokens != null) dio.interceptors.add(_AuthInterceptor(dio: dio, tokens: tokens));
    _dio = dio;
  }

  late final Dio _dio;

  Future<Object?> get(String path,
      {Map<String, dynamic>? query, AuthKind auth = AuthKind.parent, Map<String, String>? headers}) {
    return _send('GET', path, query: query, auth: auth, headers: headers);
  }

  Future<Object?> post(String path,
      {Object? body, AuthKind auth = AuthKind.parent, Map<String, String>? headers}) {
    return _send('POST', path, body: body, auth: auth, headers: headers);
  }

  Future<Object?> put(String path, {Object? body, AuthKind auth = AuthKind.parent, Map<String, String>? headers}) {
    return _send('PUT', path, body: body, auth: auth, headers: headers);
  }

  Future<Object?> patch(String path,
      {Object? body, AuthKind auth = AuthKind.parent, Map<String, String>? headers}) {
    return _send('PATCH', path, body: body, auth: auth, headers: headers);
  }

  Future<Object?> delete(String path, {AuthKind auth = AuthKind.parent, Map<String, String>? headers}) {
    return _send('DELETE', path, auth: auth, headers: headers);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required AuthKind auth,
    Map<String, String>? headers,
  }) async {
    try {
      final Response<dynamic> response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: _cleanQuery(query),
        options: Options(
          method: method,
          headers: headers == null ? null : Map<String, dynamic>.from(headers),
          extra: <String, dynamic>{_kAuthExtra: auth.name},
        ),
      );
      final Object? data = response.data;
      if (data is String && data.isEmpty) return null;
      return data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final Map<String, dynamic> out = <String, dynamic>{};
    query.forEach((String key, dynamic value) {
      if (value != null && value.toString().isNotEmpty) out[key] = value;
    });
    return out.isEmpty ? null : out;
  }
}

/// Parses a JSON object body; a malformed body becomes a [BadResponseException], never a raw FormatException.
T parseObject<T>(Object? data, T Function(Map<String, dynamic> json) build) {
  try {
    return build(asJsonMap(data));
  } on FormatException catch (e) {
    throw BadResponseException(e.message);
  }
}

List<T> parseList<T>(Object? data, T Function(Map<String, dynamic> json) build) {
  try {
    return asJsonList(data).map<T>((Object? e) => build(asJsonMap(e))).toList();
  } on FormatException catch (e) {
    throw BadResponseException(e.message);
  }
}

class _RequestIdInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Request-Id'] = newUuid();
    handler.next(options);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required Dio dio, required TokenSource tokens})
      : _dio = dio,
        _tokens = tokens;

  final Dio _dio;
  final TokenSource _tokens;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final AuthKind kind = authKindOf(options.extra[_kAuthExtra]);
    if (kind != AuthKind.none) {
      final String? token = _tokens.tokenFor(kind);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_kSentTokenExtra] = token;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final RequestOptions request = err.requestOptions;
    final AuthKind kind = authKindOf(request.extra[_kAuthExtra]);
    final bool alreadyRetried = request.extra[_kRetriedExtra] == true;
    final bool expired = err.response?.statusCode == 401 && _errorCode(err.response?.data) == 'unauthenticated';
    if (kind != AuthKind.none && expired && !alreadyRetried) {
      final Object? sent = request.extra[_kSentTokenExtra];
      final RefreshOutcome outcome = await _tokens.refresh(kind, staleToken: sent is String ? sent : null);
      if (outcome == RefreshOutcome.refreshed) {
        request.extra[_kRetriedExtra] = true;
        try {
          final Response<dynamic> retried = await _dio.fetch<dynamic>(request);
          handler.resolve(retried);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
        return;
      }
    }
    handler.next(err);
  }

  String? _errorCode(Object? data) {
    if (data is Map && data['error'] is Map) {
      final Object? code = (data['error'] as Map<dynamic, dynamic>)['code'];
      if (code is String) return code;
    }
    return null;
  }
}
