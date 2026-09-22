import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeschooling/core/app_version.dart';

/// Keeps `pubspec.yaml`'s `version:` and `lib/core/app_version.dart`'s `kAppVersion` from drifting apart —
/// the min-app-version gate (see state/config_providers.dart) compares `kAppVersion` against the server, so
/// a stale constant would make the gate lie.
void main() {
  test('kAppVersion matches the version in pubspec.yaml', () {
    final File pubspec = File('pubspec.yaml');
    final List<String> lines = pubspec.readAsLinesSync();
    final String versionLine = lines.firstWhere((String l) => l.trim().startsWith('version:'));
    final String pubspecVersion = versionLine.split(':')[1].trim().split('+').first;
    expect(kAppVersion, pubspecVersion);
  });

  group('compareVersions', () {
    test('numeric parts compare correctly, not lexicographically', () {
      expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
      expect(compareVersions('1.2.9', '1.2.10'), lessThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('ignores build metadata and pre-release suffixes', () {
      expect(compareVersions('1.2.0+5', '1.2.0'), 0);
      expect(compareVersions('1.2.0-beta', '1.2.0'), 0);
    });

    test('shorter version is padded with zeros', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.3', '1.2.9'), greaterThan(0));
    });
  });

  group('isUpdateRequired', () {
    test('true when current is below minimum', () {
      expect(isUpdateRequired(current: '0.9.0', minimum: '1.0.0'), isTrue);
    });

    test('false when current meets or exceeds minimum', () {
      expect(isUpdateRequired(current: '1.0.0', minimum: '1.0.0'), isFalse);
      expect(isUpdateRequired(current: '1.1.0', minimum: '1.0.0'), isFalse);
    });
  });
}
