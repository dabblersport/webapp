import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
    _validate();
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get appName => dotenv.env['APP_NAME'] ?? '';
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'production';

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
