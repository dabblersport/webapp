// KAN-1016: v15's data-only Android pushes (RSVP, waitlist, message) are drawn
// by the app — in the background isolate and in the foreground — on the
// data's channel with the category's actions; a push with a notification
// block is left to FCM in the background.
import 'package:dabbler/services/notifications/push_background.dart';
import 'package:dabbler/services/notifications/push_contract.dart';
import 'package:dabbler/services/notifications/push_notification_service_mobile.dart';
import 'package:dabbler/services/notifications/push_presence.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The v15 data of a waitlist promotion (comment 16485's keys).
const Map<String, String> _waitlist = {
  'kind_key': 'game.waitlist_promoted',
  'entity_type': 'game',
  'entity_id': 'g1',
  'game_id': 'g1',
  'notification_id': 'n1',
  'dedupe_key': 'd1',
  'category': 'DABBLER_WAITLIST',
  'delivery_mode': 'alert',
  'android_channel_id': 'dabbler_games',
  'collapse_id': 'game:g1',
  'title': "You've been promoted from the waitlist",
  'body': 'You have a place in the game now.',
  'badge': '3',
};

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rules', () {
    test('a data-only push draws from its data', () {
      final d = pushDrawingOf(_waitlist)!;
      expect(d.title, _waitlist['title']);
      expect(d.body, _waitlist['body']);
      expect(d.channelId, 'dabbler_games');
      expect(d.tag, 'game:g1');
      expect(
        isDataOnlyPush(hasNotificationBlock: false, data: _waitlist),
        isTrue,
      );
      expect(
        isDataOnlyPush(hasNotificationBlock: true, data: _waitlist),
        isFalse,
        reason: 'FCM draws a notification message itself',
      );
    });

    test('the notification block wins; no text draws nothing', () {
      final d = pushDrawingOf(
        _waitlist,
        notificationTitle: 'T',
        notificationBody: 'B',
        notificationChannelId: 'dabbler_social',
        notificationTag: 'tag',
      )!;
      expect(
        [d.title, d.body, d.channelId, d.tag],
        ['T', 'B', 'dabbler_social', 'tag'],
      );
      expect(pushDrawingOf({'kind_key': 'game.invited'}), isNull);
      expect(pushDrawingOf({'body': 'x'}, collapseKey: 'ck')!.tag, 'ck');
    });

    test('the payload keys line up with the contract', () {
      expect(PushChannels.of(_waitlist), 'games.invites');
      expect(PushCategories.of(_waitlist), PushCategories.waitlist);
      expect(PushCategories.actionsOf(_waitlist), [PushActionId.cancelPlace]);
      expect(pushBadge(_waitlist), 3);
      expect(pushDedupeKey(_waitlist), 'd1');
      expect(
        const OpenChat(
          conversationId: 'c1',
        ).shows({'category': 'DABBLER_MESSAGE', 'conversation_id': 'c1'}),
        isTrue,
      );
    });

    test('background labels follow the device: Arabic, else English', () {
      expect(
        pushBackgroundLocale(const Locale('ar', 'AE')),
        const Locale('ar'),
      );
      expect(pushBackgroundLocale(const Locale('fr')), const Locale('en'));
    });
  });

  group('drawing', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'initialize' => true,
              'getNotificationAppLaunchDetails' => null,
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    Map<dynamic, dynamic> shown() =>
        calls.lastWhere((c) => c.method == 'show').arguments as Map;

    test('background: channels created, the push shown on its channel with '
        'Cancel my place', () async {
      await drawBackgroundPush(const RemoteMessage(data: _waitlist));
      final created = calls
          .where((c) => c.method == 'createNotificationChannel')
          .map((c) => (c.arguments as Map)['id'])
          .toList();
      expect(created, containsAll(['games.invites', 'dabbler_quiet']));
      final show = shown();
      expect(show['title'], _waitlist['title']);
      expect(show['body'], _waitlist['body']);
      final details = show['platformSpecifics'] as Map;
      expect(details['channelId'], 'games.invites');
      expect(details['tag'], 'game:g1');
      final actions = (details['actions'] as List).cast<Map>();
      expect(actions.map((a) => a['id']), ['CANCEL_PLACE']);
    });

    test(
      'background: a push with a notification block is not drawn twice',
      () async {
        await drawBackgroundPush(
          const RemoteMessage(
            data: _waitlist,
            notification: RemoteNotification(title: 'x'),
          ),
        );
        expect(calls.where((c) => c.method == 'show'), isEmpty);
      },
    );

    test('foreground: a data-only push is drawn; the pop-up de-dup still '
        'applies', () async {
      final presence = PushPresence.instance;
      final seen = <ForegroundPush>[];
      final sub = presence.foregroundPushes.listen(seen.add);
      addTearDown(sub.cancel);

      final service = PushNotificationService.forTest();
      await service.onForegroundMessage(const RemoteMessage(data: _waitlist));
      await pumpEventQueue();
      expect(calls.where((c) => c.method == 'show'), hasLength(1));
      expect(
        (shown()['platformSpecifics'] as Map)['channelId'],
        'games.invites',
      );
      expect(seen.single.alerted, isTrue);
      expect(seen.single.dedupeKey, 'd1');

      calls.clear();
      seen.clear();
      presence.inAppBannerShows = true;
      addTearDown(() => presence.inAppBannerShows = false);
      await service.onForegroundMessage(const RemoteMessage(data: _waitlist));
      await pumpEventQueue();
      expect(
        calls.where((c) => c.method == 'show'),
        isEmpty,
        reason: 'the pop-up shows it instead',
      );
      expect(seen.single.alerted, isFalse);
      expect(seen.single.data['title'], _waitlist['title']);
    });
  });
}
