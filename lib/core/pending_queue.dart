import 'dart:convert';
import 'dart:math';

import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/core/backoff.dart';
import 'package:homeschooling/core/pending_item.dart';

/// Minimal storage the queue needs (shared_preferences in the app, a map in tests).
abstract class KeyValueStorage {
  String? read(String key);
  Future<void> write(String key, String value);
}

/// The two network calls a queued entry may need. Implemented by the sessions repository.
abstract class PendingSender {
  /// POST /sessions with the entry's client_op_id (idempotent). Returns the session id.
  Future<String> start(PendingSubmit item);

  /// POST /sessions/{id}/submit (idempotent).
  Future<void> submit(PendingSubmit item, String sessionId, Map<String, dynamic> body);
}

class FlushResult {
  const FlushResult({required this.sent, required this.dropped, required this.remaining, required this.offline});

  final int sent;
  final int dropped;
  final int remaining;

  /// A call failed for lack of connectivity: the caller should try again later.
  final bool offline;
}

enum _Step { sent, retryLater, offline, drop }

/// Persisted queue of finished activities that still have to be submitted.
///
/// Rules: oldest first; entries older than [maxAge] are dropped (the API refuses `occurred_at` older than 7 days);
/// failed entries back off exponentially; 4xx answers other than 401/429 are final and drop the entry; a 422 is retried
/// once without `occurred_at` (clock skew) before it is dropped.
class PendingQueue {
  PendingQueue({
    required KeyValueStorage storage,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 7),
    this.maxAttempts = 25,
    Random? random,
  })  : _storage = storage,
        _clock = clock ?? DateTime.now,
        _random = random;

  static const String storageKey = 'pending_submits_v1';

  final KeyValueStorage _storage;
  final DateTime Function() _clock;
  final Random? _random;
  final Duration maxAge;
  final int maxAttempts;

  List<PendingSubmit> _items = <PendingSubmit>[];
  bool _flushing = false;

  List<PendingSubmit> get items => List<PendingSubmit>.unmodifiable(_items);
  int get length => _items.length;
  bool get isFlushing => _flushing;

  void load() {
    final String? raw = _storage.read(storageKey);
    if (raw == null || raw.isEmpty) {
      _items = <PendingSubmit>[];
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      final List<PendingSubmit> parsed = <PendingSubmit>[];
      if (decoded is List) {
        for (final Object? e in decoded) {
          try {
            if (e is Map) parsed.add(PendingSubmit.fromJson(Map<String, dynamic>.from(e)));
          } on FormatException {
            // A damaged entry is skipped; the rest of the queue survives.
          }
        }
      }
      _items = parsed;
    } on FormatException {
      _items = <PendingSubmit>[];
    }
  }

  Future<void> enqueue(PendingSubmit item) async {
    final int index = _items.indexWhere((PendingSubmit i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    await _persist();
  }

  /// Earliest time a retry is due (null = queue empty, or something is due right now).
  Duration? delayUntilNextAttempt() {
    if (_items.isEmpty) return null;
    final DateTime now = _clock();
    Duration? best;
    for (final PendingSubmit i in _items) {
      final DateTime? at = i.nextAttemptAt;
      final Duration d = (at == null || !at.isAfter(now)) ? Duration.zero : at.difference(now);
      if (best == null || d < best) best = d;
    }
    return best;
  }

  Future<FlushResult> flush(PendingSender sender, {bool ignoreBackoff = false}) async {
    if (_flushing) return FlushResult(sent: 0, dropped: 0, remaining: _items.length, offline: false);
    _flushing = true;
    int sent = 0;
    int dropped = 0;
    bool offline = false;
    try {
      final List<PendingSubmit> snapshot = List<PendingSubmit>.of(_items);
      for (final PendingSubmit item in snapshot) {
        if (_isTooOld(item)) {
          await _remove(item.id);
          dropped++;
          continue;
        }
        final DateTime? due = item.nextAttemptAt;
        if (!ignoreBackoff && due != null && due.isAfter(_clock())) continue;

        final _Step step = await _attempt(sender, item);
        switch (step) {
          case _Step.sent:
            await _remove(item.id);
            sent++;
          case _Step.drop:
            await _remove(item.id);
            dropped++;
          case _Step.retryLater:
            if (await _scheduleRetry(item.id)) dropped++;
          case _Step.offline:
            offline = true;
            await _scheduleRetry(item.id);
        }
        if (offline) break;
      }
    } finally {
      _flushing = false;
    }
    return FlushResult(sent: sent, dropped: dropped, remaining: _items.length, offline: offline);
  }

  Future<_Step> _attempt(PendingSender sender, PendingSubmit start) async {
    PendingSubmit item = start;
    try {
      String? sessionId = item.sessionId;
      if (sessionId == null) {
        sessionId = await sender.start(item);
        item = item.copyWith(sessionId: sessionId);
        await enqueue(item);
      }
      await sender.submit(item, sessionId, item.submitBody());
      return _Step.sent;
    } on NetworkException {
      return _Step.offline;
    } on ApiException catch (e) {
      if (e.code == 'validation_error' && !item.omitOccurredAt) {
        final PendingSubmit again = item.copyWith(omitOccurredAt: true);
        await enqueue(again);
        return _attempt(sender, again);
      }
      final int? status = e.status;
      if (status != null && (status >= 500 || status == 429 || status == 401 || status == 408)) {
        return _Step.retryLater;
      }
      return _Step.drop;
    } catch (_) {
      return _Step.retryLater;
    }
  }

  /// Bumps the attempt counter and sets the next due time. Returns true when the entry was dropped instead.
  Future<bool> _scheduleRetry(String id) async {
    final int index = _items.indexWhere((PendingSubmit i) => i.id == id);
    if (index < 0) return false;
    final PendingSubmit current = _items[index];
    final int attempts = current.attempts + 1;
    if (attempts >= maxAttempts) {
      _items.removeAt(index);
      await _persist();
      return true;
    }
    final Duration wait = backoffDelay(attempts, jitter: 0.2, random: _random);
    _items[index] = current.copyWith(attempts: attempts, nextAttemptAt: _clock().add(wait));
    await _persist();
    return false;
  }

  bool _isTooOld(PendingSubmit item) {
    final Duration limit = maxAge - const Duration(minutes: 5);
    return _clock().difference(item.occurredAt) > limit;
  }

  Future<void> _remove(String id) async {
    _items.removeWhere((PendingSubmit i) => i.id == id);
    await _persist();
  }

  Future<void> _persist() {
    final String json = jsonEncode(_items.map((PendingSubmit i) => i.toJson()).toList());
    return _storage.write(storageKey, json);
  }
}
