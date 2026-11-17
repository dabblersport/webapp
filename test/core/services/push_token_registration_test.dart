import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/services/notifications/push_installation_id.dart';
import 'package:dabbler/services/notifications/push_notification_service_web.dart'
    as web;
import 'package:dabbler/services/notifications/push_token_registrar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every RPC call and answers like the live backend (KAN-977).
class FakeRpc {
  final calls = <(String, Map<String, dynamic>)>[];
  Object? throwOnNext;

  Future<dynamic> call(String fn, Map<String, dynamic> params) async {
    final error = throwOnNext;
    throwOnNext = null;
    if (error != null) throw error;
    calls.add((fn, Map.of(params)));
    if (fn == SupabaseConfig.rpcUnregisterPushToken) return true;
    return 'row-${calls.length}';
  }
}

PushTokenRegistrar registrarWith(
  FakeRpc rpc, {
  String? Function()? user,
  PushInstallationId? id,
}) => PushTokenRegistrar(
  rpc: rpc.call,
  currentUserId: user ?? () => 'user-a',
  appVersion: () async => '1.8.0+42',
  installationId: id ?? PushInstallationId(generate: () => 'install-1'),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('installation id', () {
    test('is created once and then read back unchanged', () async {
      var made = 0;
      final id = PushInstallationId(generate: () => 'uuid-${++made}');
      final first = await id.read();
      final second = await id.read();
      // A fresh instance (an app restart) reads the stored value.
      final third = await PushInstallationId(
        generate: () => 'uuid-${++made}',
      ).read();
      expect(first, 'uuid-1');
      expect(second, first);
      expect(third, first);
      expect(made, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PushInstallationId.prefsKey), 'uuid-1');
    });

    test('concurrent first reads share one id', () async {
      var made = 0;
      final id = PushInstallationId(generate: () => 'uuid-${++made}');
      final both = await Future.wait([id.read(), id.read()]);
      expect(both, ['uuid-1', 'uuid-1']);
      expect(made, 1);
    });

    test('the default is a uuid v4 that never starts with legacy:', () async {
      final value = await PushInstallationId().read();
      expect(
        value,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(value.startsWith('legacy:'), isFalse);
    });

    test('a stored legacy:, blank or over-long value is replaced', () async {
      for (final bad in ['legacy:android', '  ', 'x' * 129]) {
        SharedPreferences.setMockInitialValues({
          PushInstallationId.prefsKey: bad,
        });
        final value = await PushInstallationId(generate: () => 'fresh').read();
        expect(value, 'fresh', reason: bad);
      }
    });

    test('survives sign-out (unregister keeps it)', () async {
      final rpc = FakeRpc();
      final id = PushInstallationId(generate: () => 'install-1');
      final registrar = registrarWith(rpc, id: id);
      await registrar.register(token: 't1', platform: 'android');
      final result = await registrar.unregister();
      expect(result.requireValue, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PushInstallationId.prefsKey), 'install-1');
      // Signing in again registers the same installation.
      await registrar.register(token: 't2', platform: 'android');
      expect(rpc.calls.last.$2['p_installation_id'], 'install-1');
    });
  });

  group('permission mapping', () {
    test('maps every AuthorizationStatus', () {
      expect(osPermissionWire(AuthorizationStatus.authorized), 'granted');
      expect(osPermissionWire(AuthorizationStatus.denied), 'denied');
      expect(osPermissionWire(AuthorizationStatus.provisional), 'provisional');
      expect(osPermissionWire(AuthorizationStatus.notDetermined), isNull);
      expect(osPermissionWire(null), isNull);
    });
  });

  group('register params', () {
    test('carry the contract keys and values', () {
      final params = pushRegisterParams(
        installationId: 'install-1',
        token: 'tok',
        platform: 'iOS',
        appVersion: '1.8.0+42',
        locale: const Locale('ar', 'AE'),
        permission: AuthorizationStatus.provisional,
      );
      expect(params, {
        'p_installation_id': 'install-1',
        'p_token': 'tok',
        'p_platform': 'iOS',
        'p_app_version': '1.8.0+42',
        'p_locale': 'ar-AE',
        'p_os_permission': 'provisional',
      });
    });

    test('nullable values stay null and long values are clipped', () {
      final params = pushRegisterParams(
        installationId: 'i',
        token: 't',
        platform: 'android',
        appVersion: 'v' * 80,
      );
      expect(params['p_locale'], isNull);
      expect(params['p_os_permission'], isNull);
      expect((params['p_app_version'] as String).length, 64);
    });

    test('platform is web on the web, else the target platform name', () {
      expect(
        pushPlatformName(isWeb: true, platform: TargetPlatform.android),
        'web',
      );
      expect(
        pushPlatformName(isWeb: false, platform: TargetPlatform.iOS),
        'iOS',
      );
      expect(
        pushPlatformName(isWeb: false, platform: TargetPlatform.android),
        'android',
      );
    });
  });

  group('registrar', () {
    test('register calls the register RPC with the full params', () async {
      final rpc = FakeRpc();
      final registrar = registrarWith(rpc)..setLocale(const Locale('en'));
      final result = await registrar.register(
        token: 'tok',
        platform: 'android',
        permission: AuthorizationStatus.authorized,
      );
      expect(result.requireValue, 'row-1');
      expect(rpc.calls.single.$1, 'rpc_register_push_token');
      expect(rpc.calls.single.$2, {
        'p_installation_id': 'install-1',
        'p_token': 'tok',
        'p_platform': 'android',
        'p_app_version': '1.8.0+42',
        'p_locale': 'en',
        'p_os_permission': 'granted',
      });
    });

    test('signed out: nothing is sent', () async {
      final rpc = FakeRpc();
      final registrar = registrarWith(rpc, user: () => null);
      await registrar.register(token: 'tok', platform: 'android');
      expect((await registrar.unregister()).requireValue, isFalse);
      expect(rpc.calls, isEmpty);
    });

    test('a token refresh sends again; an identical call does not', () async {
      final rpc = FakeRpc();
      final registrar = registrarWith(rpc);
      await registrar.register(token: 't1', platform: 'android');
      await registrar.register(token: 't1', platform: 'android');
      await registrar.register(token: 't2', platform: 'android');
      expect(rpc.calls.map((c) => c.$2['p_token']), ['t1', 't2']);
      expect(rpc.calls.map((c) => c.$2['p_installation_id']).toSet(), {
        'install-1',
      });
    });

    test('a locale or permission change is sent on resync', () async {
      final rpc = FakeRpc();
      final registrar = registrarWith(rpc)..setLocale(const Locale('en'));
      await registrar.register(
        token: 't1',
        platform: 'iOS',
        permission: AuthorizationStatus.authorized,
      );
      expect(registrar.setLocale(const Locale('en')), isFalse);
      expect(registrar.setLocale(const Locale('ar')), isTrue);
      await registrar.resync(
        platform: 'iOS',
        permission: AuthorizationStatus.authorized,
      );
      await registrar.resync(
        platform: 'iOS',
        permission: AuthorizationStatus.denied,
      );
      expect(rpc.calls.map((c) => c.$2['p_locale']), ['en', 'ar', 'ar']);
      expect(rpc.calls.map((c) => c.$2['p_os_permission']), [
        'granted',
        'granted',
        'denied',
      ]);
    });

    test('resync before any token is a no-op', () async {
      final rpc = FakeRpc();
      final result = await registrarWith(rpc).resync(platform: 'android');
      expect(result.isSuccess, isTrue);
      expect(rpc.calls, isEmpty);
    });

    test('another user on the same installation registers again', () async {
      final rpc = FakeRpc();
      var user = 'user-a';
      final registrar = registrarWith(rpc, user: () => user);
      await registrar.register(token: 't1', platform: 'android');
      user = 'user-b';
      await registrar.register(token: 't1', platform: 'android');
      expect(rpc.calls, hasLength(2));
    });

    test('a failed RPC is a Failure and is retried next time', () async {
      final rpc = FakeRpc()..throwOnNext = Exception('42501');
      final registrar = registrarWith(rpc);
      final failed = await registrar.register(token: 't1', platform: 'android');
      expect(failed.isFailure, isTrue);
      final retried = await registrar.register(
        token: 't1',
        platform: 'android',
      );
      expect(retried.requireValue, 'row-1');
    });

    test('unregister sends only the installation id', () async {
      final rpc = FakeRpc();
      final registrar = registrarWith(rpc);
      await registrar.register(token: 't1', platform: 'android');
      await registrar.unregister();
      expect(rpc.calls.last.$1, 'rpc_unregister_push_token');
      expect(rpc.calls.last.$2, {'p_installation_id': 'install-1'});
      expect(registrar.token, isNull);
    });
  });

  group('web path', () {
    test('registers with platform web and the browser permission', () async {
      final rpc = FakeRpc();
      final service = web.PushNotificationService.forTest()
        ..registrar = registrarWith(rpc)
        ..readPermission = () async => AuthorizationStatus.authorized;
      await service.updateLocale(const Locale('ar'));
      await service.registerToken('web-tok');
      expect(rpc.calls.single.$1, 'rpc_register_push_token');
      expect(rpc.calls.single.$2['p_platform'], 'web');
      expect(rpc.calls.single.$2['p_token'], 'web-tok');
      expect(rpc.calls.single.$2['p_locale'], 'ar');
      expect(rpc.calls.single.$2['p_os_permission'], 'granted');
    });

    test('a locale change after registering is sent again', () async {
      final rpc = FakeRpc();
      final service = web.PushNotificationService.forTest()
        ..registrar = registrarWith(rpc)
        ..readPermission = () async => AuthorizationStatus.authorized;
      await service.updateLocale(const Locale('en'));
      await service.registerToken('web-tok');
      await service.updateLocale(const Locale('ar'));
      expect(rpc.calls.map((c) => c.$2['p_locale']), ['en', 'ar']);
    });

    test('sign-out unregisters this installation, keeping its id', () async {
      final rpc = FakeRpc();
      final service = web.PushNotificationService.forTest()
        ..registrar = registrarWith(
          rpc,
          id: PushInstallationId(generate: () => 'browser-1'),
        )
        ..readPermission = () async => AuthorizationStatus.authorized;
      await service.registerToken('web-tok');
      await service.revokeToken();
      expect(rpc.calls.last.$1, 'rpc_unregister_push_token');
      expect(rpc.calls.last.$2, {'p_installation_id': 'browser-1'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PushInstallationId.prefsKey), 'browser-1');
    });

    test('a permission read failure sends a null permission', () async {
      final rpc = FakeRpc();
      final service = web.PushNotificationService.forTest()
        ..registrar = registrarWith(rpc)
        ..readPermission = () async => throw Exception('no firebase');
      await service.registerToken('web-tok');
      expect(rpc.calls.single.$2['p_os_permission'], isNull);
    });
  });
}
