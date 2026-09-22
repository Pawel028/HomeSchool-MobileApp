/// Build-time configuration, injected with `--dart-define-from-file=env/<flavor>.json`.
/// These values ship inside the app: never put secrets in the env files.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
  static const String envName = String.fromEnvironment('ENV_NAME', defaultValue: 'dev');

  static bool get isProd => envName == 'prod';

  /// True when the env file still holds the placeholder that tools/check-env.ps1 refuses to build with.
  static bool get hasPlaceholderUrl => apiBaseUrl.contains('REPLACE-WITH');
}
