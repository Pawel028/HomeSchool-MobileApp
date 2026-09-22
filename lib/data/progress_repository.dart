import 'package:homeschooling/core/api_client.dart';
import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/models/json.dart';
import 'package:homeschooling/models/progress.dart';

class ProgressRepository {
  ProgressRepository(this._api);

  final ApiClient _api;

  Future<Dashboard> dashboard(String childId) async {
    final Object? data = await _api.get('/v1/children/$childId/dashboard');
    return parseObject(data, Dashboard.fromJson);
  }

  Future<List<Mastery>> mastery(String childId, {String? subject}) async {
    final Object? data = await _api.get(
      '/v1/children/$childId/mastery',
      query: <String, dynamic>{'subject': subject},
    );
    return parseList(data, Mastery.fromJson);
  }

  /// rating: trying | with_help | independent
  Future<Mastery> observe({
    required String childId,
    required String skillCode,
    required String rating,
    String? note,
    required DateTime occurredAt,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'skill_code': skillCode,
      'rating': rating,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    };
    final String trimmed = (note ?? '').trim();
    if (trimmed.isNotEmpty) body['note'] = trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed;
    final Object? data = await _api.post('/v1/children/$childId/observations', body: body);
    return parseObject<Mastery>(
      data,
      (Map<String, dynamic> json) => Mastery.fromJson(asJsonMap(json['mastery'], 'mastery')),
    );
  }

  /// Starting checklist for a level. Only rated skills are sent.
  Future<void> baseline(String childId, Map<String, String> ratingsBySkill) async {
    final List<Map<String, String>> ratings = ratingsBySkill.entries
        .map((MapEntry<String, String> e) => <String, String>{'skill_code': e.key, 'rating': e.value})
        .toList();
    await _api.post('/v1/children/$childId/baseline', body: <String, dynamic>{'ratings': ratings});
  }

  /// Finished sessions, newest first. Readable with a child token too.
  Future<List<HistoryItem>> history(String childId,
      {int limit = 30, int offset = 0, AuthKind auth = AuthKind.parent}) async {
    final Object? data = await _api.get(
      '/v1/children/$childId/history',
      query: <String, dynamic>{'limit': limit, 'offset': offset},
      auth: auth,
    );
    return parseList(data, HistoryItem.fromJson);
  }
}
