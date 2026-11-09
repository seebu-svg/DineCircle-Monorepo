/// Build-time configuration read from dart-define flags.
///
/// Usage:
///   flutter run --dart-define-from-file=dart-defines.json
///   flutter build web --dart-define-from-file=dart-defines.json
///
/// `apiBaseUrl` is the API *root* (`http://host:4000`); every repository path
/// is relative to [apiUrl], which appends the shared `/api` prefix the Express
/// server mounts both clients under.
class AppConfig {
  AppConfig._();

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Root of the DineCircle Express API (no trailing slash).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  /// All REST routes live under `/api`, same base as the customer app.
  static String get apiUrl => '$apiBaseUrl/api';

  static const int apiTimeoutMs = int.fromEnvironment(
    'API_TIMEOUT_MS',
    defaultValue: 30000,
  );

  static const bool enableDebugLogging = bool.fromEnvironment(
    'ENABLE_DEBUG_LOGGING',
    defaultValue: false,
  );

  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );

  static const bool enableCrashReporting = bool.fromEnvironment(
    'ENABLE_CRASH_REPORTING',
    defaultValue: false,
  );

  /// Surfaced in Settings → About so a tester can confirm which build they run.
  static const String appVersion = '1.0.0';

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  /// True when a production build was compiled against a non-HTTPS host.
  ///
  /// Release manifests no longer permit cleartext traffic, so such a build
  /// fails every request. Surfacing this at startup turns an opaque network
  /// error into a named configuration mistake.
  static bool get isInsecureProductionBuild =>
      isProduction && !apiBaseUrl.startsWith('https://');

  /// Safe to show in the debug sheet: no token, no secret.
  static Map<String, Object> toDebugMap() => {
    'environment': environment,
    'apiUrl': apiUrl,
    'apiTimeoutMs': apiTimeoutMs,
    'enableDebugLogging': enableDebugLogging,
    'enableAnalytics': enableAnalytics,
    'enableCrashReporting': enableCrashReporting,
  };
}
