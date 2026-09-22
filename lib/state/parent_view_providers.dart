import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/state/family_providers.dart';

/// Which child the parent-facing screens (dashboard/planner/catalogue/progress/reviews) currently show.
/// Distinct from `child_mode_providers.dart`'s active child, which is about the device being *handed to*
/// a child, not which child a parent is looking at.
class ParentViewedChildNotifier extends Notifier<Child?> {
  @override
  Child? build() {
    ref.listen<List<Child>>(familyProvider.select((FamilyState s) => s.children), (List<Child>? prev, List<Child> next) {
      if (next.isEmpty) {
        state = null;
      } else if (state == null || !next.any((Child c) => c.id == state!.id)) {
        state = next.first;
      } else {
        // Keep the same child selected but with fresh data (e.g. after an edit).
        state = next.firstWhere((Child c) => c.id == state!.id);
      }
    });
    final List<Child> children = ref.read(familyProvider).children;
    return children.isEmpty ? null : children.first;
  }

  void select(Child child) => state = child;
}

final NotifierProvider<ParentViewedChildNotifier, Child?> parentViewedChildProvider =
    NotifierProvider<ParentViewedChildNotifier, Child?>(ParentViewedChildNotifier.new);
