import 'package:homeschooling/models/json.dart';

/// Response of GET /v1/config (public, no auth).
class RemoteConfig {
  const RemoteConfig({
    required this.env,
    required this.minAppVersion,
    required this.declarationNoticeVersion,
    this.features = const <String, dynamic>{},
  });

  final String env;
  final String minAppVersion;
  final String declarationNoticeVersion;
  final Map<String, dynamic> features;

  bool feature(String key) => features[key] == true;

  factory RemoteConfig.fromJson(Map<String, dynamic> j) => RemoteConfig(
        env: optString(j, 'env') ?? '',
        minAppVersion: optString(j, 'min_app_version') ?? '0.0.0',
        declarationNoticeVersion: reqString(j, 'declaration_notice_version'),
        features: j['features'] is Map ? asJsonMap(j['features']) : <String, dynamic>{},
      );
}
