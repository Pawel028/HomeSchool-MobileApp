import 'package:homeschooling/models/json.dart';

/// A finished activity that could not be sent yet. Holds ids and answers only (no names, no e-mail).
class PendingSubmit {
  const PendingSubmit({
    required this.id,
    required this.childId,
    required this.activityId,
    required this.clientOpId,
    required this.body,
    required this.occurredAt,
    required this.createdAt,
    required this.auth,
    this.sessionId,
    this.planItemId,
    this.attempts = 0,
    this.nextAttemptAt,
    this.omitOccurredAt = false,
  });

  /// Local id of the queue entry.
  final String id;

  /// Null when POST /sessions itself failed: the queue then starts the session first, using [clientOpId]
  /// (the same value as the first attempt, so the server returns the same session if it did get the first call).
  final String? sessionId;
  final String childId;
  final String activityId;
  final String? planItemId;
  final String clientOpId;

  /// `answers`, `hints_used`, `parent_assist`, `duration_sec` (never `occurred_at`; see [submitBody]).
  final Map<String, dynamic> body;

  /// The real completion time (UTC). The API accepts at most 7 days back.
  final DateTime occurredAt;
  final DateTime createdAt;

  /// 'child' or 'parent': which token created the session.
  final String auth;
  final int attempts;
  final DateTime? nextAttemptAt;

  /// Set after a 422: the device clock may be wrong, so let the server stamp the time.
  final bool omitOccurredAt;

  Map<String, dynamic> submitBody() {
    final Map<String, dynamic> out = Map<String, dynamic>.from(body);
    if (!omitOccurredAt) out['occurred_at'] = occurredAt.toUtc().toIso8601String();
    return out;
  }

  PendingSubmit copyWith({
    String? sessionId,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    bool? omitOccurredAt,
  }) {
    return PendingSubmit(
      id: id,
      childId: childId,
      activityId: activityId,
      clientOpId: clientOpId,
      body: body,
      occurredAt: occurredAt,
      createdAt: createdAt,
      auth: auth,
      sessionId: sessionId ?? this.sessionId,
      planItemId: planItemId,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      omitOccurredAt: omitOccurredAt ?? this.omitOccurredAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'session_id': sessionId,
        'child_id': childId,
        'activity_id': activityId,
        'plan_item_id': planItemId,
        'client_op_id': clientOpId,
        'body': body,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'auth': auth,
        'attempts': attempts,
        'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
        'omit_occurred_at': omitOccurredAt,
      };

  factory PendingSubmit.fromJson(Map<String, dynamic> j) => PendingSubmit(
        id: reqString(j, 'id'),
        sessionId: optString(j, 'session_id'),
        childId: reqString(j, 'child_id'),
        activityId: reqString(j, 'activity_id'),
        planItemId: optString(j, 'plan_item_id'),
        clientOpId: reqString(j, 'client_op_id'),
        body: asJsonMap(j['body'], 'body'),
        occurredAt: reqDateTime(j, 'occurred_at'),
        createdAt: reqDateTime(j, 'created_at'),
        auth: optString(j, 'auth') ?? 'parent',
        attempts: optInt(j, 'attempts') ?? 0,
        nextAttemptAt: optDateTime(j, 'next_attempt_at'),
        omitOccurredAt: boolOr(j, 'omit_occurred_at'),
      );
}
