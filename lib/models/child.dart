import 'package:homeschooling/models/json.dart';

class Child {
  const Child({
    required this.id,
    required this.familyId,
    required this.displayName,
    required this.avatar,
    required this.interests,
    required this.goals,
    required this.version,
    this.birthYear,
    this.levelCode,
  });

  final String id;
  final String familyId;
  final String displayName;
  final String avatar;
  final int? birthYear;
  final String? levelCode;
  final List<String> interests;
  final List<String> goals;
  final int version;

  factory Child.fromJson(Map<String, dynamic> j) => Child(
        id: reqString(j, 'id'),
        familyId: reqString(j, 'family_id'),
        displayName: reqString(j, 'display_name'),
        avatar: optString(j, 'avatar') ?? 'star',
        birthYear: optInt(j, 'birth_year'),
        levelCode: optString(j, 'level_code'),
        interests: stringList(j, 'interests'),
        goals: stringList(j, 'goals'),
        version: optInt(j, 'version') ?? 1,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'family_id': familyId,
        'display_name': displayName,
        'avatar': avatar,
        'birth_year': birthYear,
        'level_code': levelCode,
        'interests': interests,
        'goals': goals,
        'version': version,
      };
}

/// What the add/edit form collects. Used for POST (create) and PATCH (with the last known version).
class ChildDraft {
  const ChildDraft({
    required this.displayName,
    required this.avatar,
    required this.interests,
    required this.goals,
    this.birthYear,
    this.levelCode,
  });

  final String displayName;
  final String avatar;
  final int? birthYear;
  final String? levelCode;
  final List<String> interests;
  final List<String> goals;

  Map<String, dynamic> toCreateJson() => <String, dynamic>{
        'display_name': displayName,
        'avatar': avatar,
        'birth_year': birthYear,
        'level_code': levelCode,
        'interests': interests,
        'goals': goals,
      };

  Map<String, dynamic> toPatchJson(int version) => <String, dynamic>{
        ...toCreateJson(),
        'version': version,
      };
}

/// Response of POST /children/{id}/sessions (child mode).
class ChildSessionGrant {
  const ChildSessionGrant({required this.childToken, required this.expiresAt, required this.child});

  final String childToken;
  final DateTime expiresAt;
  final Child child;

  factory ChildSessionGrant.fromJson(Map<String, dynamic> j) => ChildSessionGrant(
        childToken: reqString(j, 'child_token'),
        expiresAt: reqDateTime(j, 'expires_at'),
        child: Child.fromJson(asJsonMap(j['child'], 'child')),
      );
}
