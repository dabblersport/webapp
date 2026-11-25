// KAN-1046 (NOTIF-2): the Android channel table mirrors notification_channels
// (snapshot in fixtures/, refreshed from the database when KAN-1045's rows
// change), the channels are created inside their groups in the app's
// language, legacy ids are deleted only after, and a push picks its channel
// from data.channel_key first.
import 'dart:convert';
import 'dart:io';

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/notifications/push_contract.dart';
import 'package:dabbler/services/notifications/push_local_display.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('table', () {
    final rows =
        (jsonDecode(
                  File(
                    'test/services/notifications/fixtures/'
                    'notification_channels_snapshot.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();

    test('matches the database snapshot, row for row and in order', () {
      expect(
        [
          for (final c in PushChannelTable.channels)
            [c.key, c.group, c.labelEn, c.labelAr, c.importance],
        ],
        [
          for (final r in rows)
            [
              r['key'],
              r['group_key'],
              r['label_en'],
              r['label_ar'],
              PushImportance.parse(r['android_importance'] as String?),
            ],
        ],
      );
    });

    test('groups are the snapshot groups, in sort order', () {
      final groups = <String>[];
      for (final r in rows) {
        final g = r['group_key'] as String;
        if (!groups.contains(g)) groups.add(g);
      }
      expect(PushChannelTable.groups, groups);
    });

    test('importance parse and sound', () {
      expect(PushImportance.parse('max'), PushImportance.max);
      expect(PushImportance.parse('default'), PushImportance.defaultLevel);
      expect(PushImportance.low.sounds, isFalse);
      expect(PushImportance.min.sounds, isFalse);
      expect(PushImportance.defaultLevel.sounds, isTrue);
    });

    test('every legacy id maps to a table channel', () {
      for (final key in PushChannelTable.legacy.values) {
        expect(PushChannelTable.byKey(key), isNotNull, reason: key);
      }
    });
  });

  group('channel from data', () {
    test('data.channel_key wins over the legacy server id', () {
      expect(
        PushChannels.of({
          'channel_key': 'games.reminders',
          'android_channel_id': 'dabbler_games',
        }, serverChannelId: 'dabbler_games'),
        'games.reminders',
      );
    });

    test('a legacy id without channel_key maps to its channel_key', () {
      expect(
        PushChannels.of({}, serverChannelId: 'dabbler_security'),
        'security.alerts',
      );
      expect(
        PushChannels.of({'android_channel_id': 'dabbler_messages'}),
        'messages.direct',
      );
    });

    test('silent goes quiet; unknown channel_key falls through', () {
      expect(
        PushChannels.of({
          'channel_key': 'games.invites',
          'delivery_mode': 'silent',
        }),
        PushChannels.quiet,
      );
      expect(
        PushChannels.of({'channel_key': 'nope.nope'}),
        PushChannels.fallback,
      );
      expect(
        PushChannels.of({}, serverChannelId: PushChannels.quiet),
        PushChannels.quiet,
      );
    });
  });

  group('creation', () {
    late List<MethodCall> calls;
    List<dynamic>? existing;

    setUp(() {
      calls = [];
      existing = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'getNotificationChannels' => existing,
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    Iterable<Map> args(String method) =>
        calls.where((c) => c.method == method).map((c) => c.arguments as Map);

    test('one group each, every channel in its group, legacy deleted '
        'after', () async {
      final l = lookupAppLocalizations(const Locale('en'));
      await PushLocalDisplay(
        FlutterLocalNotificationsPlugin(),
      ).createChannels(l);

      expect(args('createNotificationChannelGroup').map((g) => g['id']), [
        ...PushChannelTable.groups,
      ]);
      final channels = args('createNotificationChannel').toList();
      expect(channels.map((c) => c['id']), [
        for (final c in PushChannelTable.channels) c.key,
        PushChannels.quiet,
        PushChannels.fallback,
      ]);
      final invites = channels.firstWhere((c) => c['id'] == 'games.invites');
      expect(invites['groupId'], 'games');
      expect(invites['name'], 'Invites & join requests');
      expect(invites['description'], l.notif_channels_group_games);
      expect(invites['playSound'], isTrue);
      final quiet = channels.firstWhere((c) => c['id'] == PushChannels.quiet);
      expect(quiet['groupId'], isNull);
      expect(quiet['playSound'], isFalse);
      expect(quiet['enableVibration'], isFalse);

      final lastCreate = calls.lastIndexWhere(
        (c) => c.method == 'createNotificationChannel',
      );
      final deletes = [
        for (var i = 0; i < calls.length; i++)
          if (calls[i].method == 'deleteNotificationChannel') i,
      ];
      expect(deletes.map((i) => calls[i].arguments), [
        ...PushChannelTable.legacy.keys,
        'default_channel',
      ]);
      expect(deletes.every((i) => i > lastCreate), isTrue);
    });

    test('Arabic names in Arabic; background keeps existing names', () async {
      final ar = lookupAppLocalizations(const Locale('ar'));
      await PushLocalDisplay(
        FlutterLocalNotificationsPlugin(),
      ).createChannels(ar);
      final invites = args(
        'createNotificationChannel',
      ).firstWhere((c) => c['id'] == 'games.invites');
      expect(invites['name'], 'الدعوات وطلبات الانضمام');

      calls.clear();
      existing = [
        <String, Object?>{
          'id': 'games.invites',
          'name': 'x',
          'importance': 4,
          'showBadge': true,
          'playSound': true,
          'enableLights': false,
          'enableVibration': true,
          'ledColor': 0,
        },
      ];
      await PushLocalDisplay(
        FlutterLocalNotificationsPlugin(),
      ).createChannels(ar, onlyMissing: true);
      final ids = args('createNotificationChannel').map((c) => c['id']);
      expect(ids, isNot(contains('games.invites')));
      expect(ids, contains('games.reminders'));
    });

    test('a push is shown on its channel_key channel', () async {
      final l = lookupAppLocalizations(const Locale('en'));
      await PushLocalDisplay(FlutterLocalNotificationsPlugin()).show(
        data: const {
          'channel_key': 'messages.threads',
          'android_channel_id': 'dabbler_messages',
        },
        title: 'T',
        body: 'B',
        channelId: 'dabbler_messages',
        l10n: l,
      );
      final show = calls.lastWhere((c) => c.method == 'show').arguments as Map;
      final details = show['platformSpecifics'] as Map;
      expect(details['channelId'], 'messages.threads');
      expect(details['channelName'], 'Game & meet-up chats');
    });
  });
}
