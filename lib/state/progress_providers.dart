import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/models/progress.dart';
import 'package:homeschooling/state/environment.dart';

/// Parent dashboard (overview + today + recommendations) for one child.
final dashboardProvider = FutureProvider.family<Dashboard, String>(
  (Ref ref, String childId) => ref.watch(environmentProvider).progressRepository.dashboard(childId),
);

class MasteryQuery {
  const MasteryQuery(this.childId, {this.subject});

  final String childId;
  final String? subject;

  @override
  bool operator ==(Object other) => other is MasteryQuery && other.childId == childId && other.subject == subject;

  @override
  int get hashCode => Object.hash(childId, subject);
}

final masteryProvider =
    FutureProvider.family<List<Mastery>, MasteryQuery>((Ref ref, MasteryQuery query) {
  return ref.watch(environmentProvider).progressRepository.mastery(query.childId, subject: query.subject);
});

/// Finished-session history for one child, used both for a general history list and to find `needs_review`
/// sessions for the Reviews screen.
class HistoryState {
  const HistoryState({this.childId, this.items = const <HistoryItem>[], this.loading = false, this.hasMore = true, this.error});

  final String? childId;
  final List<HistoryItem> items;
  final bool loading;
  final bool hasMore;
  final ApiException? error;

  List<HistoryItem> get needingReview => items.where((HistoryItem i) => i.needsReview.isNotEmpty).toList();

  HistoryState copyWith({
    String? childId,
    List<HistoryItem>? items,
    bool? loading,
    bool? hasMore,
    ApiException? error,
    bool clearError = false,
  }) {
    return HistoryState(
      childId: childId ?? this.childId,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  AppEnvironment get _env => ref.read(environmentProvider);
  static const int _pageSize = 30;

  Future<void> load(String childId) async {
    state = HistoryState(childId: childId, loading: true);
    try {
      final List<HistoryItem> items = await _env.progressRepository.history(childId, limit: _pageSize);
      if (state.childId != childId) return;
      state = state.copyWith(items: items, loading: false, hasMore: items.length >= _pageSize);
    } on ApiException catch (e) {
      if (state.childId != childId) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final String? childId = state.childId;
    if (childId == null || !state.hasMore || state.loading) return;
    state = state.copyWith(loading: true);
    try {
      final List<HistoryItem> page =
          await _env.progressRepository.history(childId, limit: _pageSize, offset: state.items.length);
      state = state.copyWith(
        items: <HistoryItem>[...state.items, ...page],
        loading: false,
        hasMore: page.length >= _pageSize,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Removes a session from the "needs review" view after `POST /sessions/{id}/review` succeeds, without a
  /// full reload.
  void markReviewed(String sessionId) {
    state = state.copyWith(
      items: <HistoryItem>[
        for (final HistoryItem i in state.items)
          if (i.sessionId == sessionId)
            HistoryItem(
              sessionId: i.sessionId,
              activityTitle: i.activityTitle,
              subjectCode: i.subjectCode,
              submittedAt: i.submittedAt,
              durationSec: i.durationSec,
              score: i.score,
              parentAssist: i.parentAssist,
              needsReview: const <String>[],
            )
          else
            i,
      ],
    );
  }
}

final NotifierProvider<HistoryNotifier, HistoryState> historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);

/// Observations and the baseline checklist: write-only actions, so a tiny notifier is enough (the mastery
/// list itself is re-fetched by invalidating [masteryProvider] after a successful write).
class ObservationsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<bool> observe({
    required String childId,
    required String skillCode,
    required String rating,
    String? note,
  }) async {
    state = const AsyncLoading<void>();
    try {
      await _env.progressRepository.observe(
        childId: childId,
        skillCode: skillCode,
        rating: rating,
        note: note,
        occurredAt: DateTime.now(),
      );
      state = const AsyncData<void>(null);
      ref.invalidate(masteryProvider);
      ref.invalidate(dashboardProvider);
      return true;
    } on ApiException catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> submitBaseline(String childId, Map<String, String> ratingsBySkill) async {
    state = const AsyncLoading<void>();
    try {
      await _env.progressRepository.baseline(childId, ratingsBySkill);
      state = const AsyncData<void>(null);
      ref.invalidate(masteryProvider);
      return true;
    } on ApiException catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }
}

final NotifierProvider<ObservationsNotifier, AsyncValue<void>> observationsProvider =
    NotifierProvider<ObservationsNotifier, AsyncValue<void>>(ObservationsNotifier.new);

/// `POST /sessions/{id}/review`: a parent rates the steps a session flagged as `needs_review`.
class ReviewNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<bool> submit(String sessionId, Map<String, String> ratings, {bool? parentAssist}) async {
    state = const AsyncLoading<void>();
    try {
      await _env.sessionRepository.review(sessionId, ratings, parentAssist: parentAssist);
      state = const AsyncData<void>(null);
      ref.read(historyProvider.notifier).markReviewed(sessionId);
      return true;
    } on ApiException catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }
}

final NotifierProvider<ReviewNotifier, AsyncValue<void>> reviewProvider =
    NotifierProvider<ReviewNotifier, AsyncValue<void>>(ReviewNotifier.new);
