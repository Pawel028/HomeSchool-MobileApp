import 'package:homeschooling/models/activity.dart';
import 'package:homeschooling/models/json.dart';
import 'package:homeschooling/models/plan.dart';

class SubjectProgress {
  const SubjectProgress({
    required this.subjectCode,
    required this.subjectName,
    required this.started,
    required this.total,
    this.progressPct,
  });

  final String subjectCode;
  final String subjectName;
  final int started;
  final int total;
  final int? progressPct;

  factory SubjectProgress.fromJson(Map<String, dynamic> j) => SubjectProgress(
        subjectCode: reqString(j, 'subject_code'),
        subjectName: optString(j, 'subject_name') ?? reqString(j, 'subject_code'),
        started: optInt(j, 'started') ?? 0,
        total: optInt(j, 'total') ?? 0,
        progressPct: optInt(j, 'progress_pct'),
      );
}

class Overview {
  const Overview({
    required this.childId,
    required this.activities,
    required this.minutes,
    required this.newSkills,
    required this.streak,
    required this.weekDone,
    required this.weekPlanned,
    required this.subjects,
    this.independentPct,
  });

  final String childId;
  final int activities;
  final int minutes;
  final int newSkills;
  final int streak;
  final int weekDone;
  final int weekPlanned;
  final int? independentPct;
  final List<SubjectProgress> subjects;

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        childId: reqString(j, 'child_id'),
        activities: optInt(j, 'activities') ?? 0,
        minutes: optInt(j, 'minutes') ?? 0,
        newSkills: optInt(j, 'new_skills') ?? 0,
        streak: optInt(j, 'streak') ?? 0,
        weekDone: optInt(j, 'week_done') ?? 0,
        weekPlanned: optInt(j, 'week_planned') ?? 0,
        independentPct: optInt(j, 'independent_pct'),
        subjects: mapList<SubjectProgress>(j['subjects'], SubjectProgress.fromJson),
      );
}

class Recommendation {
  const Recommendation({required this.activity, required this.reason, required this.score});

  final ActivitySummary activity;
  final String reason;
  final double score;

  factory Recommendation.fromJson(Map<String, dynamic> j) => Recommendation(
        activity: ActivitySummary.fromJson(asJsonMap(j['activity'], 'activity')),
        reason: optString(j, 'reason') ?? '',
        score: optDouble(j, 'score') ?? 0,
      );
}

class Dashboard {
  const Dashboard({required this.overview, required this.today, required this.recommendations});

  final Overview overview;
  final List<PlanItem> today;
  final List<Recommendation> recommendations;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        overview: Overview.fromJson(asJsonMap(j['overview'], 'overview')),
        today: mapList<PlanItem>(j['today'], PlanItem.fromJson),
        recommendations: mapList<Recommendation>(j['recommendations'], Recommendation.fromJson),
      );
}

/// emerging | developing | secure
class Mastery {
  const Mastery({
    required this.skillCode,
    required this.skillName,
    required this.subjectCode,
    required this.levelCode,
    required this.status,
    required this.score,
    required this.confidence,
    required this.needsRevisit,
    required this.evidenceCount,
    required this.distinctDays,
    this.lastEvidenceAt,
  });

  final String skillCode;
  final String skillName;
  final String subjectCode;
  final String levelCode;
  final String status;
  final double score;
  final double confidence;
  final bool needsRevisit;
  final int evidenceCount;
  final int distinctDays;
  final DateTime? lastEvidenceAt;

  factory Mastery.fromJson(Map<String, dynamic> j) => Mastery(
        skillCode: reqString(j, 'skill_code'),
        skillName: optString(j, 'skill_name') ?? reqString(j, 'skill_code'),
        subjectCode: optString(j, 'subject_code') ?? '',
        levelCode: optString(j, 'level_code') ?? '',
        status: optString(j, 'status') ?? 'emerging',
        score: optDouble(j, 'score') ?? 0,
        confidence: optDouble(j, 'confidence') ?? 0,
        needsRevisit: boolOr(j, 'needs_revisit'),
        evidenceCount: optInt(j, 'evidence_count') ?? 0,
        distinctDays: optInt(j, 'distinct_days') ?? 0,
        lastEvidenceAt: optDateTime(j, 'last_evidence_at'),
      );
}

class HistoryItem {
  const HistoryItem({
    required this.sessionId,
    required this.activityTitle,
    required this.subjectCode,
    required this.submittedAt,
    required this.durationSec,
    required this.parentAssist,
    required this.needsReview,
    this.score,
  });

  final String sessionId;
  final String activityTitle;
  final String subjectCode;
  final DateTime submittedAt;
  final int durationSec;
  final double? score;
  final bool parentAssist;
  final List<String> needsReview;

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        sessionId: reqString(j, 'session_id'),
        activityTitle: optString(j, 'activity_title') ?? '',
        subjectCode: optString(j, 'subject_code') ?? '',
        submittedAt: reqDateTime(j, 'submitted_at'),
        durationSec: optInt(j, 'duration_sec') ?? 0,
        score: optDouble(j, 'score'),
        parentAssist: boolOr(j, 'parent_assist'),
        needsReview: stringList(j, 'needs_review'),
      );
}
