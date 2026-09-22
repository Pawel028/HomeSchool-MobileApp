import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/core/app_version.dart';
import 'package:homeschooling/models/remote_config.dart';
import 'package:homeschooling/state/environment.dart';

/// `GET /v1/config`. Fetched once at startup; `app.dart` blocks on this (with a retry UI) before showing
/// anything else, both to read `declaration_notice_version` and to enforce `min_app_version`.
final FutureProvider<RemoteConfig> remoteConfigProvider = FutureProvider<RemoteConfig>((Ref ref) {
  final AppEnvironment env = ref.watch(environmentProvider);
  return env.configRepository.fetch();
});

/// True when this build is older than the server's `min_app_version` and must show the update gate.
bool updateIsRequired(RemoteConfig config) => isUpdateRequired(current: kAppVersion, minimum: config.minAppVersion);
