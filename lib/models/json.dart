// Small helpers so that every fromJson stays boring and fails with a readable FormatException.

Map<String, dynamic> asJsonMap(Object? value, [String what = 'object']) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected $what to be a JSON object');
}

List<dynamic> asJsonList(Object? value, [String what = 'array']) {
  if (value is List) return value;
  throw FormatException('Expected $what to be a JSON array');
}

String reqString(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  if (v is String) return v;
  throw FormatException('Missing string "$key"');
}

String? optString(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is String ? v : null;
}

int reqInt(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw FormatException('Missing integer "$key"');
}

int? optInt(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

double reqDouble(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  if (v is num) return v.toDouble();
  throw FormatException('Missing number "$key"');
}

double? optDouble(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is num ? v.toDouble() : null;
}

bool boolOr(Map<String, dynamic> m, String key, {bool fallback = false}) {
  final Object? v = m[key];
  return v is bool ? v : fallback;
}

List<String> stringList(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  if (v is List) return v.whereType<String>().toList();
  return <String>[];
}

DateTime reqDateTime(Map<String, dynamic> m, String key) {
  final String s = reqString(m, key);
  final DateTime? parsed = DateTime.tryParse(s);
  if (parsed == null) throw FormatException('Bad timestamp "$key"');
  return parsed;
}

DateTime? optDateTime(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is String ? DateTime.tryParse(v) : null;
}

/// `YYYY-MM-DD` to a local date-only DateTime (no time zone maths: plan dates are the family's calendar dates).
DateTime reqDate(Map<String, dynamic> m, String key) {
  final String s = reqString(m, key);
  final List<String> p = s.split('-');
  if (p.length < 3) throw FormatException('Bad date "$key"');
  final int? y = int.tryParse(p[0]);
  final int? mo = int.tryParse(p[1]);
  final int? d = int.tryParse(p[2].length > 2 ? p[2].substring(0, 2) : p[2]);
  if (y == null || mo == null || d == null) throw FormatException('Bad date "$key"');
  return DateTime(y, mo, d);
}

List<T> mapList<T>(Object? value, T Function(Map<String, dynamic> json) build) {
  if (value is! List) return <T>[];
  return value.map<T>((Object? e) => build(asJsonMap(e))).toList();
}
