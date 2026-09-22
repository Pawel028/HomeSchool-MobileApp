import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/models/curriculum.dart';
import 'package:homeschooling/state/environment.dart';

/// Reference data (`/v1/curriculum/*`) barely ever changes within a session, so plain (non-family, cached-until
/// invalidated) [FutureProvider]s are enough — no dedicated notifier needed.

final FutureProvider<List<Level>> levelsProvider = FutureProvider<List<Level>>((Ref ref) {
  return ref.watch(environmentProvider).curriculumRepository.levels();
});

final FutureProvider<List<Subject>> subjectsProvider = FutureProvider<List<Subject>>((Ref ref) {
  return ref.watch(environmentProvider).curriculumRepository.subjects();
});

final FutureProvider<List<Interest>> interestsProvider = FutureProvider<List<Interest>>((Ref ref) {
  return ref.watch(environmentProvider).curriculumRepository.interests();
});

class SkillsQuery {
  const SkillsQuery({this.subject, this.level});

  final String? subject;
  final String? level;

  @override
  bool operator ==(Object other) => other is SkillsQuery && other.subject == subject && other.level == level;

  @override
  int get hashCode => Object.hash(subject, level);
}

final FutureProvider.family<List<Skill>, SkillsQuery> skillsProvider =
    FutureProvider.family<List<Skill>, SkillsQuery>((Ref ref, SkillsQuery query) {
  return ref.watch(environmentProvider).curriculumRepository.skills(subject: query.subject, level: query.level);
});
