import 'package:dabbler/core/services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-760: web and Android Apple sign-in through Supabase OAuth.
class _FakeAuth extends Fake implements GoTrueClient {
  final calls = <String>[];
  Map<String, Object?> args = {};

  // signInWithOAuth is an extension on GoTrueClient, so the seam takes it as a
  // callback and the web test passes this one.
  Future<void> webSignIn(
    OAuthProvider provider, {
    String? redirectTo,
    String? scopes,
  }) async {
    calls.add('signInWithOAuth');
    args = {'provider': provider, 'redirectTo': redirectTo, 'scopes': scopes};
  }

  @override
  Future<OAuthResponse> getOAuthSignInUrl({
    OAuthProvider? provider,
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    calls.add('getOAuthSignInUrl');
    args = {'provider': provider, 'redirectTo': redirectTo, 'scopes': scopes};
    return OAuthResponse(
      provider: provider ?? OAuthProvider.apple,
      url: 'https://apple.test/auth',
    );
  }

  @override
  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    calls.add('exchange:$authCode');
    return AuthSessionUrlResponse(
      session: Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-11-02T00:00:00Z',
        ),
      ),
      redirectType: null,
    );
  }
}

void main() {
  late _FakeAuth auth;
  setUp(() => auth = _FakeAuth());

  Future<String> never(String url, String scheme) async =>
      fail('web must not open an in-app sheet');

  test('web calls signInWithOAuth with apple and returns true', () async {
    final ok = await AuthService.signInWithAppleOAuth(
      isWeb: true,
      auth: auth,
      authenticate: never,
      webOrigin: 'https://alpha.dabbler.pro',
      webSignIn: auth.webSignIn,
    );

    expect(ok, isTrue);
    expect(auth.calls, ['signInWithOAuth']);
    expect(auth.args['provider'], OAuthProvider.apple);
    expect(auth.args['redirectTo'], 'https://alpha.dabbler.pro');
    expect(auth.args['scopes'], 'name email');
  });

  test('android exchanges the returned code', () async {
    String? seenUrl;
    String? seenScheme;

    final ok = await AuthService.signInWithAppleOAuth(
      isWeb: false,
      auth: auth,
      authenticate: (url, scheme) async {
        seenUrl = url;
        seenScheme = scheme;
        return 'dabbler://app/?code=abc123';
      },
    );

    expect(ok, isTrue);
    expect(auth.args['provider'], OAuthProvider.apple);
    expect(auth.args['scopes'], 'name email');
    expect(auth.args['redirectTo'], endsWith('/'));
    expect(seenUrl, 'https://apple.test/auth');
    expect(seenScheme, 'dabbler');
    expect(auth.calls, ['getOAuthSignInUrl', 'exchange:abc123']);
  });

  test('android cancel returns false', () async {
    final ok = await AuthService.signInWithAppleOAuth(
      isWeb: false,
      auth: auth,
      authenticate: (_, _) async => throw PlatformException(code: 'CANCELED'),
    );

    expect(ok, isFalse);
    expect(auth.calls, ['getOAuthSignInUrl']);
  });

  test('android missing code throws an Apple exception', () async {
    await expectLater(
      AuthService.signInWithAppleOAuth(
        isWeb: false,
        auth: auth,
        authenticate: (_, _) async => 'dabbler://app/?error=denied',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Apple'),
        ),
      ),
    );
    expect(auth.calls, ['getOAuthSignInUrl']);
  });
}
