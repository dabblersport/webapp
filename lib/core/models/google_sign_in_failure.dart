import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The stage of the native Android Google sign-in that failed (KAN-570).
enum GoogleSignInStage {
  /// The Google account chooser / Credential Manager (`GoogleSignIn.signIn`).
  /// An `ApiException: 10` here is DEVELOPER_ERROR: the package + signing
  /// certificate is not registered for the Android OAuth client.
  native,

  /// The account came back but without an id token (no `serverClientId`, or
  /// one that does not match a Web OAuth client).
  idToken,

  /// Supabase refused the id token (`signInWithIdToken`), e.g. a wrong
  /// audience or a provider that is not enabled.
  exchange,

  /// Anything else.
  unknown,
}

/// A Google sign-in failure that is safe to show and to report: it carries the
/// [stage] and a short sanitized [code] (an Android API status number, a
/// Supabase auth error code or HTTP status, or a fixed word) and NOTHING from
/// the provider's message, so no token, email, client id or account detail can
/// reach the screen, a log or an error report through it.
class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.stage, this.code);

  final GoogleSignInStage stage;
  final String code;

  static final RegExp _apiStatus = RegExp(r'ApiException:\s*(\d{1,5})');
  static final RegExp _safeWord = RegExp(r'^[a-z0-9_.-]{1,40}$');

  /// The failure for [error] thrown at [stage]. Only a status number or a
  /// lower-case code word is kept; everything else becomes `error`.
  factory GoogleSignInFailure.from(GoogleSignInStage stage, Object error) {
    if (error is GoogleSignInFailure) return error;
    if (error is PlatformException) {
      final status = _apiStatus.firstMatch('${error.message}')?.group(1);
      if (status != null) return GoogleSignInFailure(stage, status);
      return GoogleSignInFailure(stage, _word(error.code));
    }
    if (error is AuthException) {
      final code = error.code;
      if (code != null && code.isNotEmpty) {
        return GoogleSignInFailure(stage, _word(code));
      }
      return GoogleSignInFailure(stage, _word(error.statusCode ?? 'error'));
    }
    return GoogleSignInFailure(stage, 'error');
  }

  static String _word(String raw) {
    final lower = raw.toLowerCase();
    return _safeWord.hasMatch(lower) ? lower : 'error';
  }

  /// `google:<stage>:<code>`: short, fixed-shape, safe to show.
  @override
  String toString() => 'google:${stage.name}:$code';
}
