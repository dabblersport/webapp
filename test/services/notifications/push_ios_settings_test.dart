// KAN-1047: iOS details for a locally drawn push, and the Settings link route.

import 'package:dabbler/services/notifications/push_local_display.dart';
import 'package:dabbler/services/notifications/push_presence.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/app/routes/profile_social_routes.dart';

void main() {
  group('darwinDetailsFor', () {
    test('thread id is the channel_key', () {
      final d = darwinDetailsFor({'channel_key': 'games.reminders'});
      expect(d.threadIdentifier, 'games.reminders');
      expect(d.interruptionLevel, isNull);
    });

    test('no or empty channel_key gives no thread id', () {
      expect(darwinDetailsFor({}).threadIdentifier, isNull);
      expect(darwinDetailsFor({'channel_key': ''}).threadIdentifier, isNull);
    });

    test('interruption levels map from the payload', () {
      InterruptionLevel? of(Object? v) =>
          darwinDetailsFor({'interruption_level': v}).interruptionLevel;
      expect(of('time-sensitive'), InterruptionLevel.timeSensitive);
      expect(of('time_sensitive'), InterruptionLevel.timeSensitive);
      expect(of('active'), InterruptionLevel.active);
      expect(of('passive'), InterruptionLevel.passive);
      expect(of('critical'), isNull);
      expect(of(null), isNull);
    });
  });

  test('the Settings link opens the in-app notification settings route', () {
    final route = settingsNotificationsRoute as GoRoute;
    expect(PushPresence.notificationSettingsRoute, route.path);
  });

  test('a link tapped before anything listens is kept once', () {
    final p = PushPresence.instance;
    expect(p.takePendingOpenSettings(), isFalse);
  });
}
