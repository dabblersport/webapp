// KAN-964: the Active card as the Home Feed design's ActivityCard, and the
// three states of a game or meetup (upcoming, live, finished) told apart by
// kicker, tone and action, whatever event the row records. EN and
// AR.
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'active_957_support.dart';
import 'active_fixtures.dart';
import 'home_test_harness.dart';

Finder _card(String id) => find.byKey(ValueKey<String>(id));

Finder _in(String id, Finder f) => find.descendant(of: _card(id), matching: f);

Color? _fill(WidgetTester tester, String id) => tester
    .widget<DabblerActivityCard>(_in(id, find.byType(DabblerActivityCard)))
    .tone
    .surface;

String _mark(WidgetTester tester, String id) => tester
    .widget<DabblerActivityCard>(_in(id, find.byType(DabblerActivityCard)))
    .mark;

String _action(WidgetTester tester, String id) => tester
    .widget<DabblerActivityAction>(_in(id, find.byType(DabblerActivityAction)))
    .label;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final ar = locale.languageCode == 'ar';

    testWidgets('upcoming, live and finished games look different — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            // Live: started an hour ago, ends in an hour.
            activeGame(
              id: 'live',
              type: 'game_started',
              at: activeNow.subtract(const Duration(hours: 1)),
              startAt: activeNow.subtract(const Duration(hours: 1)),
              endAt: activeNow.add(const Duration(hours: 1)),
              live: true,
            ),
            // Upcoming: starts on the 20th.
            activeGame(
              id: 'next',
              at: activeNow.subtract(const Duration(hours: 2)),
            ),
            // Finished: ended this morning.
            activeGame(
              id: 'done',
              type: 'game_ended',
              at: activeNow.subtract(const Duration(hours: 3)),
              startAt: activeNow.subtract(const Duration(hours: 5)),
              endAt: activeNow.subtract(const Duration(hours: 3)),
            ),
          ],
          hasMore: false,
        ),
      );

      // Live: "Happening now" beside the green dot, the success tone and
      // "Join in".
      const live = 'game_started:live';
      expect(_in(live, find.text(l.act_kicker_live)), findsOneWidget);
      expect(
        _in(live, find.byKey(const ValueKey<String>('activity-live-dot'))),
        findsOneWidget,
      );
      expect(_fill(tester, live), DabblerActivityTones.sport.surface);
      expect(_mark(tester, live), 'flash');
      expect(_action(tester, live), l.act_cta_join_in);

      // Upcoming: "New game", no dot, the brand tint, "Join game".
      const next = 'game_created:next';
      expect(_in(next, find.text(l.act_kicker_game_created)), findsOneWidget);
      expect(
        _in(next, find.byKey(const ValueKey<String>('activity-live-dot'))),
        findsNothing,
      );
      expect(_fill(tester, next), DabblerActivityTones.main.surface);
      expect(_mark(tester, next), 'calendar-add');
      expect(_action(tester, next), l.act_cta_join_game);

      // Finished: "Final whistle", the muted sunken ground and "See results".
      const done = 'game_ended:done';
      expect(_in(done, find.text(l.act_kicker_game_ended)), findsOneWidget);
      expect(_fill(tester, done), DabblerActivityTones.ended.surface);
      expect(_mark(tester, done), 'cup');
      expect(_action(tester, done), l.act_cta_see_results);

      // Three different grounds.
      expect(<Color?>{
        _fill(tester, live),
        _fill(tester, next),
        _fill(tester, done),
      }, hasLength(3));
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);

    testWidgets('the state comes from the schedule, not the event — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            // A "created" row of a game that has since ended.
            activeGame(
              id: 'old',
              at: activeNow.subtract(const Duration(days: 3)),
              startAt: activeNow.subtract(const Duration(days: 2)),
              endAt: activeNow.subtract(const Duration(days: 2, hours: -2)),
            ),
            // A cached "live" row whose meetup is over.
            activeGame(
              id: 'm1',
              kind: 'meetup',
              type: 'meetup_started',
              at: activeNow.subtract(const Duration(days: 4)),
              startAt: activeNow.subtract(const Duration(days: 4)),
              endAt: activeNow.subtract(const Duration(days: 4, hours: -1)),
              live: true,
            ),
          ],
          hasMore: false,
        ),
      );
      expect(
        _in('game_created:old', find.text(l.act_kicker_game_ended)),
        findsOneWidget,
      );
      expect(_action(tester, 'game_created:old'), l.act_cta_see_results);
      expect(
        _in('meetup_started:m1', find.text(l.act_kicker_meetup_completed)),
        findsOneWidget,
      );
      expect(_action(tester, 'meetup_started:m1'), l.act_cta_see_recap);
      expect(
        find.byKey(const ValueKey<String>('activity-live-dot')),
        findsNothing,
      );
    }, variant: desktopOnly);

    testWidgets('a game shows once, at its newest event — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(
              id: 'g1',
              type: 'game_ended',
              at: activeNow.subtract(const Duration(hours: 1)),
              startAt: activeNow.subtract(const Duration(hours: 3)),
              endAt: activeNow.subtract(const Duration(hours: 1)),
            ),
            activeGame(
              id: 'g1',
              type: 'game_started',
              at: activeNow.subtract(const Duration(hours: 3)),
              startAt: activeNow.subtract(const Duration(hours: 3)),
              endAt: activeNow.subtract(const Duration(hours: 1)),
            ),
            activeGame(
              id: 'g1',
              at: activeNow.subtract(const Duration(days: 1)),
              startAt: activeNow.subtract(const Duration(hours: 3)),
              endAt: activeNow.subtract(const Duration(hours: 1)),
            ),
          ],
          hasMore: false,
        ),
      );
      expect(find.byType(ActiveEventCard), findsOneWidget);
      expect(_card('game_ended:g1'), findsOneWidget);
      expect(find.text(l.act_kicker_game_ended), findsOneWidget);
    }, variant: desktopOnly);

    testWidgets('game card fields: date tile, title, sub, host, tags — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(at: activeNow.subtract(const Duration(minutes: 12))),
          ],
          hasMore: false,
        ),
      );
      const id = 'game_created:g1';
      final start = DateTime(2026, 11, 20, 19);
      expect(_in(id, find.text(l.act_time_minutes(12))), findsOneWidget);
      final tile = _in(id, find.byKey(const ValueKey('active-date-tile')));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(ActiveEventCard.monthLabel(start)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            DabblerType.toWesternDigits(
              DateFormat.d(l.localeName).format(start),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(_in(id, find.text('Sunday 5-a-side')), findsOneWidget);
      final sub = <String>[
        'Al Wasl Sports Club',
        DateFormat.jm(l.localeName).format(start),
        l.act_by('Omar'),
      ].join(' · ');
      expect(
        _in(id, find.text(DabblerType.toWesternDigits(sub))),
        findsOneWidget,
      );
      // The host's 28 avatar leads the footer.
      final avatar = tester.widget<DabblerAvatar>(
        _in(id, find.byType(DabblerAvatar)),
      );
      expect(avatar.size, DabblerAvatarSize.xs);
      expect(_in(id, find.text(ar ? 'كرة القدم' : 'Football')), findsOneWidget);
      // The kicker pill opens the card at its 18 inset, in reading order.
      final card = tester.getRect(_card(id));
      final pill = tester.getRect(_in(id, find.byType(DabblerActivityKicker)));
      if (ar) {
        expect(card.right - pill.right, moreOrLessEquals(18, epsilon: 0.5));
      } else {
        expect(pill.left - card.left, moreOrLessEquals(18, epsilon: 0.5));
      }
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);

    testWidgets('player and venue cards — $dir', (tester) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activePlayer(at: activeNow),
            activeVenue(at: activeNow.subtract(const Duration(minutes: 5))),
          ],
          hasMore: false,
        ),
      );
      const player = 'player_joined:u1';
      expect(
        _in(player, find.text(l.act_kicker_player_joined)),
        findsOneWidget,
      );
      expect(_in(player, find.text(l.act_welcome('Moataz'))), findsOneWidget);
      expect(
        _in(player, find.text('${l.act_plays('Tennis')} · Abu Dhabi')),
        findsOneWidget,
      );
      final avatar = tester.widget<DabblerAvatar>(
        _in(player, find.byType(DabblerAvatar)),
      );
      expect(avatar.size, DabblerAvatarSize.lg);
      expect(_action(tester, player), l.act_cta_follow);

      const venue = 'venue_added:v1';
      expect(_in(venue, find.text(l.act_kicker_venue_added)), findsOneWidget);
      expect(_in(venue, find.text('JLT Padel Club')), findsOneWidget);
      expect(
        _in(venue, find.text('Jumeirah Lake Towers · Dubai')),
        findsOneWidget,
      );
      expect(_in(venue, find.byType(DabblerAvatar)), findsNothing);
      expect(
        _in(venue, find.byKey(const ValueKey('active-date-tile'))),
        findsNothing,
      );
      expect(_action(tester, venue), l.act_cta_view_venue);
    }, variant: desktopOnly);
  }

  test('every look keeps the design\'s family glyph and watermark', () {
    expect(
      <ActiveLook, (String, String)>{
        for (final k in ActiveLook.values) k: (k.familyIcon, k.mark),
      },
      <ActiveLook, (String, String)>{
        ActiveLook.playerJoined: ('profile-add', 'profile-add'),
        ActiveLook.venueAdded: ('building-4', 'building-4'),
        ActiveLook.gameUpcoming: ('game', 'calendar-add'),
        ActiveLook.gameLive: ('game', 'flash'),
        ActiveLook.gameFinished: ('game', 'cup'),
        ActiveLook.meetupUpcoming: ('people', 'people'),
        ActiveLook.meetupLive: ('people', 'flash'),
        ActiveLook.meetupFinished: ('people', 'medal-star'),
        // KAN-967.
        ActiveLook.trendingSport: ('trend-up', 'trend-up'),
        ActiveLook.trendingHashtag: ('trend-up', 'hashtag'),
        ActiveLook.playerWeek: ('profile-add', 'medal-star'),
        ActiveLook.playerMonth: ('profile-add', 'crown'),
        ActiveLook.venueWeek: ('building-4', 'award'),
        ActiveLook.venueMonth: ('building-4', 'crown'),
        ActiveLook.venueRating: ('building-4', 'star'),
        ActiveLook.venueDay: ('building-4', 'magic-star'),
      },
    );
  });
}
