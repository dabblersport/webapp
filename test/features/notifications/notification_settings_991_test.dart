// KAN-991: the notification settings data path. The repository talks to the
// three KAN-975 RPCs only, with the exact payloads; the controller sends one
// partial patch per change, refuses a security mute before the server would,
// validates quiet hours and restores the previous value on a failed save; the
// time zone is sent once per (user, zone).

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings_keys.dart';
import 'package:dabbler/features/notifications/data/notification_settings_repository_impl.dart';
import 'package:dabbler/features/notifications/data/notification_settings_timezone.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/notification_settings_fakes.dart';

Map<String, dynamic> _row({Map<String, dynamic> extra = const {}}) => {
  'user_id': 'u1',
  'tz': 'Asia/Dubai',
  'quiet_start_min': null,
  'quiet_end_min': null,
  'quiet_hours_enabled': false,
  'push_enabled': true,
  'email_enabled': false,
  'sms_enabled': false,
  'muted_kinds': <String>[],
  'allow_high_priority_override': false,
  'allow_all_override': false,
  'message_preview': 'sender_and_message',
  'reminder_rungs': {
    'going': {'24h': true, '09:00': true, '2h': true, '30m': true},
    'interested': {'24h': true, '09:00': false, '2h': true, '30m': true},
  },
  'category_prefs': {
    'social': {'in_app': true, 'push': false},
    'messages': {'in_app': true, 'push': true},
    'games': {'in_app': true, 'push': true},
    'meetups': {'in_app': true, 'push': true},
    'system': {'in_app': true, 'push': true},
    'booking': {'in_app': true, 'push': true},
  },
  'updated_at': '2026-11-17T05:36:00Z',
  ...extra,
};

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('repository RPC payloads', () {
    late List<(String, Map<String, dynamic>?)> calls;
    late NotificationSettingsRepositoryImpl repo;

    setUp(() {
      calls = <(String, Map<String, dynamic>?)>[];
      repo = NotificationSettingsRepositoryImpl.withRpc((fn, {params}) async {
        calls.add((fn, params));
        return _row();
      });
    });

    test(
      'load calls rpc_get_my_notification_settings with no params',
      () async {
        final s = (await repo.load()).requireValue;
        expect(calls.single, ('rpc_get_my_notification_settings', null));
        expect(
          s.categoryOn(NotifCategoryKey.social, NotifChannel.push),
          isFalse,
        );
        expect(s.rungOn(NotifRung.interested, NotifRung.morning), isFalse);
        expect(s.hasQuietHours, isFalse);
      },
    );

    test('update sends the patch as p_patch', () async {
      await repo.update({
        'category_prefs': {
          'games': {'push': false},
        },
      });
      expect(calls.single.$1, 'rpc_update_my_notification_settings');
      expect(calls.single.$2, {
        'p_patch': {
          'category_prefs': {
            'games': {'push': false},
          },
        },
      });
    });

    test('setTimezone sends p_tz', () async {
      await repo.setTimezone('Europe/London');
      expect(calls.single.$1, 'rpc_set_my_notification_timezone');
      expect(calls.single.$2, {'p_tz': 'Europe/London'});
    });

    test('a row wrapped in a list is read; a non-row is a Failure', () async {
      final wrapped = NotificationSettingsRepositoryImpl.withRpc(
        (fn, {params}) async => [_row()],
      );
      expect((await wrapped.load()).isSuccess, isTrue);
      final broken = NotificationSettingsRepositoryImpl.withRpc(
        (fn, {params}) async => 'nope',
      );
      expect((await broken.load()).isFailure, isTrue);
    });

    test('a server error (22023) is a Failure, never a throw', () async {
      final failing = NotificationSettingsRepositoryImpl.withRpc(
        (fn, {params}) async => throw Exception('22023'),
      );
      expect((await failing.update({'muted_kinds': []})).isFailure, isTrue);
    });
  });

  group('full patch (offline queue)', () {
    test('never sends email, SMS, overrides or tz', () {
      final p = notificationSettingsFullPatch(
        const NotificationSettings(userId: 'u1', emailEnabled: true),
      );
      expect(
        p.keys,
        containsAll(<String>[
          'quiet_hours_enabled',
          'message_preview',
          'reminder_rungs',
          'category_prefs',
          'muted_kinds',
          'push_enabled',
        ]),
      );
      for (final k in [
        'email_enabled',
        'sms_enabled',
        'allow_all_override',
        'allow_high_priority_override',
        'tz',
        'user_id',
      ]) {
        expect(p.containsKey(k), isFalse, reason: k);
      }
      expect(p['quiet_hours_enabled'], isFalse);
      expect(p.containsKey('quiet_start_min'), isFalse);
    });

    test('quiet hours on carries the window', () {
      final p = notificationSettingsFullPatch(
        const NotificationSettings(
          userId: 'u1',
          quietStartMin: 1380,
          quietEndMin: 420,
        ),
      );
      expect(p['quiet_hours_enabled'], isTrue);
      expect(p['quiet_start_min'], 1380);
      expect(p['quiet_end_min'], 420);
    });
  });

  group('controller', () {
    Future<(NotificationSettingsController, FakeNotificationSettingsRepo)>
    build({NotificationSettings? s, bool fail = false}) async {
      final repo = FakeNotificationSettingsRepo(
        s ?? NotificationSettings.defaults('u1'),
        failUpdates: fail,
      );
      final c = NotificationSettingsController(repo);
      await _settle();
      return (c, repo);
    }

    test('a category switch sends only that key', () async {
      final (c, repo) = await build();
      await c.setCategory(NotifCategoryKey.social, NotifChannel.push, false);
      expect(repo.patches.single, {
        'category_prefs': {
          'social': {'push': false},
        },
      });
      expect(
        c.state.settings!.categoryOn(
          NotifCategoryKey.social,
          NotifChannel.push,
        ),
        isFalse,
      );
      expect(
        c.state.settings!.categoryOn(
          NotifCategoryKey.social,
          NotifChannel.inApp,
        ),
        isTrue,
      );
    });

    test('each rung is saved on its own', () async {
      final (c, repo) = await build();
      await c.setRung(NotifRung.interested, NotifRung.morning, false);
      await c.setRung(NotifRung.going, NotifRung.thirtyMinutes, false);
      expect(repo.patches, [
        {
          'reminder_rungs': {
            'interested': {'09:00': false},
          },
        },
        {
          'reminder_rungs': {
            'going': {'30m': false},
          },
        },
      ]);
      final s = c.state.settings!;
      expect(s.rungOn(NotifRung.interested, NotifRung.morning), isFalse);
      expect(s.rungOn(NotifRung.going, NotifRung.thirtyMinutes), isFalse);
      expect(s.rungOn(NotifRung.going, NotifRung.morning), isTrue);
    });

    test('message preview sends sender_only / sender_and_message', () async {
      final (c, repo) = await build();
      expect(c.state.settings!.previewSenderOnly, isFalse);
      await c.setPreviewSenderOnly(true);
      await c.setPreviewSenderOnly(false);
      expect(repo.patches, [
        {'message_preview': 'sender_only'},
        {'message_preview': 'sender_and_message'},
      ]);
    });

    test('quiet hours: equal start and end is invalid and not sent', () async {
      final (c, repo) = await build();
      final out = await c.saveQuietHours(
        enabled: true,
        startMin: 600,
        endMin: 600,
      );
      expect(out, QuietHoursSave.invalid);
      expect(repo.patches, isEmpty);
      expect(c.state.settings!.hasQuietHours, isFalse);
    });

    test('quiet hours: on sends the window, off clears it', () async {
      final (c, repo) = await build();
      expect(
        await c.saveQuietHours(enabled: true, startMin: 0, endMin: 480),
        QuietHoursSave.saved,
      );
      expect(c.state.settings!.quietEndMin, 480);
      await c.saveQuietHours(enabled: false, startMin: 0, endMin: 480);
      expect(repo.patches, [
        {
          'quiet_hours_enabled': true,
          'quiet_start_min': 0,
          'quiet_end_min': 480,
        },
        {'quiet_hours_enabled': false},
      ]);
      expect(c.state.settings!.hasQuietHours, isFalse);
    });

    test('a security kind is never muted; the RPC is not called', () async {
      final (c, repo) = await build();
      expect(notificationKindIsUnmutable('security.new_signin'), isTrue);
      expect(notificationKindIsUnmutable('social.post_liked'), isFalse);
      final ok = await c.setKindsMuted(['security.new_signin'], true);
      expect(ok, isFalse);
      expect(repo.patches, isEmpty);
      expect(c.state.error, kSecurityMuteRefused);
      expect(c.state.settings!.mutedKinds, isEmpty);
    });

    test('mute and unmute replace muted_kinds', () async {
      final (c, repo) = await build();
      await c.setKindsMuted(['social.post_liked'], true);
      await c.setKindsMuted(['social.post_liked'], false);
      expect(repo.patches, [
        {
          'muted_kinds': ['social.post_liked'],
        },
        {'muted_kinds': <String>[]},
      ]);
    });

    test(
      'a failed save restores the previous value and sets an error',
      () async {
        final (c, _) = await build(fail: true);
        await c.setPushEnabled(false);
        expect(c.state.settings!.pushEnabled, isTrue);
        expect(c.state.error, 'boom');
      },
    );
  });

  group('time zone', () {
    test('sent once per user and zone, again when either changes', () async {
      final sent = <String>[];
      String tz = 'Asia/Dubai';
      String? user = 'u1';
      final sync = NotificationSettingsTimezoneSync(
        readTimezone: () async => tz,
        currentUserId: () => user,
        send: (z) async {
          sent.add(z);
          return Ok(NotificationSettings.defaults('u1'));
        },
      );
      expect(await sync.sync(), isTrue);
      expect(await sync.sync(), isFalse);
      tz = 'Europe/London';
      expect(await sync.sync(), isTrue);
      user = 'u2';
      expect(await sync.sync(), isTrue);
      user = null;
      expect(await sync.sync(), isFalse);
      expect(sent, ['Asia/Dubai', 'Europe/London', 'Europe/London']);
    });

    test('a failed send is retried next time', () async {
      var fail = true;
      final sync = NotificationSettingsTimezoneSync(
        readTimezone: () async => 'Asia/Dubai',
        currentUserId: () => 'u1',
        send: (z) async => fail
            ? const Err(Failure(message: 'offline'))
            : Ok(NotificationSettings.defaults('u1')),
      );
      expect(await sync.sync(), isFalse);
      fail = false;
      expect(await sync.sync(), isTrue);
    });
  });
}
