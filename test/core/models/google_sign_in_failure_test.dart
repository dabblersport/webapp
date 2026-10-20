// KAN-570: the Google sign-in failure type. Pure unit tests; nothing real is
// called and no real token, email or client id is used.
import 'package:dabbler/core/models/google_sign_in_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('GoogleSignInFailure.from', () {
    test(
      'a DEVELOPER_ERROR (ApiException 10) from the native stage keeps only the status',
      () {
        final f = GoogleSignInFailure.from(
          GoogleSignInStage.native,
          PlatformException(
            code: 'sign_in_failed',
            message: 'com.google.android.gms.common.api.ApiException: 10: ',
          ),
        );
        expect(f.stage, GoogleSignInStage.native);
        expect(f.code, '10');
        expect('$f', 'google:native:10');
      },
    );

    test('a network error status (7) and a plain code word are kept', () {
      expect(
        GoogleSignInFailure.from(
          GoogleSignInStage.native,
          PlatformException(code: 'network_error', message: 'ApiException: 7'),
        ).code,
        '7',
      );
      expect(
        GoogleSignInFailure.from(
          GoogleSignInStage.native,
          PlatformException(code: 'network_error'),
        ).code,
        'network_error',
      );
    });

    test('a Supabase refusal of the id token keeps its error code only', () {
      final f = GoogleSignInFailure.from(
        GoogleSignInStage.exchange,
        AuthApiException(
          'Unacceptable audience in id_token: [FAKE-CLIENT-ID.apps.example]',
          statusCode: '400',
          code: 'bad_jwt',
        ),
      );
      expect('$f', 'google:exchange:bad_jwt');
      expect('$f', isNot(contains('FAKE-CLIENT-ID')));
    });

    test(
      'with no code the HTTP status is kept; with neither it is "error"',
      () {
        expect(
          GoogleSignInFailure.from(
            GoogleSignInStage.exchange,
            AuthException('boom', statusCode: '502'),
          ).code,
          '502',
        );
        expect(
          GoogleSignInFailure.from(
            GoogleSignInStage.exchange,
            StateError('x'),
          ).code,
          'error',
        );
      },
    );

    test('provider text, emails and tokens never reach the string form', () {
      const secret = 'eyJFAKE.TOKEN.VALUE person@example.invalid';
      for (final error in <Object>[
        PlatformException(code: secret, message: secret),
        AuthException(secret, statusCode: secret, code: secret),
        Exception(secret),
        secret,
      ]) {
        final f = GoogleSignInFailure.from(GoogleSignInStage.unknown, error);
        expect('$f', isNot(contains('FAKE')));
        expect('$f', isNot(contains('@')));
        expect('$f', matches(RegExp(r'^google:[a-z]+:[a-z0-9_.-]{1,40}$')));
      }
    });

    test('an existing failure is passed through unchanged', () {
      const original = GoogleSignInFailure(
        GoogleSignInStage.idToken,
        'missing',
      );
      expect(
        identical(
          GoogleSignInFailure.from(GoogleSignInStage.native, original),
          original,
        ),
        isTrue,
      );
    });
  });
}
