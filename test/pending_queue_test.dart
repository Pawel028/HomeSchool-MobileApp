import 'package:flutter_test/flutter_test.dart';
import 'package:homeschooling/core/api_exception.dart';
import 'package:homeschooling/core/pending_item.dart';
import 'package:homeschooling/core/pending_queue.dart';
import 'package:mocktail/mocktail.dart';

class _FakeStorage implements KeyValueStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  String? read(String key) => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }
}

class _MockSender extends Mock implements PendingSender {}

PendingSubmit _item(String id, {DateTime? occurredAt, int attempts = 0, DateTime? nextAttemptAt}) {
  final DateTime now = occurredAt ?? DateTime.utc(2026, 9, 22, 10);
  return PendingSubmit(
    id: id,
    childId: 'child-1',
    activityId: 'activity-1',
    clientOpId: 'op-$id',
    body: const <String, dynamic>{'answers': <String, dynamic>{}, 'hints_used': 0, 'parent_assist': false, 'duration_sec': 30},
    occurredAt: now,
    createdAt: now,
    auth: 'child',
    attempts: attempts,
    nextAttemptAt: nextAttemptAt,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_item('fallback'));
    registerFallbackValue(<String, dynamic>{});
  });

  test('flush starts then submits a fresh entry and removes it on success', () async {
    final _FakeStorage storage = _FakeStorage();
    final PendingQueue queue = PendingQueue(storage: storage, clock: () => DateTime.utc(2026, 9, 22, 10, 5));
    queue.load();
    await queue.enqueue(_item('a'));

    final _MockSender sender = _MockSender();
    when(() => sender.start(any())).thenAnswer((_) async => 'session-1');
    when(() => sender.submit(any(), any(), any())).thenAnswer((_) async {});

    final FlushResult result = await queue.flush(sender);

    expect(result.sent, 1);
    expect(result.dropped, 0);
    expect(queue.length, 0);
    verify(() => sender.start(any())).called(1);
    verify(() => sender.submit(any(), 'session-1', any())).called(1);
  });

  test('a network failure schedules a backoff retry and reports offline', () async {
    final _FakeStorage storage = _FakeStorage();
    final PendingQueue queue = PendingQueue(storage: storage, clock: () => DateTime.utc(2026, 9, 22, 10, 5));
    queue.load();
    await queue.enqueue(_item('b'));

    final _MockSender sender = _MockSender();
    when(() => sender.start(any())).thenThrow(const NetworkException());

    final FlushResult result = await queue.flush(sender);

    expect(result.offline, isTrue);
    expect(result.sent, 0);
    expect(queue.length, 1);
    expect(queue.items.single.attempts, 1);
    expect(queue.items.single.nextAttemptAt, isNotNull);
  });

  test('a 4xx other than 401/408/429 is final and drops the entry', () async {
    final _FakeStorage storage = _FakeStorage();
    final PendingQueue queue = PendingQueue(storage: storage, clock: () => DateTime.utc(2026, 9, 22, 10, 5));
    queue.load();
    await queue.enqueue(_item('c'));

    final _MockSender sender = _MockSender();
    when(() => sender.start(any())).thenThrow(const ServerException('forbidden', '', status: 403));

    final FlushResult result = await queue.flush(sender);

    expect(result.dropped, 1);
    expect(queue.length, 0);
  });

  test('a validation_error retries once with occurred_at omitted, then succeeds', () async {
    final _FakeStorage storage = _FakeStorage();
    final PendingQueue queue = PendingQueue(storage: storage, clock: () => DateTime.utc(2026, 9, 22, 10, 5));
    queue.load();
    await queue.enqueue(_item('d'));

    final _MockSender sender = _MockSender();
    when(() => sender.start(any())).thenAnswer((_) async => 'session-2');
    var submitCalls = 0;
    when(() => sender.submit(any(), any(), any())).thenAnswer((Invocation inv) async {
      submitCalls++;
      if (submitCalls == 1) throw const ServerException('validation_error', '', status: 422);
    });

    final FlushResult result = await queue.flush(sender);

    expect(submitCalls, 2);
    expect(result.sent, 1);
    expect(queue.length, 0);
  });

  test('an entry older than maxAge is dropped without being sent', () async {
    final _FakeStorage storage = _FakeStorage();
    final DateTime now = DateTime.utc(2026, 9, 22, 10, 5);
    final PendingQueue queue = PendingQueue(storage: storage, clock: () => now, maxAge: const Duration(days: 7));
    queue.load();
    await queue.enqueue(_item('e', occurredAt: now.subtract(const Duration(days: 8))));

    final _MockSender sender = _MockSender();
    final FlushResult result = await queue.flush(sender);

    expect(result.dropped, 1);
    expect(queue.length, 0);
    verifyNever(() => sender.start(any()));
  });

  test('an entry not yet due is skipped unless ignoreBackoff is set', () async {
    final _FakeStorage storage = _FakeStorage();
    final DateTime now = DateTime.utc(2026, 9, 22, 10, 5);
    final PendingQueue queue = PendingQueue(storage: storage, clock: () => now);
    queue.load();
    await queue.enqueue(_item('f', nextAttemptAt: now.add(const Duration(minutes: 5))));

    final _MockSender sender = _MockSender();
    when(() => sender.start(any())).thenAnswer((_) async => 'session-3');
    when(() => sender.submit(any(), any(), any())).thenAnswer((_) async {});

    final FlushResult skipped = await queue.flush(sender);
    expect(skipped.sent, 0);
    expect(queue.length, 1);

    final FlushResult forced = await queue.flush(sender, ignoreBackoff: true);
    expect(forced.sent, 1);
    expect(queue.length, 0);
  });

  test('persisted entries survive a reload of the queue', () async {
    final _FakeStorage storage = _FakeStorage();
    final PendingQueue first = PendingQueue(storage: storage);
    first.load();
    await first.enqueue(_item('g'));

    final PendingQueue second = PendingQueue(storage: storage);
    second.load();
    expect(second.length, 1);
    expect(second.items.single.id, 'g');
  });
}
