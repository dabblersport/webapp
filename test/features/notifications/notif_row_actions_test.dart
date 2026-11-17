// KAN-988: the row's inline actions run through the handler and show every
// state, EN and AR: idle, pending, the result, failed with Retry, handled on
// another device and not available yet; the ⋯ menu marks read / unread,
// mutes the kind (with Undo; hidden for security kinds) and mutes a
// conversation on a message.
import 'dart:async';

import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_actions.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'notif_row_support.dart';

DabblerNotificationCard _card(WidgetTester tester, [String id = 'n1']) =>
    tester.widget<DabblerNotificationCard>(
      inRow(id, find.byType(DabblerNotificationCard)),
    );

final _join = notif(
  'game.join_request',
  payload: {
    'actor_display_name': 'Yousef Ali',
    'actor_user_id': 'u-yousef',
    'entity_id': 'g1',
  },
);

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('approve: pending, then the result — $dir', (tester) async {
      final h = FakeNotifActions()..gate = Completer<void>();
      final (l, _) = await pumpRows(
        tester,
        [_join],
        locale: locale,
        handler: h,
      );
      expect(_card(tester).actions.map((a) => a.label), [
        l.notif_action_approve,
        l.notif_action_decline,
      ]);
      await tester.tap(find.text(l.notif_action_approve));
      await tester.pump();
      expect(h.calls, ['run:approve:n1']);
      expect(_card(tester).pending, l.notif_pending_sending);
      expect(_card(tester).actions, isEmpty);
      h.gate!.complete();
      await tester.pump();
      await tester.pump();
      final r = _card(tester).result!;
      expect(r.text, l.notif_res_approved('Yousef Ali'));
      expect(r.tone, DabblerNotificationTone.ok);
      expect(_card(tester).pending, isNull);
      expect(_card(tester).unread, isFalse, reason: 'acting reads the row');
    });

    testWidgets('decline shows Declining…, then Request declined — $dir', (
      tester,
    ) async {
      final h = FakeNotifActions()..gate = Completer<void>();
      final (l, _) = await pumpRows(
        tester,
        [_join],
        locale: locale,
        handler: h,
      );
      await tester.tap(find.text(l.notif_action_decline));
      await tester.pump();
      expect(_card(tester).pending, l.notif_pending_declining);
      h.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(_card(tester).result!.text, l.notif_res_request_declined);
    });

    testWidgets('failure offers Retry; Retry runs again — $dir', (
      tester,
    ) async {
      final h = FakeNotifActions(
        outcome: const NotifActionOutcome(NotifActionStatus.failed, 'offline'),
      );
      final (l, _) = await pumpRows(
        tester,
        [_join],
        locale: locale,
        handler: h,
      );
      await tester.tap(find.text(l.notif_action_approve));
      await tester.pumpAndSettle();
      final r = _card(tester).result!;
      expect(r.text, l.notif_res_failed);
      expect(r.tone, DabblerNotificationTone.err);
      expect(r.linkLabel, l.notif_res_retry);
      h.outcome = NotifActionOutcome.success;
      await tester.tap(find.text(l.notif_res_retry));
      await tester.pumpAndSettle();
      expect(h.calls, ['run:approve:n1', 'run:approve:n1']);
      expect(_card(tester).result!.text, l.notif_res_approved('Yousef Ali'));
    });

    testWidgets('handled elsewhere, and not available yet — $dir', (
      tester,
    ) async {
      final h = FakeNotifActions(outcome: NotifActionOutcome.already);
      final (l, _) = await pumpRows(
        tester,
        [
          _join,
          notif(
            'game.waitlist_promoted',
            id: 'n2',
            payload: {'title': 'Thursday'},
          ),
        ],
        locale: locale,
        handler: h,
      );
      await tester.tap(find.text(l.notif_action_approve));
      await tester.pumpAndSettle();
      expect(_card(tester).result!.text, l.notif_res_elsewhere);
      expect(_card(tester).result!.tone, DabblerNotificationTone.info);
      h.outcome = NotifActionOutcome.unavailable;
      await tester.tap(find.text(l.notif_action_cancel_place));
      await tester.pumpAndSettle();
      expect(_card(tester, 'n2').result!.text, l.notif_res_unavailable);
    });

    testWidgets('follow back, going and not going results — $dir', (
      tester,
    ) async {
      final h = FakeNotifActions();
      final soon = DateTime.now().add(const Duration(hours: 4));
      final (l, _) = await pumpRows(
        tester,
        [
          notif(
            'social.followed',
            payload: {
              'actor_display_name': 'Ahmed Hassan',
              'actor_user_id': 'u1',
            },
          ),
          for (final id in ['g', 'ng'])
            notif(
              'meetup.confirm_attendance',
              id: id,
              payload: {
                'title': 'Run',
                'time': '6:30 PM',
                'entity_id': 'm1',
                'start_at': soon.toUtc().toIso8601String(),
              },
            ),
        ],
        locale: locale,
        handler: h,
      );
      await tester.tap(find.text(l.notif_action_follow_back));
      await tester.tap(
        find.descendant(
          of: rowOf('g'),
          matching: find.text(l.notif_action_going),
        ),
      );
      await tester.tap(
        find.descendant(
          of: rowOf('ng'),
          matching: find.text(l.notif_action_not_going),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.calls, ['run:followBack:n1', 'run:going:g', 'run:notGoing:ng']);
      expect(_card(tester).result!.text, l.notif_res_following('Ahmed Hassan'));
      expect(_card(tester, 'g').result!.text, l.notif_res_going);
      expect(_card(tester, 'ng').result!.text, l.notif_res_not_going);
    });

    testWidgets('a "view" CTA opens the row, it does not run — $dir', (
      tester,
    ) async {
      final h = FakeNotifActions();
      final (l, opened) = await pumpRows(
        tester,
        [
          notif('game.invited', payload: {'actor_display_name': 'Layla'}),
        ],
        locale: locale,
        handler: h,
      );
      await tester.tap(find.text(l.notif_action_view));
      await tester.pump();
      expect(opened, ['open:n1']);
      expect(h.calls, isEmpty);
    });

    testWidgets('menu: read / unread, mute the kind with Undo — $dir', (
      tester,
    ) async {
      final h = FakeNotifActions();
      final (l, _) = await pumpRows(
        tester,
        [_join],
        locale: locale,
        handler: h,
      );
      await tester.tap(find.byKey(const ValueKey('notif-card-menu')));
      await tester.pump();
      expect(_card(tester).menu!.map((m) => m.label), [
        l.notif_menu_mark_read,
        l.notif_menu_mute_kind,
      ]);
      await tester.tap(find.text(l.notif_menu_mark_read));
      await tester.pump();
      expect(_card(tester).unread, isFalse);
      expect(_card(tester).menu, isNull);
      await tester.tap(find.byKey(const ValueKey('notif-card-menu')));
      await tester.pump();
      expect(_card(tester).menu!.first.label, l.notif_menu_mark_unread);
      await tester.tap(find.text(l.notif_menu_mute_kind));
      await tester.pump();
      expect(_card(tester).result!.text, l.notif_res_muted);
      expect(_card(tester).actions, isEmpty);
      await tester.tap(find.text(l.notif_res_undo));
      await tester.pump();
      expect(_card(tester).result, isNull);
      expect(h.calls, [
        'read:true',
        'muteKind:game.join_request:true',
        'muteKind:game.join_request:false',
      ]);
    });

    testWidgets('security: no mute item; a message: mute conversation — $dir', (
      tester,
    ) async {
      final h = FakeNotifActions();
      final (l, _) = await pumpRows(
        tester,
        [
          notif('security.new_signin'),
          notif(
            'message.received',
            id: 'n2',
            payload: {'conversation_id': 'c9'},
          ),
        ],
        locale: locale,
        handler: h,
      );
      await tester.tap(
        find.descendant(
          of: rowOf('n1'),
          matching: find.byKey(const ValueKey('notif-card-menu')),
        ),
      );
      await tester.pump();
      expect(
        _card(tester).menu!.map((m) => m.label),
        isNot(contains(l.notif_menu_mute_kind)),
      );
      await tester.tap(
        find.descendant(
          of: rowOf('n2'),
          matching: find.byKey(const ValueKey('notif-card-menu')),
        ),
      );
      await tester.pump();
      expect(
        _card(tester, 'n2').menu!.map((m) => m.label),
        contains(l.notif_menu_mute_conversation),
      );
      await tester.tap(find.text(l.notif_menu_mute_conversation));
      await tester.pump();
      expect(h.calls, ['muteConversation:c9:true']);
      expect(_card(tester, 'n2').result!.text, l.notif_res_conversation_muted);
    });
  }

  group('handler', () {
    test('view / respond / see circle open the row; the rest run inline', () {
      for (final a in NotificationActionId.values) {
        final opens =
            a == NotificationActionId.view ||
            a == NotificationActionId.respond ||
            a == NotificationActionId.seeCircle;
        expect(notifActionRunsInline(a), !opens, reason: a.name);
      }
    });

    test('server "already" codes and unique violations read as handled', () {
      for (final code in SupabaseNotifActionHandler.alreadyCodes) {
        expect(
          SupabaseNotifActionHandler.isAlreadyHandledError(
            PostgrestException(message: code),
          ),
          isTrue,
          reason: code,
        );
      }
      expect(
        SupabaseNotifActionHandler.isAlreadyHandledError(
          const PostgrestException(message: 'dup', code: '23505'),
        ),
        isTrue,
      );
      expect(
        SupabaseNotifActionHandler.isAlreadyHandledError(
          const PostgrestException(message: 'network'),
        ),
        isFalse,
      );
      expect(
        SupabaseNotifActionHandler.isAlreadyHandledError(StateError('x')),
        isFalse,
      );
    });

    test('the payload ids: entity, actor (direct, else first follower)', () {
      expect(notifEntityId(notif('x', payload: {'entity_id': 'e1'})), 'e1');
      expect(
        notifEntityId(notif('x', payload: {'meetup_id': 'm1'}), 'meetup_id'),
        'm1',
      );
      expect(
        notifActorUserId(notif('x', payload: {'actor_user_id': 'a'})),
        'a',
      );
      expect(
        notifActorUserId(
          notif(
            'x',
            payload: {
              'follower_user_ids': ['f1', 'f2'],
            },
          ),
        ),
        'f1',
      );
      expect(notifActorUserId(notif('x')), isNull);
    });
  }, skip: false);
}
