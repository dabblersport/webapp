import 'package:dabbler/services/notifications/push_installation_id.dart';
import 'package:dabbler/services/notifications/push_notification_service_mobile.dart';
import 'package:dabbler/services/notifications/push_token_registrar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/home_test_harness.dart' show initHomeTestSupabase;

/// The app never asks for the native notification permission at start: `init`
/// only reads the status, and `requestNotificationPermission` (the signed-in
/// user turning notifications on in the app) is the one place that prompts.
class _FakePermission implements PushPermissionGateway {
  _FakePermission(this.current, {this.afterRequest});

  AuthorizationStatus current;

  /// What the system answers once the user has been asked.
  final AuthorizationStatus? afterRequest;
  int statusReads = 0;
  int requests = 0;

  @override
  Future<AuthorizationStatus> status() async {
    statusReads++;
    return current;
  }

  @override
  Future<AuthorizationStatus> request() async {
    requests++;
    current = afterRequest ?? current;
    return current;
  }
}

/// Records the KAN-977 RPC calls the mobile service makes.
class _Rpc {
  final calls = <(String, Map<String, dynamic>)>[];

  Future<dynamic> call(String fn, Map<String, dynamic> params) async {
    calls.add((fn, Map.of(params)));
    return fn == 'rpc_unregister_push_token' ? true : 'row-id';
  }
}

PushTokenRegistrar _registrar(_Rpc rpc) => PushTokenRegistrar(
  rpc: rpc.call,
  currentUserId: () => 'user-a',
  appVersion: () async => '1.8.0+42',
  installationId: PushInstallationId(generate: () => 'install-1'),
);

void main() {
  setUpAll(initHomeTestSupabase);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final status in <AuthorizationStatus>[
    AuthorizationStatus.notDetermined,
    AuthorizationStatus.denied,
    AuthorizationStatus.authorized,
    AuthorizationStatus.provisional,
  ]) {
    test(
      'init never requests the permission (status ${status.name})',
      () async {
        final fake = _FakePermission(status);
        final service = PushNotificationService.forTest()..permission = fake;
        await service.init();
        // It read the status to decide what to set up; it never asked.
        expect(fake.statusReads, greaterThanOrEqualTo(1));
        expect(fake.requests, 0);
      },
    );
  }

  test('init twice still never requests', () async {
    final fake = _FakePermission(AuthorizationStatus.notDetermined);
    final service = PushNotificationService.forTest()..permission = fake;
    await service.init();
    await service.init();
    expect(fake.requests, 0);
  });

  test('turning notifications on asks once and reports the answer', () async {
    final fake = _FakePermission(
      AuthorizationStatus.notDetermined,
      afterRequest: AuthorizationStatus.authorized,
    );
    final service = PushNotificationService.forTest()..permission = fake;
    await service.init();
    expect(fake.requests, 0);
    expect(await service.requestNotificationPermission(), isTrue);
    expect(fake.requests, 1);
  });

  test('a refusal at the native prompt is reported as not granted', () async {
    final fake = _FakePermission(
      AuthorizationStatus.notDetermined,
      afterRequest: AuthorizationStatus.denied,
    );
    final service = PushNotificationService.forTest()..permission = fake;
    expect(await service.requestNotificationPermission(), isFalse);
    expect(fake.requests, 1);
  });

  group('token registration (KAN-977)', () {
    test('registers through the RPC, never the table', () async {
      final rpc = _Rpc();
      final service = PushNotificationService.forTest()
        ..permission = _FakePermission(AuthorizationStatus.authorized)
        ..registrar = _registrar(rpc);
      await service.registerToken('fcm-1');
      expect(rpc.calls.single.$1, 'rpc_register_push_token');
      expect(rpc.calls.single.$2, {
        'p_installation_id': 'install-1',
        'p_token': 'fcm-1',
        'p_platform': defaultTargetPlatform.name,
        'p_app_version': '1.8.0+42',
        'p_locale': null,
        'p_os_permission': 'granted',
      });
    });

    test('a token refresh updates the same installation', () async {
      final rpc = _Rpc();
      final service = PushNotificationService.forTest()
        ..permission = _FakePermission(AuthorizationStatus.authorized)
        ..registrar = _registrar(rpc);
      await service.registerToken('fcm-1');
      await service.registerToken('fcm-2');
      expect(rpc.calls.map((c) => c.$2['p_token']), ['fcm-1', 'fcm-2']);
      expect(rpc.calls.map((c) => c.$2['p_installation_id']).toSet(), {
        'install-1',
      });
    });

    test('the locale is sent, and a locale change re-registers', () async {
      final rpc = _Rpc();
      final service = PushNotificationService.forTest()
        ..permission = _FakePermission(AuthorizationStatus.provisional)
        ..registrar = _registrar(rpc);
      await service.updateLocale(const Locale('en'));
      expect(rpc.calls, isEmpty, reason: 'no token yet');
      await service.registerToken('fcm-1');
      await service.updateLocale(const Locale('ar'));
      expect(rpc.calls.map((c) => c.$2['p_locale']), ['en', 'ar']);
      expect(rpc.calls.last.$2['p_os_permission'], 'provisional');
    });

    test('a denied permission is reported as denied', () async {
      final rpc = _Rpc();
      final service = PushNotificationService.forTest()
        ..permission = _FakePermission(AuthorizationStatus.denied)
        ..registrar = _registrar(rpc);
      await service.registerToken('fcm-1');
      expect(rpc.calls.single.$2['p_os_permission'], 'denied');
    });

    test('sign-out unregisters this installation and keeps its id', () async {
      final rpc = _Rpc();
      final service = PushNotificationService.forTest()
        ..permission = _FakePermission(AuthorizationStatus.authorized)
        ..registrar = _registrar(rpc);
      await service.registerToken('fcm-1');
      await service.revokeToken();
      expect(rpc.calls.last.$1, 'rpc_unregister_push_token');
      expect(rpc.calls.last.$2, {'p_installation_id': 'install-1'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PushInstallationId.prefsKey), 'install-1');
    });
  });
}
