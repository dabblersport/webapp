// KAN-988: every card family on the one row, EN and AR: the avatar with the
// verb, the grouped avatar pair with "See all N people", the removal with the
// organiser's name and reason, the old -> new time and venue changes, a
// reminder with its sport tile, the 09:00 "Are you going?" card with the
// urgent pill, the waitlist-promoted card, an expired CTA, a deleted target,
// mirrored layout and names as entered, and device 12/24-hour times.
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notif_row_support.dart';

DabblerNotificationCard _card(WidgetTester tester, String id) =>
    tester.widget<DabblerNotificationCard>(
      inRow(id, find.byType(DabblerNotificationCard)),
    );

List<String> _actions(WidgetTester tester, String id) =>
    _card(tester, id).actions.map((a) => a.label).toList();

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final ar = locale.languageCode == 'ar';
    final dir = ar ? 'rtl' : 'ltr';

    testWidgets('follow: avatar, actor + verb, Follow back — $dir', (
      tester,
    ) async {
      final (l, _) = await pumpRows(tester, [
        notif(
          'social.followed',
          payload: {
            'actor_display_name': 'Ahmed Hassan',
            'actor_user_id': 'u-ahmed',
            'mutual_count': 3,
          },
        ),
      ], locale: locale);
      final c = _card(tester, 'n1');
      // The name stays as entered in both languages.
      expect(c.actor, 'Ahmed Hassan');
      expect(
        '${c.actor} ${c.verb}',
        l.notif_kind_social_followed('Ahmed Hassan'),
      );
      expect(c.leading, isA<DabblerAvatar>());
      expect(c.unread, isTrue);
      expect(_actions(tester, 'n1'), [l.notif_action_follow_back]);
      expect(c.meta.single.text, l.notif_meta_mutual(3));
      // Mirrored: the leading sits at the start edge (the right in Arabic).
      final row = tester.getRect(
        inRow('n1', find.byType(DabblerNotificationCard)),
      );
      final lead = tester.getRect(inRow('n1', find.byType(DabblerAvatar)));
      expect(
        ar ? row.right - lead.right < 30 : lead.left - row.left < 30,
        isTrue,
      );
    });

    testWidgets('grouped likes: pair, "and N others", people list — $dir', (
      tester,
    ) async {
      final (l, _) = await pumpRows(tester, [
        notif(
          'social.post_liked',
          payload: {
            'actor_display_name': 'Ahmed Hassan',
            'total_count': 3,
            'excerpt': 'Great run at the Corniche',
            'people': [
              {'name': 'Ahmed Hassan'},
              {'name': 'هنا يوسف'},
              {'name': 'Omar Khalil'},
            ],
          },
        ),
      ], locale: locale);
      final c = _card(tester, 'n1');
      expect(c.leading, isA<DabblerNotificationAvatarPair>());
      // EN leads with the actor; the AR template is verb-first, so the group
      // phrase sits inside the line.
      expect(c.actor, contains(l.notif_actor_and_others('Ahmed Hassan', 2)));
      expect('${c.actor} ${c.verb}', contains('Ahmed Hassan'));
      expect(c.excerpt!.label, l.notif_ex_your_post);
      expect(c.people!.toggleLabel, l.notif_people_see_all(3));
      expect(find.text('هنا يوسف'), findsNothing);
      await tester.tap(find.text(l.notif_people_see_all(3)));
      await tester.pump();
      expect(find.text('هنا يوسف'), findsOneWidget);
      expect(find.text(l.notif_people_hide), findsOneWidget);
    });

    testWidgets('removal names the organiser and the reason — $dir', (
      tester,
    ) async {
      final (l, _) = await pumpRows(tester, [
        notif(
          'meetup.removed',
          payload: {
            'title': 'Saturday run',
            'organiser': 'Layla Mansour',
            'reason': 'The line-up is fixed',
          },
        ),
      ], locale: locale);
      final c = _card(tester, 'n1');
      expect(c.sub, contains('Layla Mansour'));
      expect(c.sub, contains('The line-up is fixed'));
      expect(c.sub, isNot(contains('{')));
      expect(l.localeName, startsWith(locale.languageCode));
    });

    testWidgets('time and venue changes draw old -> new — $dir', (
      tester,
    ) async {
      final (l, _) = await pumpRows(tester, [
        notif(
          'game.time_changed',
          payload: {
            'title': 'Thursday 5-a-side',
            'old': 'Thu 8:00 PM',
            'new': 'Thu 9:00 PM',
          },
        ),
        notif(
          'game.venue_changed',
          id: 'n2',
          payload: {
            'title': 'Thursday 5-a-side',
            'old': 'Hudayriyat',
            'new': 'Zayed Sports City',
          },
        ),
      ], locale: locale);
      final time = _card(tester, 'n1').change!;
      expect(
        (time.label, time.from, time.to),
        (l.notif_change_time, 'Thu 8:00 PM', 'Thu 9:00 PM'),
      );
      expect(
        _card(tester, 'n1').sub,
        isNull,
        reason: 'the diff replaces the body',
      );
      final venue = _card(tester, 'n2').change!;
      expect(
        (venue.label, venue.from, venue.to),
        (l.notif_change_venue, 'Hudayriyat', 'Zayed Sports City'),
      );
      expect(
        find.descendant(
          of: inRow('n2', find.byKey(const ValueKey('notif-card-change'))),
          matching: find.text('Zayed Sports City'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reminder rungs: the sport tile, the rung text — $dir', (
      tester,
    ) async {
      await pumpRows(tester, [
        for (final (i, rung) in const [
          (1, 'tomorrow at 8:00 PM'),
          (2, 'today at 8:00 PM'),
          (3, 'in 2 hours'),
          (4, 'in 30 min'),
        ])
          notif(
            'meetup.reminder',
            id: 'r$i',
            payload: {
              'title': 'Saturday run',
              'when': rung,
              'sport_key': 'running',
            },
          ),
      ], locale: locale);
      for (final i in [1, 2, 3, 4]) {
        final c = _card(tester, 'r$i');
        expect(
          c.leading,
          isA<DabblerNotificationSportTile>(),
          reason: 'rung $i',
        );
        expect('${c.actor} ${c.verb}', contains('Saturday run'));
      }
      expect(_card(tester, 'r4').actor, contains('30 min'));
    });

    testWidgets('"Are you going?": Going / Not going, urgent; expired — $dir', (
      tester,
    ) async {
      final soon = DateTime.now().add(const Duration(hours: 5));
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final (l, _) = await pumpRows(tester, [
        notif(
          'meetup.confirm_attendance',
          payload: {
            'title': 'Saturday run',
            'time': '6:30 PM',
            'start_at': soon.toUtc().toIso8601String(),
          },
        ),
        notif(
          'meetup.confirm_attendance',
          id: 'n2',
          payload: {
            'title': 'Saturday run',
            'time': '6:30 PM',
            'start_at': past.toUtc().toIso8601String(),
          },
        ),
      ], locale: locale);
      expect(_actions(tester, 'n1'), [
        l.notif_action_going,
        l.notif_action_not_going,
      ]);
      expect(_card(tester, 'n1').urgent, l.notif_urgent_action);
      expect(_card(tester, 'n1').sub, isNotNull);
      // Started: the CTA is gone, no urgent pill.
      expect(_actions(tester, 'n2'), isEmpty);
      expect(_card(tester, 'n2').urgent, isNull);
    });

    testWidgets('waitlist promoted: Cancel my place; deleted target — $dir', (
      tester,
    ) async {
      final (l, _) = await pumpRows(tester, [
        notif(
          'game.waitlist_promoted',
          payload: {'title': 'Thursday 5-a-side'},
        ),
        notif(
          'game.join_request',
          id: 'n2',
          payload: {
            'actor_display_name': 'Yousef Ali',
            'target_state': 'deleted',
          },
        ),
      ], locale: locale);
      expect(_actions(tester, 'n1'), [l.notif_action_cancel_place]);
      expect(_actions(tester, 'n2'), isEmpty);
      expect(_card(tester, 'n2').result!.text, l.notif_res_gone);
    });

    testWidgets('meta times follow the device 12/24-hour setting — $dir', (
      tester,
    ) async {
      final at = DateTime(2026, 11, 19, 20, 0);
      for (final h24 in [false, true]) {
        await pumpRows(
          tester,
          [
            notif(
              'game.invited',
              payload: {
                'actor_display_name': 'Layla Mansour',
                'start_at': at.toUtc().toIso8601String(),
                'venue_name': 'All Star Sport',
              },
            ),
          ],
          locale: locale,
          use24h: h24,
        );
        final meta = _card(tester, 'n1').meta;
        expect(
          DabblerType.toWesternDigits(meta.first.text).contains('20:00'),
          h24,
          reason: 'h24=$h24',
        );
        expect(meta.last.text, 'All Star Sport');
      }
    });
  }
}
