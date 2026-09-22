import 'package:homeschooling/core/api_client.dart';
import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/core/dates.dart';
import 'package:homeschooling/models/plan.dart';
import 'package:homeschooling/models/progress.dart';

class PlanningRepository {
  PlanningRepository(this._api);

  final ApiClient _api;

  /// [anyDayInWeek] can be any date: the API snaps to Monday.
  Future<Plan> plan(String childId, DateTime anyDayInWeek, {AuthKind auth = AuthKind.parent}) async {
    final Object? data = await _api.get(
      '/v1/children/$childId/plan',
      query: <String, dynamic>{'week_start': formatApiDate(weekStartOf(anyDayInWeek))},
      auth: auth,
    );
    return parseObject(data, Plan.fromJson);
  }

  Future<List<PlanItem>> today(String childId, {AuthKind auth = AuthKind.parent}) async {
    final Object? data = await _api.get('/v1/children/$childId/today', auth: auth);
    return parseList(data, PlanItem.fromJson);
  }

  Future<PlanItem> addItem({required String childId, required String activityId, required DateTime date}) async {
    final Object? data = await _api.post(
      '/v1/children/$childId/plan/items',
      body: <String, dynamic>{'activity_id': activityId, 'scheduled_date': formatApiDate(date)},
    );
    return parseObject(data, PlanItem.fromJson);
  }

  /// Version-safe: sends the version that was read. A 409 `conflict` means the item changed elsewhere.
  Future<PlanItem> updateItem(PlanItem item, {DateTime? scheduledDate, String? status}) async {
    final Map<String, dynamic> body = <String, dynamic>{'version': item.version};
    if (scheduledDate != null) body['scheduled_date'] = formatApiDate(scheduledDate);
    if (status != null) body['status'] = status;
    final Object? data = await _api.patch('/v1/plan-items/${item.id}', body: body);
    return parseObject(data, PlanItem.fromJson);
  }

  Future<void> deleteItem(String itemId) async {
    await _api.delete('/v1/plan-items/$itemId');
  }

  Future<List<Recommendation>> recommendations(String childId, {int limit = 5, int? maxMinutes}) async {
    final Object? data = await _api.get(
      '/v1/children/$childId/recommendations',
      query: <String, dynamic>{'limit': limit, 'max_minutes': maxMinutes},
    );
    return parseList(data, Recommendation.fromJson);
  }
}
