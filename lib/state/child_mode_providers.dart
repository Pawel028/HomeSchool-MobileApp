import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/state/environment.dart';

enum AppMode { parent, child }

class ActiveChildState {
  const ActiveChildState({this.mode = AppMode.parent, this.child, this.busy = false, this.error});

  final AppMode mode;
  final Child? child;
  final bool busy;
  final ApiException? error;

  bool get isChildMode => mode == AppMode.child;

  ActiveChildState copyWith({AppMode? mode, Child? child, bool? busy, ApiException? error, bool clearError = false}) {
    return ActiveChildState(
      mode: mode ?? this.mode,
      child: child ?? this.child,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Which child is active and whether the device is currently in "child mode" (locked to the child's own
/// screens). `TokenManager.activeChildId` is the source of truth that survives a process kill, so a child
/// cannot escape parent screens just by closing and reopening the app.
class ActiveChildNotifier extends Notifier<ActiveChildState> {
  @override
  ActiveChildState build() {
    final String? persistedChildId = _env.tokenManager.activeChildId;
    if (persistedChildId != null) {
      Future<void>.microtask(() => _restore(persistedChildId));
      return const ActiveChildState(mode: AppMode.child, busy: true);
    }
    return const ActiveChildState();
  }

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<void> _restore(String childId) async {
    try {
      final Child child = await _env.childrenRepository.get(childId);
      state = ActiveChildState(mode: AppMode.child, child: child);
    } on ApiException catch (e) {
      // Could not confirm the child still exists/belongs to this family: fail safe into parent mode rather
      // than trapping the device in a broken child screen.
      await _env.tokenManager.clearChildSession();
      state = ActiveChildState(error: e);
    }
  }

  /// Enter child mode. No PIN needed (the parent is the one tapping the tile); leaving requires one.
  Future<bool> enterChildMode(Child child) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final ChildSessionGrant grant = await _env.childrenRepository.openChildSession(child.id);
      await _env.tokenManager.setChildSession(child.id, grant.childToken);
      state = ActiveChildState(mode: AppMode.child, child: grant.child);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e);
      return false;
    }
  }

  /// Leave child mode. [elevationToken] comes from a just-completed PIN verification (see pin_providers.dart).
  Future<bool> exitToParentMode(String elevationToken) async {
    final String? childId = state.child?.id;
    if (childId == null) {
      state = const ActiveChildState();
      return true;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _env.childrenRepository.closeChildSessions(childId, elevationToken);
      await _env.tokenManager.clearChildSession();
      state = const ActiveChildState();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e);
      return false;
    }
  }

  void updateActiveChild(Child child) {
    if (state.child?.id == child.id) state = state.copyWith(child: child);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final NotifierProvider<ActiveChildNotifier, ActiveChildState> activeChildProvider =
    NotifierProvider<ActiveChildNotifier, ActiveChildState>(ActiveChildNotifier.new);
