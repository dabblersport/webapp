import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
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

  static Future<void> load() async {
    // Secrets are provided at build time via --dart-define (see README).
    // `.env` is intentionally NOT bundled as a Flutter asset, so it never
    // ships inside the APK/IPA. We still attempt a best-effort load for
    // local developer convenience, but the app must run fine without it.
    //
    // Run locally with:  flutter run --dart-define-from-file=.env
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // No `.env` asset present (the normal case for release/CI builds).
      // Initialize an empty map so dotenv.env[...] lookups don't throw;
      // all values then come from --dart-define.
      dotenv.testLoad(fileInput: '');
    }
    _validate();
  }

  static String get supabaseUrl => _supabaseUrlDefine.isNotEmpty
      ? _supabaseUrlDefine
      : (dotenv.env['SUPABASE_URL'] ?? '');
  static String get supabaseAnonKey => _supabaseAnonKeyDefine.isNotEmpty
      ? _supabaseAnonKeyDefine
      : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
  static String get supabasePublishableKey =>
      _supabasePublishableKeyDefine.isNotEmpty
      ? _supabasePublishableKeyDefine
      : (dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '');
  static String get appName => _appNameDefine.isNotEmpty
      ? _appNameDefine
      : (dotenv.env['APP_NAME'] ?? '');
  static String get environment => _environmentDefine.isNotEmpty
      ? _environmentDefine
      : (dotenv.env['ENVIRONMENT'] ?? 'production');

  // Optional: Google Sign-In configuration
  // - Web: required for google_sign_in on Flutter web
  // - Mobile: usually configured via google-services.json / GoogleService-Info.plist
  static String get googleWebClientId => _googleWebClientIdDefine.isNotEmpty
      ? _googleWebClientIdDefine
      : (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '');

  /// Mapbox public access token for Search / Geocoding APIs.
  static String get mapboxAccessToken => _mapboxAccessTokenDefine.isNotEmpty
      ? _mapboxAccessTokenDefine
      : (dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '');

  /// Tenor GIF API key (Google Cloud) — deprecated, Tenor shut down Jan 2026.
  static String get tenorApiKey => _tenorApiKeyDefine.isNotEmpty
      ? _tenorApiKeyDefine
      : (dotenv.env['TENOR_API_KEY'] ?? '');

  /// GIPHY API key — used for GIF search in the post composer.
  static String get giphyApiKey => _giphyApiKeyDefine.isNotEmpty
      ? _giphyApiKeyDefine
      : (dotenv.env['GIPHY_API_KEY'] ?? '');

  static void _validate() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (appName.isEmpty) missing.add('APP_NAME');
    if (environment.isEmpty) missing.add('ENVIRONMENT');

    if (missing.isNotEmpty) {
      throw Exception('Missing environment variables: ${missing.join(', ')}');
    }
  }

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
}
