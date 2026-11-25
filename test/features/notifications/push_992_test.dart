// KAN-992 (W1-F6): push on device — channel selection, iOS categories and
// their actions, action routing, the open-chat foreground rule, the badge and
// the tapped push's route or target state.
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_target_states.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/notifications/push_action_runner.dart';
import 'package:dabbler/services/notifications/push_contract.dart';
import 'package:dabbler/services/notifications/push_local_display.dart';
import 'package:dabbler/services/notifications/push_notification_service_mobile.dart';
import 'package:dabbler/services/notifications/push_presence.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('channels', () {
    test('quiet is low with no sound; channel importance from the table', () {
      expect(PushChannels.quietChannel.importance, PushImportance.low);
      expect(PushChannels.quietChannel.sound, isFalse);
      expect(
        PushChannelTable.byKey('games.reminders')!.importance,
        PushImportance.max,
      );
      expect(
        PushChannelTable.byKey('social.reactions')!.importance,
        PushImportance.defaultLevel,
        reason: 'social never breaks through (I-3)',
      );
    });

    test('the server channel wins; silent goes quiet; else by category', () {
      expect(
        PushChannels.of({
          'kind_key': 'game.invited',
        }, serverChannelId: 'security.alerts'),
        'security.alerts',
      );
      expect(
        PushChannels.of({
          'kind_key': 'game.invited',
          'delivery_mode': 'silent',
        }),
        PushChannels.quiet,
      );
      expect(
        PushChannels.of({'kind_key': 'social.post_liked'}),
        'social.reactions',
      );
      expect(
        PushChannels.of({'kind_key': 'message.received'}),
        'messages.direct',
      );
      expect(
        PushChannels.of({'kind_key': 'activity.checkin_open'}),
        'activities.checkin',
      );
      expect(
        PushChannels.of({'kind_key': 'security.new_signin'}),
        'security.alerts',
      );
      expect(PushChannels.of({'kind_key': 'nope'}), PushChannels.fallback);
      expect(
        PushChannels.of({}, serverChannelId: 'default_channel'),
        PushChannels.fallback,
        reason: 'an unknown channel id is ignored',
      );
    });
  });

  group('categories', () {
    test('server category, else by kind; their actions', () {
      expect(
        PushCategories.of({'category': 'DABBLER_RSVP'}),
        PushCategories.rsvp,
      );
      expect(
        PushCategories.of({'kind_key': 'message.received'}),
        PushCategories.message,
      );
      expect(
        PushCategories.of({'kind_key': 'meetup.confirm_attendance'}),
        PushCategories.rsvp,
      );
      expect(
        PushCategories.of({'kind_key': 'game.waitlist_promoted'}),
        PushCategories.waitlist,
      );
      expect(
        PushCategories.of({'kind_key': 'security.password_changed'}),
        PushCategories.security,
      );
      expect(
        PushCategories.of({'kind_key': 'social.post_liked'}),
        PushCategories.fallback,
      );

      expect(PushCategories.actionsOf({'category': PushCategories.message}), [
        PushActionId.reply,
        PushActionId.markRead,
      ]);
      expect(PushCategories.actionsOf({'category': PushCategories.rsvp}), [
        PushActionId.going,
        PushActionId.notGoing,
      ]);
      expect(PushCategories.actionsOf({'category': PushCategories.waitlist}), [
        PushActionId.cancelPlace,
      ]);
      expect(
        PushCategories.actionsOf({'category': PushCategories.security}),
        isEmpty,
      );
      expect(PushCategories.actionsOf({}), [PushActionId.markRead]);
    });

    test('security hides its preview (G-08)', () {
      expect(
        PushCategories.hidesPreview({'kind_key': 'security.new_signin'}),
        isTrue,
      );
      expect(
        PushCategories.hidesPreview({'kind_key': 'game.invited'}),
        isFalse,
      );
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      test('${locale.languageCode}: every action has a localized label', () {
        final l = lookupAppLocalizations(locale);
        for (final a in PushActionId.values) {
          expect(pushActionLabel(a, l), isNotEmpty);
        }
        expect(pushActionLabel(PushActionId.going, l), l.notif_action_going);
        final reply = androidActionFor(PushActionId.reply, l);
        expect(reply.id, 'REPLY');
        expect(reply.inputs, hasLength(1), reason: 'Reply takes text');
        expect(androidActionFor(PushActionId.markRead, l).inputs, isEmpty);
      });
    }
  });

  group('foreground', () {
    test('the open chat from the router location', () {
      expect(
        OpenChat.fromLocation('/messaging/thread/c1').conversationId,
        'c1',
      );
      expect(OpenChat.fromLocation('/messaging/game/g1').gameId, 'g1');
      expect(OpenChat.fromLocation('/meetups/m1/chat').meetupId, 'm1');
      expect(OpenChat.fromLocation('/home').isNone, isTrue);
      expect(OpenChat.fromLocation('/meetups/m1').isNone, isTrue);
    });

    test(
      'no alert for a message of the chat on screen; another chat alerts',
      () {
        const open = OpenChat(conversationId: 'c1');
        Map<String, dynamic> msg(String conv) => {
          'kind_key': 'message.received',
          'category': PushCategories.message,
          'conversation_id': conv,
        };
        expect(suppressForegroundAlert(msg('c1'), openChat: open), isTrue);
        expect(suppressForegroundAlert(msg('c2'), openChat: open), isFalse);
        expect(
          suppressForegroundAlert({
            'kind_key': 'game.invited',
            'conversation_id': 'c1',
          }, openChat: open),
          isFalse,
          reason: 'only messages',
        );
        expect(
          suppressForegroundAlert(
            msg('c2'),
            openChat: open,
            inAppBannerShows: true,
          ),
          isTrue,
          reason: 'the in-app banner (W1-F7) takes over',
        );
        expect(
          suppressForegroundAlert({
            'kind_key': 'message.received',
            'game_id': 'g1',
          }, openChat: const OpenChat(gameId: 'g1')),
          isTrue,
        );
      },
    );

    test('the de-dup key shared with the banner', () {
      expect(pushDedupeKey({'dedupe_key': 'k', 'notification_id': 'n'}), 'k');
      expect(pushDedupeKey({'notification_id': 'n'}), 'n');
      expect(pushDedupeKey({}), isNull);
    });
  });

  test('a foreground push reaches the pop-up with its keys, title and body '
      '(KAN-993); with the pop-up mounted it does not alert', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final presence = PushPresence.instance;
    final seen = <ForegroundPush>[];
    final sub = presence.foregroundPushes.listen(seen.add);
    addTearDown(sub.cancel);
    presence.inAppBannerShows = true;
    addTearDown(() => presence.inAppBannerShows = false);
    await PushNotificationService.forTest().onForegroundMessage(
      const RemoteMessage(
        data: {
          'kind_key': 'game.invited',
          'notification_id': 'n1',
          'dedupe_key': 'd1',
        },
        notification: RemoteNotification(
          title: 'Omar invited you',
          body: 'Fri 7pm',
        ),
      ),
    );
    await pumpEventQueue();
    expect(seen, hasLength(1));
    expect(seen.single.alerted, isFalse);
    expect(seen.single.dedupeKey, 'd1');
    expect(seen.single.data['notification_id'], 'n1');
    expect(seen.single.data['title'], 'Omar invited you');
    expect(seen.single.data['body'], 'Fri 7pm');
  });

  test('badge: data, APNs or Android count; never negative', () {
    expect(pushBadge({'badge': '36'}), 36);
    expect(pushBadge({}, appleBadge: '4'), 4);
    expect(pushBadge({}, androidCount: 2), 2);
    expect(pushBadge({'badge': -3}), 0);
    expect(pushBadge({}), isNull);
  });

  group('tap target', () {
    final now = DateTime(2026, 11, 17, 12);

    test('the server route, else the registry route for the kind', () {
      expect(pushTarget({'action_route': '/x'}, now: now).route, '/x');
      expect(
        pushTarget({
          'kind_key': 'game.invited',
          'entity_type': 'game',
          'entity_id': 'g1',
        }, now: now).route,
        RoutePaths.gameDetail('g1'),
      );
      expect(
        pushTarget({
          'kind_key': 'meetup.invited',
          'meetup_id': 'm1',
        }, now: now).route,
        RoutePaths.meetupDetail('m1'),
      );
      expect(
        pushTarget({'kind_key': 'meetup.invited'}, now: now).route,
        RoutePaths.meetups,
      );
      expect(
        pushTarget({'kind_key': 'message.received'}, now: now).opens,
        isFalse,
      );
    });

    test('a gone target shows its state instead', () {
      expect(
        pushTarget({
          'kind_key': 'game.cancelled',
          'entity_id': 'g',
        }, now: now).state,
        NotifTargetState.cancelled,
      );
      expect(
        pushTarget({
          'kind_key': 'game.updated',
          'entity_id': 'g',
        }, now: now).state,
        NotifTargetState.cancelled,
      );
      expect(
        pushTarget({
          'kind_key': 'game.invited',
          'expires_at': '2026-11-17T08:00:00',
        }, now: now).state,
        NotifTargetState.expired,
      );
      expect(
        pushTarget({
          'kind_key': 'game.invited',
          'target_state': 'deleted',
        }, now: now).showsSheet,
        isTrue,
      );
    });

    test('the service routes a tap or hands the state to the app', () {
      final s = PushNotificationService.forTest();
      final routes = <String>[];
      final states = <NotifTargetState>[];
      s.onNotificationTap = routes.add;
      s.onTargetUnavailable = states.add;
      s.routeTap({'action_route': '/sports/games/g1'});
      s.routeTap({'kind_key': 'meetup.cancelled', 'entity_id': 'm1'});
      expect(routes, ['/sports/games/g1']);
      expect(states, [NotifTargetState.cancelled]);
    });
  });

  group('actions', () {
    late List<String> calls;
    late bool confirm;
    late bool rpcFails;

    PushActionRunner runner() => PushActionRunner(
      markRead: (id) async => calls.add('read:$id'),
      reply: (c, t) async => calls.add('reply:$c:$t'),
      rpc: (fn, params) async {
        if (rpcFails) throw Exception('not live');
        calls.add('rpc:$fn:$params');
        return null;
      },
      confirmCancelPlace: (_) async {
        calls.add('confirm');
        return confirm;
      },
      openRoute: (r) => calls.add('open:$r'),
    );

    setUp(() {
      calls = [];
      confirm = true;
      rpcFails = false;
    });

    test('Mark as read marks the row', () async {
      expect(
        await runner().run(
          const PushActionEvent(PushActionId.markRead, {
            'notification_id': 'n1',
          }),
        ),
        PushActionOutcome.done,
      );
      expect(calls, ['read:n1']);
    });

    test(
      'Reply sends the text, then marks read; no text does nothing',
      () async {
        final r = runner();
        expect(
          await r.run(
            const PushActionEvent(PushActionId.reply, {
              'conversation_id': 'c1',
              'notification_id': 'n1',
            }, text: ' On my way '),
          ),
          PushActionOutcome.done,
        );
        expect(calls, ['reply:c1:On my way', 'read:n1']);
        expect(
          await r.run(
            const PushActionEvent(PushActionId.reply, {
              'conversation_id': 'c1',
            }),
          ),
          PushActionOutcome.skipped,
        );
      },
    );

    test('Going / Not going answer the 09:00 card (KAN-983)', () async {
      final r = runner();
      await r.run(
        const PushActionEvent(PushActionId.going, {
          'entity_type': 'meetup',
          'entity_id': 'm1',
        }),
      );
      await r.run(
        const PushActionEvent(PushActionId.notGoing, {'meetup_id': 'm2'}),
      );
      expect(calls, [
        'rpc:${SupabaseConfig.rpcAnswerMeetupAttendance}:'
            '{p_meetup_id: m1, p_answer: going}',
        'rpc:${SupabaseConfig.rpcAnswerMeetupAttendance}:'
            '{p_meetup_id: m2, p_answer: not_going}',
      ]);
    });

    test(
      'Cancel my place asks first, then frees the place (KAN-982)',
      () async {
        const event = PushActionEvent(PushActionId.cancelPlace, {
          'entity_type': 'game',
          'entity_id': 'g1',
        });
        confirm = false;
        expect(await runner().run(event), PushActionOutcome.cancelled);
        expect(calls, ['confirm']);

        calls.clear();
        confirm = true;
        expect(await runner().run(event), PushActionOutcome.done);
        expect(
          calls.last,
          'rpc:${SupabaseConfig.rpcCancelWaitlistPlace}:{p_game_id: g1}',
        );

        calls.clear();
        rpcFails = true;
        expect(await runner().run(event), PushActionOutcome.opened);
        expect(calls.last, 'open:${RoutePaths.gameDetail('g1')}');
      },
    );

    test('the iOS bridge payload parses into an action', () {
      final e = PushPresence.parseNativeAction({
        'action': 'REPLY',
        'data': {'conversation_id': 'c1'},
        'text': 'hi',
      })!;
      expect(e.action, PushActionId.reply);
      expect(e.data['conversation_id'], 'c1');
      expect(e.text, 'hi');
      expect(PushPresence.parseNativeAction({'action': 'NOPE'}), isNull);
    });
  });
}
