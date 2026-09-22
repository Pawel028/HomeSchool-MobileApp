import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/features/parent/parent_scaffold.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/models/progress.dart';
import 'package:homeschooling/state/parent_view_providers.dart';
import 'package:homeschooling/state/progress_providers.dart';
import 'package:homeschooling/strings.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  String? _loadedForChildId;

  @override
  Widget build(BuildContext context) {
    final Child? child = ref.watch(parentViewedChildProvider);
    final HistoryState history = ref.watch(historyProvider);

    if (child != null && _loadedForChildId != child.id) {
      _loadedForChildId = child.id;
      Future<void>.microtask(() => ref.read(historyProvider.notifier).load(child.id));
    }

    final List<HistoryItem> pending = history.needingReview;

    return ParentScaffold(
      currentPath: '/parent/reviews',
      title: Str.reviewsTitle,
      body: child == null
          ? const EmptyView(message: Str.emptyGeneric, icon: Icons.face_outlined)
          : history.loading && history.items.isEmpty
              ? const LoadingView()
              : history.error != null && history.items.isEmpty
                  ? ErrorView.fromException(history.error!, onRetry: () => ref.read(historyProvider.notifier).load(child.id))
                  : pending.isEmpty
                      ? const EmptyView(message: Str.reviewsEmpty, icon: Icons.check_circle_outline)
                      : RefreshIndicator(
                          onRefresh: () => ref.read(historyProvider.notifier).load(child.id),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: pending.length,
                            itemBuilder: (BuildContext context, int index) {
                              final HistoryItem item = pending[index];
                              return Card(
                                child: ListTile(
                                  title: Text(item.activityTitle),
                                  subtitle: Text('${item.needsReview.length} step(s) to review'),
                                  trailing: FilledButton(
                                    onPressed: () => _openReviewDialog(context, item),
                                    child: const Text(Str.reviewsTitle),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }

  void _openReviewDialog(BuildContext context, HistoryItem item) {
    showDialog<void>(context: context, builder: (BuildContext ctx) => _ReviewDialog(item: item));
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.item});

  final HistoryItem item;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final Map<String, String> _ratings = <String, String>{};

  @override
  void initState() {
    super.initState();
    for (final String stepId in widget.item.needsReview) {
      _ratings[stepId] = 'trying';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> review = ref.watch(reviewProvider);
    return AlertDialog(
      title: Text(widget.item.activityTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(Str.reviewsIntro),
              const SizedBox(height: 12),
              for (final String stepId in widget.item.needsReview)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(stepId)),
                      SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(value: 'trying', label: Text(Str.ratingTrying)),
                          ButtonSegment<String>(value: 'with_help', label: Text(Str.ratingWithHelp)),
                          ButtonSegment<String>(value: 'independent', label: Text(Str.ratingIndependent)),
                        ],
                        selected: <String>{_ratings[stepId] ?? 'trying'},
                        onSelectionChanged: (Set<String> s) => setState(() => _ratings[stepId] = s.first),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(Str.cancel)),
        FilledButton(
          onPressed: review.isLoading
              ? null
              : () async {
                  final bool ok = await ref.read(reviewProvider.notifier).submit(widget.item.sessionId, _ratings);
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
          child: const Text(Str.reviewSubmit),
        ),
      ],
    );
  }
}
