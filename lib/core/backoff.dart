import 'dart:math';

/// Exponential backoff: base, 2*base, 4*base ... capped. `attempt` starts at 1.
/// Pass `jitter` (0..1) together with a `random` to spread retries; without a random the result is deterministic.
Duration backoffDelay(
  int attempt, {
  Duration base = const Duration(seconds: 5),
  Duration cap = const Duration(minutes: 15),
  double jitter = 0,
  Random? random,
}) {
  final int a = attempt < 1 ? 1 : (attempt > 20 ? 20 : attempt);
  int ms = base.inMilliseconds * (1 << (a - 1));
  if (ms > cap.inMilliseconds) ms = cap.inMilliseconds;
  if (jitter > 0 && random != null) {
    final double factor = 1 - jitter + random.nextDouble() * jitter * 2;
    ms = (ms * factor).round();
    if (ms > cap.inMilliseconds) ms = cap.inMilliseconds;
  }
  return Duration(milliseconds: ms);
}
