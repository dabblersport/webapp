import 'package:dabbler/features/notifications/meetup_notification_routes.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'm-1';
  final expected = <String, String>{
    'meetup.invited': RoutePaths.meetupDetail(id),
    'meetup.player_joined': RoutePaths.meetupDetail(id),
    'meetup.rsvp_received': RoutePaths.meetupManage(id),
    'meetup.request_received': RoutePaths.meetupManage(id),
    'meetup.request_approved': RoutePaths.meetupDetail(id),
    'meetup.request_declined': RoutePaths.meetupDetail(id),
    'meetup.cancelled': RoutePaths.meetupDetail(id),
  };

  for (final e in expected.entries) {
    test('${e.key} routes with the flag on', () {
      expect(
        meetupNotificationRoute(kindKey: e.key, meetupId: id, enabled: true),
        e.value,
      );
    });
    test('${e.key} has no route with the flag off', () {
      expect(
        meetupNotificationRoute(kindKey: e.key, meetupId: id, enabled: false),
        isNull,
      );
    });
  }

  test('missing id or non-meetup kind gives no route', () {
    expect(
      meetupNotificationRoute(
        kindKey: 'meetup.invited',
        meetupId: null,
        enabled: true,
      ),
      isNull,
    );
    expect(
      meetupNotificationRoute(
        kindKey: 'game.invited',
        meetupId: id,
        enabled: true,
      ),
      isNull,
    );
  });

  group('push fallback', () {
    test('empty action_route with kind and a meetup id derives the route', () {
      final data = {
        'kind_key': 'meetup.request_received',
        'action_route': '',
        'meetup_id': id,
      };
      expect(meetupPushRoute(data, enabled: true), RoutePaths.meetupManage(id));
    });

    test('entity_id is the notification id, so without meetup_id it lands '
        'on the meetups list', () {
      final data = {
        'kind_key': 'meetup.cancelled',
        'action_route': '',
        'entity_id': 'notification-row-id',
      };
      expect(meetupPushRoute(data, enabled: true), RoutePaths.meetups);
    });

    test('host kind routes to manage; meetup.cancelled to the details', () {
      expect(
        meetupPushRoute({
          'kind_key': 'meetup.rsvp_received',
          'action_route': '',
          'meetup_id': id,
        }, enabled: true),
        RoutePaths.meetupManage(id),
      );
      expect(
        meetupPushRoute({
          'kind_key': 'meetup.cancelled',
          'action_route': '',
          'meetup_id': id,
        }, enabled: true),
        RoutePaths.meetupDetail(id),
      );
    });

    test('flag off gives none', () {
      final data = {
        'kind_key': 'meetup.cancelled',
        'action_route': '',
        'meetup_id': id,
      };
      expect(meetupPushRoute(data, enabled: false), isNull);
    });

    test('a present action_route is left to the existing path', () {
      final data = {
        'kind_key': 'meetup.cancelled',
        'action_route': '/x',
        'meetup_id': id,
      };
      expect(meetupPushRoute(data, enabled: true), isNull);
    });
  });
}
