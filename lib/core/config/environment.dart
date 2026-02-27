import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  // Prefer compile-time values when present (e.g. web deployments).
  // These are provided via `--dart-define=KEY=value` at build time.
  static const String _supabaseUrlDefine =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _supabaseAnonKeyDefine =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String _supabasePublishableKeyDefine =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');
  static const String _appNameDefine =
    String.fromEnvironment('APP_NAME', defaultValue: '');
  static const String _environmentDefine =
    String.fromEnvironment('ENVIRONMENT', defaultValue: '');
  static const String _googleWebClientIdDefine =
    String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  static Future<void> load() async {
  // On web, avoid runtime loading of `.env` assets.
  // Many CDNs/WAFs (e.g. Cloudflare) block `.env` paths by default,
  // causing a silent misconfiguration where Supabase isn't initialized.
  // Web deployments should use `--dart-define` instead.
  if (!kIsWeb) {
    await dotenv.load(fileName: '.env');
  }
    _validate();
  }

  static String get supabaseUrl =>
    _supabaseUrlDefine.isNotEmpty ? _supabaseUrlDefine : (dotenv.env['SUPABASE_URL'] ?? '');
  static String get supabaseAnonKey =>
    _supabaseAnonKeyDefine.isNotEmpty ? _supabaseAnonKeyDefine : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
  static String get supabasePublishableKey => _supabasePublishableKeyDefine
      .isNotEmpty
    ? _supabasePublishableKeyDefine
    : (dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '');
  static String get appName =>
    _appNameDefine.isNotEmpty ? _appNameDefine : (dotenv.env['APP_NAME'] ?? '');
  static String get environment => _environmentDefine.isNotEmpty
    ? _environmentDefine
    : (dotenv.env['ENVIRONMENT'] ?? 'production');

  // Optional: Google Sign-In configuration
  // - Web: required for google_sign_in on Flutter web
  // - Mobile: usually configured via google-services.json / GoogleService-Info.plist
  static String get googleWebClientId =>
      _googleWebClientIdDefine.isNotEmpty
        ? _googleWebClientIdDefine
        : (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '');

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
