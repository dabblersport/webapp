import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/services/notifications/push_installation_id.dart';
import 'package:dabbler/services/notifications/security_sign_in_registrar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// KAN-1003: every sign-in is registered with the server, whether or not push
// is allowed (the registrar has no permission input at all).
Session _session() => Session(
  accessToken: 'a',
  tokenType: 'bearer',
  user: const User(
    id: 'u',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01',
  ),
);

void main() {
  late List<(String, Map<String, dynamic>)> calls;
  late SecuritySignInRegistrar registrar;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    registrar = SecuritySignInRegistrar(
      rpc: (fn, params) async => calls.add((fn, params)),
      installationId: PushInstallationId(generate: () => 'install-1'),
      platform: () => 'android',
    );
  });

  test('signedIn registers with the right arguments', () async {
    await registrar.onAuthState(
      AuthState(AuthChangeEvent.signedIn, _session()),
    );
    expect(calls, hasLength(1));
    expect(calls.single.$1, SupabaseConfig.rpcSecurityRegisterSignInFn);
    expect(calls.single.$2, <String, dynamic>{
      'p_installation_id': 'install-1',
      'p_platform': 'android',
      'p_device_label': null,
    });
  });

  test('initialSession with a session registers', () async {
    await registrar.onAuthState(
      AuthState(AuthChangeEvent.initialSession, _session()),
    );
    expect(calls, hasLength(1));
  });

  test('initialSession without a session and signedOut do not', () async {
    await registrar.onAuthState(
      AuthState(AuthChangeEvent.initialSession, null),
    );
    await registrar.onAuthState(AuthState(AuthChangeEvent.signedOut, null));
    expect(calls, isEmpty);
  });

  test('a failing call does not throw', () async {
    final failing = SecuritySignInRegistrar(
      rpc: (fn, params) async => throw Exception('boom'),
      installationId: PushInstallationId(generate: () => 'install-1'),
      platform: () => 'web',
    );
    await expectLater(
      failing.onAuthState(AuthState(AuthChangeEvent.signedIn, _session())),
      completes,
    );
  });
}
