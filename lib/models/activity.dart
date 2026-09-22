import 'package:homeschooling/models/json.dart';
import 'package:homeschooling/models/steps.dart';

class ActivitySummary {
  const ActivitySummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.subjectCode,
    required this.levelFrom,
    required this.levelTo,
    required this.durationMin,
    required this.materials,
    required this.interestTags,
    required this.version,
    this.summary,
  });

  final String id;
  final String slug;
  final String title;
  final String subjectCode;
  final String levelFrom;
  final String levelTo;
  final int durationMin;
  final List<String> materials;
  final List<String> interestTags;
  final String? summary;
  final int version;

  factory ActivitySummary.fromJson(Map<String, dynamic> j) => ActivitySummary(
        id: reqString(j, 'id'),
        slug: optString(j, 'slug') ?? '',
        title: reqString(j, 'title'),
        subjectCode: optString(j, 'subject_code') ?? '',
        levelFrom: optString(j, 'level_from') ?? '',
        levelTo: optString(j, 'level_to') ?? '',
        durationMin: optInt(j, 'duration_min') ?? 0,
        materials: stringList(j, 'materials'),
        interestTags: stringList(j, 'interest_tags'),
        summary: optString(j, 'summary'),
        version: optInt(j, 'version') ?? 1,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'slug': slug,
        'title': title,
        'subject_code': subjectCode,
        'level_from': levelFrom,
        'level_to': levelTo,
        'duration_min': durationMin,
        'materials': materials,
        'interest_tags': interestTags,
        'summary': summary,
        'version': version,
      };

  /// "L2" or "L2-L3".
  String get levelRange => levelFrom == levelTo ? levelFrom : '$levelFrom-$levelTo';
}

/// GET /activities/{id}: the summary plus the answer-key-free definition.
class ActivityDetail {
  const ActivityDetail({required this.summary, required this.skills, required this.definition});

  final ActivitySummary summary;
  final List<String> skills;
  final ActivityDefinition definition;

  factory ActivityDetail.fromJson(Map<String, dynamic> j) => ActivityDetail(
        summary: ActivitySummary.fromJson(j),
        skills: stringList(j, 'skills'),
        definition: ActivityDefinition.fromJson(asJsonMap(j['definition'], 'definition')),
      );
}
