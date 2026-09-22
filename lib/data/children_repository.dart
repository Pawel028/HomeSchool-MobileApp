import 'package:homeschooling/core/api_client.dart';
import 'package:homeschooling/models/child.dart';

class ChildrenRepository {
  ChildrenRepository({required ApiClient api, required Future<String> Function() deviceId})
      : _api = api,
        _deviceId = deviceId;

  final ApiClient _api;
  final Future<String> Function() _deviceId;

  Future<Child> create(String familyId, ChildDraft draft) async {
    final Object? data = await _api.post('/v1/families/$familyId/children', body: draft.toCreateJson());
    return parseObject(data, Child.fromJson);
  }

  Future<Child> get(String childId) async {
    final Object? data = await _api.get('/v1/children/$childId');
    return parseObject(data, Child.fromJson);
  }

  /// [version] is the version the form was loaded with; a 409 `conflict` means someone else changed the profile.
  Future<Child> update(String childId, ChildDraft draft, int version) async {
    final Object? data = await _api.patch('/v1/children/$childId', body: draft.toPatchJson(version));
    return parseObject(data, Child.fromJson);
  }

  Future<void> delete(String childId, String elevationToken) async {
    await _api.delete('/v1/children/$childId', headers: <String, String>{'X-Elevation-Token': elevationToken});
  }

  /// Child mode: uses the parent token and returns a child-scoped token.
  Future<ChildSessionGrant> openChildSession(String childId) async {
    final String device = await _deviceId();
    final Object? data = await _api.post('/v1/children/$childId/sessions', body: <String, dynamic>{'device_id': device});
    return parseObject(data, ChildSessionGrant.fromJson);
  }

  /// Leaves child mode on the server (revokes the child tokens). Needs a PIN elevation token.
  Future<void> closeChildSessions(String childId, String elevationToken) async {
    await _api.delete('/v1/children/$childId/sessions', headers: <String, String>{'X-Elevation-Token': elevationToken});
  }
}
