import 'package:homeschooling/models/activity.dart';
import 'package:homeschooling/models/json.dart';
import 'package:homeschooling/models/steps.dart';

/// `result` of a submitted session. Only the parts the app needs.
class SessionResult {
  const SessionResult({
    required this.score,
    required this.scoredSteps,
    required this.stepScores,
    required this.needsReview,
    required this.skills,
    this.independence,
  });

  /// 0..1, or null when nothing was auto-scored.
  final double? score;
  final int scoredSteps;
  final Map<String, double> stepScores;
  final List<String> needsReview;
  final List<String> skills;
  final String? independence;

  factory SessionResult.fromJson(Map<String, dynamic> j) {
    final Map<String, double> scores = <String, double>{};
    final Object? steps = j['steps'];
    if (steps is Map) {
      steps.forEach((Object? key, Object? value) {
        if (key is String && value is Map && value['score'] is num) {
          scores[key] = (value['score'] as num).toDouble();
        }
      });
    }
    return SessionResult(
      score: optDouble(j, 'score'),
      scoredSteps: optInt(j, 'scored_steps') ?? 0,
      stepScores: scores,
      needsReview: stringList(j, 'needs_review'),
      skills: stringList(j, 'skills'),
      independence: optString(j, 'independence'),
    );
  }
}

class SessionOut {
  const SessionOut({
    required this.id,
    required this.childId,
    required this.activity,
    required this.definition,
    required this.answers,
    required this.hintsUsed,
    required this.parentAssist,
    required this.durationSec,
    required this.status,
    required this.version,
    this.result,
  });

  final String id;
  final String childId;
  final ActivitySummary activity;
  final ActivityDefinition definition;
  final Map<String, dynamic> answers;
  final int hintsUsed;
  final bool parentAssist;
  final int durationSec;
  final String status;
  final int version;
  final SessionResult? result;

  bool get isSubmitted => status == 'submitted';

  factory SessionOut.fromJson(Map<String, dynamic> j) => SessionOut(
        id: reqString(j, 'id'),
        childId: reqString(j, 'child_id'),
        activity: ActivitySummary.fromJson(asJsonMap(j['activity'], 'activity')),
        definition: ActivityDefinition.fromJson(asJsonMap(j['activity_definition'], 'activity_definition')),
        answers: j['answers'] is Map ? asJsonMap(j['answers']) : <String, dynamic>{},
        hintsUsed: optInt(j, 'hints_used') ?? 0,
        parentAssist: boolOr(j, 'parent_assist'),
        durationSec: optInt(j, 'duration_sec') ?? 0,
        status: optString(j, 'status') ?? 'in_progress',
        version: optInt(j, 'version') ?? 1,
        result: j['result'] is Map ? SessionResult.fromJson(asJsonMap(j['result'])) : null,
      );
}
