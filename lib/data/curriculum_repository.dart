import 'package:homeschooling/core/api_client.dart';
import 'package:homeschooling/models/curriculum.dart';

class CurriculumRepository {
  CurriculumRepository(this._api);

  final ApiClient _api;

  Future<List<Level>> levels() async {
    final Object? data = await _api.get('/v1/curriculum/levels');
    return parseList(data, Level.fromJson);
  }

  Future<List<Subject>> subjects() async {
    final Object? data = await _api.get('/v1/curriculum/subjects');
    final List<Subject> list = parseList(data, Subject.fromJson);
    list.sort((Subject a, Subject b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  Future<List<Interest>> interests() async {
    final Object? data = await _api.get('/v1/curriculum/interests');
    return parseList(data, Interest.fromJson);
  }

  Future<List<Skill>> skills({String? subject, String? level}) async {
    final Object? data = await _api.get('/v1/curriculum/skills', query: <String, dynamic>{'subject': subject, 'level': level});
    return parseList(data, Skill.fromJson);
  }
}
