import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thrown by [Environment.load] when required client configuration is absent.
/// Its message is shown on the start-up error screen, so it says what to do.
class EnvironmentConfigException implements Exception {
  EnvironmentConfigException(this.missing);

  /// The names of the missing keys (never values).
  final List<String> missing;

  @override
  String toString() =>
      'Missing configuration: ${missing.join(', ')}.\n\n'
      'One-time local setup: from Dabbler/dabbler-code run '
      '`scripts/setup_local_env.sh` (it reads your local .env, or '
      '`--from <file>`), then run `flutter run -d <device-id>` again. '
      'See docs/LOCAL_RUN.md. Release and CI builds must pass '
      '--dart-define values instead.';
}

class Environment {
  /// The gitignored local client configuration, written by
  /// `scripts/setup_local_env.sh` and bundled only through the
  /// `assets/config/` asset directory. Read in non-release builds when the
  /// build did not supply the required `--dart-define` values.
  static const String localConfigAsset = 'assets/config/local.env';

  /// A compile-time value wins; else the local value; else empty. This is the
  /// precedence for every key.
  @visibleForTesting
  static String resolve(String compileTime, String? local) =>
      compileTime.isNotEmpty ? compileTime : (local ?? '');

  // Prefer compile-time values when present (e.g. web deployments).
  // These are provided via `--dart-define=KEY=value` at build time.
  static const String _supabaseUrlDefine = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _supabaseAnonKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String _supabasePublishableKeyDefine = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  static const String _appNameDefine = String.fromEnvironment(
    'APP_NAME',
    defaultValue: '',
  );
  static const String _environmentDefine = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: '',
  );
  static const String _googleWebClientIdDefine = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static const String _mapboxAccessTokenDefine = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String _tenorApiKeyDefine = String.fromEnvironment(
    'TENOR_API_KEY',
    defaultValue: '',
  );
  static const String _giphyApiKeyDefine = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: '',
  );

  static const String _messagingApiBaseUrlDefine = String.fromEnvironment(
    'MESSAGING_API_BASE_URL',
    defaultValue: '',
  );

  static bool get _definesComplete =>
      _supabaseUrlDefine.isNotEmpty &&
      _supabaseAnonKeyDefine.isNotEmpty &&
      _appNameDefine.isNotEmpty;

  /// Resolves the configuration. Explicit `--dart-define` values (CI, release,
  /// `--dart-define-from-file`) take precedence and, when complete, nothing is
  /// read. Otherwise, outside release builds, the gitignored local file
  /// ([localConfigAsset]) is read. [assetLoader] is a seam for tests.
  ///
  /// Throws [EnvironmentConfigException] when a required key is still missing.
  static Future<void> load({
    Future<String> Function(String path)? assetLoader,
  }) async {
    String content = '';
    if (!_definesComplete && !kReleaseMode) {
      try {
        content = await (assetLoader ?? rootBundle.loadString)(
          localConfigAsset,
        );
      } catch (_) {
        // No local setup: the diagnostic below says how to create it.
      }
    }
    dotenv.testLoad(fileInput: content);
    _validate();
  }

  static String get supabaseUrl =>
      resolve(_supabaseUrlDefine, dotenv.env['SUPABASE_URL']);
  static String get supabaseAnonKey =>
      resolve(_supabaseAnonKeyDefine, dotenv.env['SUPABASE_ANON_KEY']);
  static String get supabasePublishableKey => resolve(
    _supabasePublishableKeyDefine,
    dotenv.env['SUPABASE_PUBLISHABLE_KEY'],
  );
  static String get appName => resolve(_appNameDefine, dotenv.env['APP_NAME']);
  static String get environment => _environmentDefine.isNotEmpty
      ? _environmentDefine
      : (dotenv.env['ENVIRONMENT'] ?? 'production');

  /// Optional: the messaging Worker origin (KAN-550). Empty by default; the
  /// client appends `/v1/...`. A flag-on build without it shows the
  /// unavailable state rather than calling anything.
  static String get messagingApiBaseUrl => resolve(
    _messagingApiBaseUrlDefine,
    dotenv.isInitialized ? dotenv.env['MESSAGING_API_BASE_URL'] : null,
  );

  // Optional: Google Sign-In configuration
  // - Web: required for google_sign_in on Flutter web
  // - Mobile: usually configured via google-services.json / GoogleService-Info.plist
  static String get googleWebClientId =>
      resolve(_googleWebClientIdDefine, dotenv.env['GOOGLE_WEB_CLIENT_ID']);

  /// Mapbox public access token for Search / Geocoding APIs.
  static String get mapboxAccessToken =>
      resolve(_mapboxAccessTokenDefine, dotenv.env['MAPBOX_ACCESS_TOKEN']);

  /// Tenor GIF API key (Google Cloud) — deprecated, Tenor shut down Jan 2026.
  static String get tenorApiKey =>
      resolve(_tenorApiKeyDefine, dotenv.env['TENOR_API_KEY']);

  /// GIPHY API key — used for GIF search in the post composer.
  static String get giphyApiKey =>
      resolve(_giphyApiKeyDefine, dotenv.env['GIPHY_API_KEY']);

  static void _validate() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (appName.isEmpty) missing.add('APP_NAME');
    if (environment.isEmpty) missing.add('ENVIRONMENT');

    if (missing.isNotEmpty) throw EnvironmentConfigException(missing);
  }

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
}
