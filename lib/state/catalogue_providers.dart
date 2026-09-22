import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/data/catalogue_repository.dart';
import 'package:homeschooling/models/activity.dart';
import 'package:homeschooling/state/environment.dart';

class CatalogueState {
  const CatalogueState({
    this.query = '',
    this.subject,
    this.level,
    this.interest,
    this.results = const <ActivitySummary>[],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final String query;
  final String? subject;
  final String? level;
  final String? interest;
  final List<ActivitySummary> results;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final ApiException? error;

  CatalogueState copyWith({
    String? query,
    String? subject,
    bool clearSubject = false,
    String? level,
    bool clearLevel = false,
    String? interest,
    bool clearInterest = false,
    List<ActivitySummary>? results,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    ApiException? error,
    bool clearError = false,
  }) {
    return CatalogueState(
      query: query ?? this.query,
      subject: clearSubject ? null : (subject ?? this.subject),
      level: clearLevel ? null : (level ?? this.level),
      interest: clearInterest ? null : (interest ?? this.interest),
      results: results ?? this.results,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Activity library: search, filter and page through `/v1/activities`.
class CatalogueNotifier extends Notifier<CatalogueState> {
  @override
  CatalogueState build() => const CatalogueState();

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<void> search({String? query, String? subject, String? level, String? interest}) async {
    state = CatalogueState(
      query: query ?? state.query,
      subject: subject ?? state.subject,
      level: level ?? state.level,
      interest: interest ?? state.interest,
      loading: true,
    );
    await _fetch(offset: 0);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading || state.loadingMore) return;
    state = state.copyWith(loadingMore: true);
    await _fetch(offset: state.results.length, append: true);
  }

  Future<void> _fetch({required int offset, bool append = false}) async {
    try {
      final List<ActivitySummary> page = await _env.catalogueRepository.list(
        subject: state.subject,
        level: state.level,
        interest: state.interest,
        query: state.query.isEmpty ? null : state.query,
        offset: offset,
      );
      state = state.copyWith(
        results: append ? <ActivitySummary>[...state.results, ...page] : page,
        loading: false,
        loadingMore: false,
        hasMore: page.length >= CatalogueRepository.pageSize,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, loadingMore: false, error: e);
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final NotifierProvider<CatalogueNotifier, CatalogueState> catalogueProvider =
    NotifierProvider<CatalogueNotifier, CatalogueState>(CatalogueNotifier.new);
