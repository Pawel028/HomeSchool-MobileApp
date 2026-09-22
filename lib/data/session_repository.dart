import 'package:homeschooling/core/api_client.dart';
import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/core/pending_queue.dart';
import 'package:homeschooling/core/pending_item.dart';
import 'package:homeschooling/models/session.dart';

/// Talks to `/v1/sessions*` (see docs/client-guide.md "Activities and the player").
///
/// Also implements [PendingSender] so [PendingQueue] can flush queued submits without knowing about HTTP.
class SessionRepository implements PendingSender {
  SessionRepository(this._api);

  final ApiClient _api;

  /// `POST /sessions`. Idempotent on [clientOpId]: calling twice with the same id returns the same session.
  Future<SessionOut> startSession({
    required String childId,
    required String activityId,
    String? planItemId,
    required String clientOpId,
    AuthKind auth = AuthKind.child,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'child_id': childId,
      'activity_id': activityId,
      'client_op_id': clientOpId,
    };
    if (planItemId != null) body['plan_item_id'] = planItemId;
    final Object? data = await _api.post('/v1/sessions', body: body, auth: auth);
    return parseObject(data, SessionOut.fromJson);
  }

  Future<SessionOut> get(String sessionId, {AuthKind auth = AuthKind.child}) async {
    final Object? data = await _api.get('/v1/sessions/$sessionId', auth: auth);
    return parseObject(data, SessionOut.fromJson);
  }

  /// `PUT /sessions/{id}/autosave`. Best-effort: callers should swallow [ApiException] from this (the pending
  /// queue submit is the thing that must not be lost, autosave is just a progress hint to the server).
  Future<SessionOut> autosave(
    String sessionId, {
    required Map<String, dynamic> answers,
    required int hintsUsed,
    required bool parentAssist,
    AuthKind auth = AuthKind.child,
  }) async {
    final Object? data = await _api.put(
      '/v1/sessions/$sessionId/autosave',
      body: <String, dynamic>{'answers': answers, 'hints_used': hintsUsed, 'parent_assist': parentAssist},
      auth: auth,
    );
    return parseObject(data, SessionOut.fromJson);
  }

  /// `POST /sessions/{id}/submit`. Idempotent: a second call returns the stored result unchanged.
  Future<SessionOut> submitSession(String sessionId, Map<String, dynamic> body, {AuthKind auth = AuthKind.child}) async {
    final Object? data = await _api.post('/v1/sessions/$sessionId/submit', body: body, auth: auth);
    return parseObject(data, SessionOut.fromJson);
  }

  /// Parent-only. `ratings`: step id -> trying | with_help | independent.
  Future<SessionOut> review(String sessionId, Map<String, String> ratings, {bool? parentAssist}) async {
    final Map<String, dynamic> body = <String, dynamic>{'ratings': ratings};
    if (parentAssist != null) body['parent_assist'] = parentAssist;
    final Object? data = await _api.post('/v1/sessions/$sessionId/review', body: body, auth: AuthKind.parent);
    return parseObject(data, SessionOut.fromJson);
  }

  // ---- PendingSender ----

  @override
  Future<String> start(PendingSubmit item) async {
    final AuthKind auth = item.auth == 'parent' ? AuthKind.parent : AuthKind.child;
    final SessionOut session = await startSession(
      childId: item.childId,
      activityId: item.activityId,
      planItemId: item.planItemId,
      clientOpId: item.clientOpId,
      auth: auth,
    );
    return session.id;
  }

  @override
  Future<void> submit(PendingSubmit item, String sessionId, Map<String, dynamic> body) async {
    final AuthKind auth = item.auth == 'parent' ? AuthKind.parent : AuthKind.child;
    await submitSession(sessionId, body, auth: auth);
  }
}
