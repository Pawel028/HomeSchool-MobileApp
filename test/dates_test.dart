import 'package:flutter_test/flutter_test.dart';
import 'package:homeschooling/core/dates.dart';

void main() {
  group('weekStartOf', () {
    test('a Wednesday snaps back to Monday', () {
      final DateTime wed = DateTime(2026, 9, 23); // a Wednesday
      expect(weekStartOf(wed), DateTime(2026, 9, 21));
    });

    test('a Monday stays put', () {
      final DateTime mon = DateTime(2026, 9, 21);
      expect(weekStartOf(mon), mon);
    });

    test('a Sunday belongs to the week that started the previous Monday', () {
      final DateTime sun = DateTime(2026, 9, 27);
      expect(weekStartOf(sun), DateTime(2026, 9, 21));
    });
  });

  test('weekDays returns 7 consecutive days starting Monday', () {
    final List<DateTime> days = weekDays(DateTime(2026, 9, 21));
    expect(days.length, 7);
    expect(days.first, DateTime(2026, 9, 21));
    expect(days.last, DateTime(2026, 9, 27));
    for (int i = 0; i < 7; i++) {
      expect(days[i].weekday, i + 1);
    }
  });

  test('formatApiDate/parseApiDate round trip and pad', () {
    final DateTime d = DateTime(2026, 1, 5);
    expect(formatApiDate(d), '2026-01-05');
    expect(parseApiDate('2026-01-05'), d);
  });

  test('friendlyDate labels today and tomorrow, otherwise weekday + month/day', () {
    final DateTime today = DateTime(2026, 9, 21);
    expect(friendlyDate(today, today), 'Today');
    expect(friendlyDate(addDays(today, 1), today), 'Tomorrow');
    expect(friendlyDate(addDays(today, 2), today), 'Wed, Sep 23');
  });

  test('daysActiveInWeek counts distinct local calendar days, not timestamps', () {
    final DateTime now = DateTime(2026, 9, 23, 10);
    final List<DateTime> timestamps = <DateTime>[
      DateTime(2026, 9, 21, 8),
      DateTime(2026, 9, 21, 20),
      DateTime(2026, 9, 22, 9),
      DateTime(2026, 8, 1), // outside the week: ignored
    ];
    expect(daysActiveInWeek(timestamps, now), 2);
  });

  test('formatMinSec pads seconds and never goes negative', () {
    expect(formatMinSec(65), '01:05');
    expect(formatMinSec(0), '00:00');
    expect(formatMinSec(-5), '00:00');
  });
}
