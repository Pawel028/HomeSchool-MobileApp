import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/core/dates.dart';
import 'package:homeschooling/models/plan.dart';
import 'package:homeschooling/state/environment.dart';

class TodayState {
  const TodayState({this.childId, this.items = const <PlanItem>[], this.loading = false, this.error});

  final String? childId;
  final List<PlanItem> items;
  final bool loading;
  final ApiException? error;

  TodayState copyWith({String? childId, List<PlanItem>? items, bool? loading, ApiException? error, bool clearError = false}) {
    return TodayState(
      childId: childId ?? this.childId,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Today's plan items for whichever child is passed to [load]. Used by both the child home screen (child
/// token) and the parent dashboard (parent token) — pass the right [auth].
class TodayNotifier extends Notifier<TodayState> {
  @override
  TodayState build() => const TodayState();

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<void> load(String childId, {AuthKind auth = AuthKind.parent}) async {
    state = state.copyWith(childId: childId, loading: true, clearError: true);
    try {
      final List<PlanItem> items = await _env.planningRepository.today(childId, auth: auth);
      if (state.childId != childId) return; // a newer load() for a different child won: drop this result
      state = state.copyWith(items: items, loading: false);
    } on ApiException catch (e) {
      if (state.childId != childId) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Optimistically marks an item completed after a session submits, without waiting for a full reload.
  void markCompletedLocally(String planItemId) {
    state = state.copyWith(
      items: <PlanItem>[
        for (final PlanItem i in state.items)
          if (i.id == planItemId)
            PlanItem(
              id: i.id,
              childId: i.childId,
              activity: i.activity,
              scheduledDate: i.scheduledDate,
              position: i.position,
              status: 'completed',
              version: i.version,
            )
          else
            i,
      ],
    );
  }
}

final NotifierProvider<TodayNotifier, TodayState> todayProvider = NotifierProvider<TodayNotifier, TodayState>(
  TodayNotifier.new,
);

class WeekPlanState {
  const WeekPlanState({this.childId, this.weekStart, this.items = const <PlanItem>[], this.loading = false, this.error});

  final String? childId;
  final DateTime? weekStart;
  final List<PlanItem> items;
  final bool loading;
  final ApiException? error;

  List<PlanItem> itemsOn(DateTime day) => items.where((PlanItem i) => isSameDay(i.scheduledDate, day)).toList();

  WeekPlanState copyWith({
    String? childId,
    DateTime? weekStart,
    List<PlanItem>? items,
    bool? loading,
    ApiException? error,
    bool clearError = false,
  }) {
    return WeekPlanState(
      childId: childId ?? this.childId,
      weekStart: weekStart ?? this.weekStart,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The planner (week view): load a week, add/reschedule/skip/delete items with version-conflict handling.
class WeekPlanNotifier extends Notifier<WeekPlanState> {
  @override
  WeekPlanState build() => const WeekPlanState();

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<void> loadWeek(String childId, DateTime anyDayInWeek) async {
    final DateTime start = weekStartOf(anyDayInWeek);
    state = state.copyWith(childId: childId, weekStart: start, loading: true, clearError: true);
    try {
      final Plan plan = await _env.planningRepository.plan(childId, anyDayInWeek);
      if (state.childId != childId || state.weekStart != start) return;
      state = state.copyWith(items: plan.items, loading: false);
    } on ApiException catch (e) {
      if (state.childId != childId || state.weekStart != start) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> _reload() async {
    final String? childId = state.childId;
    final DateTime? weekStart = state.weekStart;
    if (childId == null || weekStart == null) return;
    await loadWeek(childId, weekStart);
  }

  Future<bool> addItem({required String childId, required String activityId, required DateTime date}) async {
    try {
      await _env.planningRepository.addItem(childId: childId, activityId: activityId, date: date);
      await _reload();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<bool> reschedule(PlanItem item, DateTime newDate) => _update(item, scheduledDate: newDate);

  Future<bool> skip(PlanItem item) => _update(item, status: 'skipped');

  Future<bool> _update(PlanItem item, {DateTime? scheduledDate, String? status}) async {
    try {
      await _env.planningRepository.updateItem(item, scheduledDate: scheduledDate, status: status);
      await _reload();
      return true;
    } on ApiException catch (e) {
      // A 409 means someone else changed it: reload so the UI shows the current truth before the parent retries.
      state = state.copyWith(error: e);
      if (e.isConflict) await _reload();
      return false;
    }
  }

  Future<bool> deleteItem(String itemId) async {
    try {
      await _env.planningRepository.deleteItem(itemId);
      state = state.copyWith(items: state.items.where((PlanItem i) => i.id != itemId).toList());
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

final NotifierProvider<WeekPlanNotifier, WeekPlanState> weekPlanProvider =
    NotifierProvider<WeekPlanNotifier, WeekPlanState>(WeekPlanNotifier.new);
