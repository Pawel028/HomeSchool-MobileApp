/// Keep in sync with `version:` in pubspec.yaml (test/app_version_test.dart checks it).
const String kAppVersion = '0.1.0';

/// Compares dotted numeric versions: "1.2.10" is greater than "1.2.9".
/// Build metadata ("+3") and pre-release suffixes ("-beta") are ignored; non-numeric parts count as 0.
int compareVersions(String a, String b) {
  final List<int> pa = _parts(a);
  final List<int> pb = _parts(b);
  final int n = pa.length > pb.length ? pa.length : pb.length;
  for (int i = 0; i < n; i++) {
    final int x = i < pa.length ? pa[i] : 0;
    final int y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

List<int> _parts(String version) {
  final String core = version.split('+').first.split('-').first.trim();
  if (core.isEmpty) return <int>[0];
  return core.split('.').map((String p) => int.tryParse(p) ?? 0).toList();
}

bool isUpdateRequired({required String current, required String minimum}) => compareVersions(current, minimum) < 0;
