import 'package:homeschooling/strings.dart';

/// Calendar helpers. Plan dates are the family's calendar dates, so all maths here is on date-only local values.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Monday of the week containing [d] (the API's weeks start on Monday).
DateTime weekStartOf(DateTime d) {
  final DateTime day = dateOnly(d);
  return addDays(day, -(day.weekday - DateTime.monday));
}

List<DateTime> weekDays(DateTime weekStart) => List<DateTime>.generate(7, (int i) => addDays(weekStart, i));

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// `YYYY-MM-DD`, as the API expects.
String formatApiDate(DateTime d) {
  final String y = d.year.toString().padLeft(4, '0');
  final String m = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime parseApiDate(String s) {
  final List<String> p = s.split('-');
  if (p.length != 3) throw FormatException('Bad date: $s');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String weekdayShort(DateTime d) => Str.weekdaysShort[d.weekday - 1];

String monthDay(DateTime d) => '${Str.monthsShort[d.month - 1]} ${d.day}';

/// "Today", "Tomorrow" or "Mon, Sep 21".
String friendlyDate(DateTime d, DateTime today) {
  if (isSameDay(d, today)) return Str.today;
  if (isSameDay(d, addDays(today, 1))) return Str.tomorrow;
  return '${weekdayShort(d)}, ${monthDay(d)}';
}

/// "Sep 21 - Sep 27".
String weekRangeLabel(DateTime weekStart) => '${monthDay(weekStart)} - ${monthDay(addDays(weekStart, 6))}';

/// How many distinct (local) calendar days in the week containing [now] have at least one timestamp.
/// Used for the child's "days you learned this week" (the streak endpoint is parent-only).
int daysActiveInWeek(Iterable<DateTime> timestamps, DateTime now) {
  final DateTime start = weekStartOf(now);
  final DateTime end = addDays(start, 7);
  final Set<String> days = <String>{};
  for (final DateTime t in timestamps) {
    final DateTime local = dateOnly(t.toLocal());
    if (!local.isBefore(start) && local.isBefore(end)) days.add(formatApiDate(local));
  }
  return days.length;
}

/// Time of day for the greeting: 0 = morning, 1 = afternoon, 2 = evening.
int dayPart(DateTime now) {
  if (now.hour < 12) return 0;
  if (now.hour < 17) return 1;
  return 2;
}

/// "12:05" for 125 seconds.
String formatMinSec(int totalSeconds) {
  final int s = totalSeconds < 0 ? 0 : totalSeconds;
  final String m = (s ~/ 60).toString().padLeft(2, '0');
  final String r = (s % 60).toString().padLeft(2, '0');
  return '$m:$r';
}
