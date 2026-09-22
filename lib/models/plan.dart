import 'package:homeschooling/core/dates.dart';
import 'package:homeschooling/models/activity.dart';
import 'package:homeschooling/models/json.dart';

class PlanItem {
  const PlanItem({
    required this.id,
    required this.childId,
    required this.activity,
    required this.scheduledDate,
    required this.position,
    required this.status,
    required this.version,
  });

  final String id;
  final String childId;
  final ActivitySummary activity;

  /// Calendar date in the family's time zone (date-only, local DateTime).
  final DateTime scheduledDate;
  final int position;

  /// planned | in_progress | completed | skipped
  final String status;
  final int version;

  bool get isCompleted => status == 'completed';
  bool get isSkipped => status == 'skipped';
  bool get isPlayable => status == 'planned' || status == 'in_progress';

  /// The server only removes planned or skipped items and refuses to change completed ones.
  bool get canDelete => status == 'planned' || status == 'skipped';
  bool get canEdit => !isCompleted;

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
        id: reqString(j, 'id'),
        childId: reqString(j, 'child_id'),
        activity: ActivitySummary.fromJson(asJsonMap(j['activity'], 'activity')),
        scheduledDate: reqDate(j, 'scheduled_date'),
        position: optInt(j, 'position') ?? 0,
        status: optString(j, 'status') ?? 'planned',
        version: optInt(j, 'version') ?? 1,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'child_id': childId,
        'activity': activity.toJson(),
        'scheduled_date': formatApiDate(scheduledDate),
        'position': position,
        'status': status,
        'version': version,
      };
}

class Plan {
  const Plan({required this.childId, required this.weekStart, required this.items});

  final String childId;
  final DateTime weekStart;
  final List<PlanItem> items;

  List<PlanItem> itemsOn(DateTime day) =>
      items.where((PlanItem i) => isSameDay(i.scheduledDate, day)).toList();

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        childId: reqString(j, 'child_id'),
        weekStart: reqDate(j, 'week_start'),
        items: mapList<PlanItem>(j['items'], PlanItem.fromJson),
      );
}
