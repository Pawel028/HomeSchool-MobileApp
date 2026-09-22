import 'package:homeschooling/models/json.dart';

class Level {
  const Level({required this.code, required this.name, this.description, this.indicativeAge});

  final String code;
  final String name;
  final String? description;
  final String? indicativeAge;

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        code: reqString(j, 'code'),
        name: reqString(j, 'name'),
        description: optString(j, 'description'),
        indicativeAge: optString(j, 'indicative_age'),
      );
}

class Subject {
  const Subject({required this.code, required this.name, required this.displayOrder});

  final String code;
  final String name;
  final int displayOrder;

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        code: reqString(j, 'code'),
        name: reqString(j, 'name'),
        displayOrder: optInt(j, 'display_order') ?? 0,
      );
}

class Interest {
  const Interest({required this.code, required this.name});

  final String code;
  final String name;

  factory Interest.fromJson(Map<String, dynamic> j) =>
      Interest(code: reqString(j, 'code'), name: reqString(j, 'name'));
}

class Skill {
  const Skill({
    required this.code,
    required this.name,
    required this.subjectCode,
    required this.levelCode,
    required this.prerequisites,
  });

  final String code;
  final String name;
  final String subjectCode;
  final String levelCode;
  final List<String> prerequisites;

  factory Skill.fromJson(Map<String, dynamic> j) => Skill(
        code: reqString(j, 'code'),
        name: reqString(j, 'name'),
        subjectCode: reqString(j, 'subject_code'),
        levelCode: reqString(j, 'level_code'),
        prerequisites: stringList(j, 'prerequisites'),
      );
}
