import 'package:dabbler/services/notifications/push_notification_service_mobile.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  setUpAll(initHomeTestSupabase);

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
}
