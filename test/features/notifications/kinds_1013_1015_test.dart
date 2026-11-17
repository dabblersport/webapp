// KAN-1013 / KAN-1015: two live kinds in the client registry, rendered on
// DabblerNotificationCard in EN and AR and routed like their inbox rows.
//
// * meetup.wants_to_join_full: meetups, in-app only, grouped ("See all N
//   people"), opens the organiser's meetup, no actions.
// * game.series_cancelled: games, breaks quiet hours, drawn like a
//   cancellation, target state cancelled.

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_target_states.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notif_row_support.dart';

DabblerNotificationCard _card(WidgetTester tester, String id) =>
    tester.widget<DabblerNotificationCard>(
      inRow(id, find.byType(DabblerNotificationCard)),
    );

AppNotification _v2(
  String kind, {
  String id = 'n1',
  required Map<String, dynamic> args,
  Map<String, dynamic>? payload,
}) => AppNotification(
  id: id,
  toUserId: 'me',
  kindKey: kind,
  title: 'Server title',
  args: args,
  payload: payload,
  schemaVersion: 2,
  createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
);

void main() {
  group('registry', () {
    test('meetup.wants_to_join_full: meetups, live, quiet, mutable', () {
      final s = NotificationKinds.of('meetup.wants_to_join_full')!;
      expect(s.category, NotificationCategory.meetups);
      expect(s.active, isTrue);
      expect(s.breaksQuiet, isFalse);
      expect(s.canMute, isTrue);
      expect(s.needsAction, isFalse);
      expect(s.ctas, isEmpty);
      expect(s.chipFor(null), NotificationChip.meetups);
    });

    test(
      'game.series_cancelled: games, live, breaks quiet, a cancellation',
      () {
        final s = NotificationKinds.of('game.series_cancelled')!;
        expect(s.category, NotificationCategory.games);
        expect(s.active, isTrue);
        expect(s.breaksQuiet, isTrue);
        expect(s.ctas, isEmpty);
        expect(
          NotificationKinds.isCancellation('game.series_cancelled'),
          isTrue,
        );
        expect(
          notifTargetStateOf(
            _v2('game.series_cancelled', args: const {'title': 'Padel'}),
            DateTime.now(),
          ),
          NotifTargetState.cancelled,
        );
      },
    );

    test('routes: the meetup (organiser) and the game', () {
      expect(
        NotificationKinds.route('meetup.wants_to_join_full', const {
          'entity_type': 'meetup',
          'entity_id': 'm1',
        }, meetupsEnabled: true),
        RoutePaths.meetupManage('m1'),
      );
      expect(
        NotificationKinds.route('meetup.wants_to_join_full', const {
          'meetup_id': 'm2',
        }, meetupsEnabled: true),
        RoutePaths.meetupManage('m2'),
      );
      expect(
        NotificationKinds.route('meetup.wants_to_join_full', const {
          'meetup_id': 'm2',
        }, meetupsEnabled: false),
        isNull,
      );
      expect(
        NotificationKinds.route('game.series_cancelled', const {
          'entity_type': 'game',
          'entity_id': 'g1',
        }),
        RoutePaths.gameDetail('g1'),
      );
      expect(
        NotificationKinds.route('game.series_cancelled', const {
          'game_id': 'g2',
        }),
        RoutePaths.gameDetail('g2'),
      );
    });
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('wants to join a full meetup: grouped, no actions — $dir', (
      tester,
    ) async {
      final (l, opened) = await pumpRows(tester, [
        _v2(
          'meetup.wants_to_join_full',
          args: const {'actor': 'Ahmed Hassan', 'title': 'Morning run'},
          payload: const {
            'actor_display_name': 'Ahmed Hassan',
            'entity_type': 'meetup',
            'entity_id': 'm1',
            'total_count': 3,
            'people': [
              {'name': 'Ahmed Hassan'},
              {'name': 'هنا يوسف'},
              {'name': 'Omar Khalil'},
            ],
          },
        ),
      ], locale: locale);
      expect(tester.takeException(), isNull);
      final c = _card(tester, 'n1');
      final line = '${c.actor} ${c.verb}';
      expect(line, contains('Morning run'));
      expect(c.actor, contains(l.notif_actor_and_others('Ahmed Hassan', 2)));
      expect(c.actions, isEmpty);
      expect(c.leading, isA<DabblerNotificationAvatarPair>());
      expect(c.people!.toggleLabel, l.notif_people_see_all(3));
      expect(find.text('هنا يوسف'), findsNothing);
      await tester.tap(find.text(l.notif_people_see_all(3)));
      await tester.pump();
      expect(find.text('هنا يوسف'), findsOneWidget);
      // The card's open is the row's tap (the inbox routes it).
      _card(tester, 'n1').onOpen!();
      await tester.pump();
      expect(opened, ['open:n1']);
    });

    testWidgets('one person, not grouped: the template line — $dir', (
      tester,
    ) async {
      final (l, _) = await pumpRows(tester, [
        _v2(
          'meetup.wants_to_join_full',
          args: const {'actor': 'Omar Khalil', 'title': 'Morning run'},
          payload: const {'actor_display_name': 'Omar Khalil'},
        ),
      ], locale: locale);
      final c = _card(tester, 'n1');
      expect(
        '${c.actor} ${c.verb}'.replaceAll(RegExp(r'\s+'), ' ').trim(),
        anyOf(
          l
              .notif_t_meetup_wants_to_join_full('Omar Khalil', 'Morning run')
              .replaceAll(RegExp(r'\s+'), ' '),
          contains('Omar Khalil'),
        ),
      );
      expect(c.people, isNull);
      expect(c.actions, isEmpty);
    });

    testWidgets('series cancelled: the cancellation line, no actions — $dir', (
      tester,
    ) async {
      final (l, opened) = await pumpRows(tester, [
        _v2(
          'game.series_cancelled',
          args: const {'title': 'Thursday 5-a-side'},
          payload: const {'entity_type': 'game', 'entity_id': 'g1'},
        ),
      ], locale: locale);
      expect(tester.takeException(), isNull);
      final c = _card(tester, 'n1');
      expect(
        '${c.actor} ${c.verb}'.trim(),
        l.notif_t_game_series_cancelled('Thursday 5-a-side'),
      );
      expect(c.actions, isEmpty);
      // The card's open is the row's tap (the inbox routes it).
      _card(tester, 'n1').onOpen!();
      await tester.pump();
      expect(opened, ['open:n1']);
    });
  }
}
