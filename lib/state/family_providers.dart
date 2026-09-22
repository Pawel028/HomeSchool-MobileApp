import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/models/family.dart';
import 'package:homeschooling/state/auth_providers.dart';
import 'package:homeschooling/state/environment.dart';

class FamilyState {
  const FamilyState({
    this.children = const <Child>[],
    this.consents = const <ConsentRecord>[],
    this.loading = false,
    this.error,
  });

  final List<Child> children;
  final List<ConsentRecord> consents;
  final bool loading;
  final ApiException? error;

  bool consentGranted(String purpose) => consents.any((ConsentRecord c) => c.purpose == purpose && c.granted);

  FamilyState copyWith({
    List<Child>? children,
    List<ConsentRecord>? consents,
    bool? loading,
    ApiException? error,
    bool clearError = false,
  }) {
    return FamilyState(
      children: children ?? this.children,
      consents: consents ?? this.consents,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The signed-in parent's family: children list, consent purposes and child-profile CRUD.
/// Guardian verification itself is `guardian_providers.dart`.
class FamilyNotifier extends Notifier<FamilyState> {
  @override
  FamilyState build() {
    ref.listen<String?>(authProvider.select((AuthState s) => s.family?.familyId), (String? prev, String? next) {
      if (next != null && next != prev) Future<void>.microtask(refresh);
      if (next == null) state = const FamilyState();
    });
    final String? familyId = ref.read(authProvider).family?.familyId;
    if (familyId != null) Future<void>.microtask(refresh);
    return const FamilyState();
  }

  AppEnvironment get _env => ref.read(environmentProvider);
  String? get _familyId => ref.read(authProvider).family?.familyId;

  Future<void> refresh() async {
    final String? familyId = _familyId;
    if (familyId == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final List<Child> children = await _env.familyRepository.listChildren(familyId);
      final List<ConsentRecord> consents = await _env.familyRepository.consents(familyId);
      state = state.copyWith(children: children, consents: consents, loading: false);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<bool> setConsent({required String purpose, required bool granted, required String noticeVersion}) async {
    final String? familyId = _familyId;
    if (familyId == null) return false;
    try {
      final List<ConsentRecord> consents = await _env.familyRepository
          .setConsent(familyId: familyId, purpose: purpose, granted: granted, noticeVersion: noticeVersion);
      state = state.copyWith(consents: consents, clearError: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<Child?> createChild(ChildDraft draft) async {
    final String? familyId = _familyId;
    if (familyId == null) return null;
    try {
      final Child child = await _env.childrenRepository.create(familyId, draft);
      state = state.copyWith(children: <Child>[...state.children, child], clearError: true);
      return child;
    } on ApiException catch (e) {
      state = state.copyWith(error: e);
      return null;
    }
  }

  /// On a 409 conflict, reloads the child from the server (so the caller can show the latest version and ask
  /// the parent to re-apply their change) instead of silently discarding the edit.
  Future<Child?> updateChild(String childId, ChildDraft draft, int version) async {
    try {
      final Child updated = await _env.childrenRepository.update(childId, draft, version);
      _replaceChild(updated);
      state = state.copyWith(clearError: true);
      return updated;
    } on ApiException catch (e) {
      if (e.isConflict) {
        try {
          final Child fresh = await _env.childrenRepository.get(childId);
          _replaceChild(fresh);
        } on ApiException {
          // Keep the stale copy if even the reload fails; the error below still surfaces.
        }
      }
      state = state.copyWith(error: e);
      return null;
    }
  }

  void _replaceChild(Child updated) {
    state = state.copyWith(
      children: <Child>[for (final Child c in state.children) if (c.id == updated.id) updated else c],
    );
  }

  Future<bool> deleteChild(String childId, String elevationToken) async {
    try {
      await _env.childrenRepository.delete(childId, elevationToken);
      state = state.copyWith(
        children: state.children.where((Child c) => c.id != childId).toList(),
        clearError: true,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final NotifierProvider<FamilyNotifier, FamilyState> familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(
  FamilyNotifier.new,
);
