import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/pending_queue.dart';
import 'package:homeschooling/state/environment.dart';

class PendingQueueSummary {
  const PendingQueueSummary({this.pendingCount = 0, this.flushing = false, this.lastFlushOffline = false});

  final int pendingCount;
  final bool flushing;

  /// True when the most recent flush attempt could not reach the server at all (shows a small "will sync
  /// later" indicator rather than a hard error, since the child's own submit already succeeded locally).
  final bool lastFlushOffline;
}

/// Periodically flushes [PendingQueue] (finished activities that could not be submitted yet) and reports a
/// count for a small sync badge. `player_providers.dart` also calls [flushNow] right after queuing an item.
class PendingQueueNotifier extends Notifier<PendingQueueSummary> {
  Timer? _timer;

  @override
  PendingQueueSummary build() {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 45), (Timer _) => flushNow());
    return PendingQueueSummary(pendingCount: _env.pendingQueue.length);
  }

  AppEnvironment get _env => ref.read(environmentProvider);

  Future<void> flushNow() async {
    if (state.flushing) return;
    state = PendingQueueSummary(pendingCount: _env.pendingQueue.length, flushing: true);
    final FlushResult result = await _env.pendingQueue.flush(_env.sessionRepository);
    state = PendingQueueSummary(
      pendingCount: _env.pendingQueue.length,
      flushing: false,
      lastFlushOffline: result.offline,
    );
  }
}

final NotifierProvider<PendingQueueNotifier, PendingQueueSummary> pendingQueueProvider =
    NotifierProvider<PendingQueueNotifier, PendingQueueSummary>(PendingQueueNotifier.new);
