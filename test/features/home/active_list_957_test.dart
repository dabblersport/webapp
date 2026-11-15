// KAN-957: the Active list — date groups, the card variants (actor, listing
// with a date tile, venue tile, Live badge, sports and city) and the loading,
// empty and error states, in EN and AR.
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/features/home/presentation/widgets/active_feed_list.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final ar = locale.languageCode == 'ar';

    testWidgets('groups by day: Today, Yesterday, then the date — $dir', (
      tester,
    ) async {
      final older = activeNow.subtract(const Duration(days: 4));
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(id: 'a', at: activeNow),
            activeVenue(
              id: 'b',
              at: activeNow.subtract(const Duration(hours: 2)),
            ),
            activeGame(
              id: 'c',
              at: activeNow.subtract(const Duration(days: 1)),
            ),
            activePlayer(id: 'd', at: older),
          ],
          hasMore: false,
        ),
      );
      final headers = tester
          .widgetList<ActiveGroupHeader>(find.byType(ActiveGroupHeader))
          .map((h) => h.label)
          .toList();
      expect(headers, <String>[
        l.act_group_today,
        l.act_group_yesterday,
        DateFormat.MMMEd(l.localeName).format(older),
      ]);
      // A header sits above its own items.
      final y = tester.getTopLeft(find.text(l.act_group_yesterday)).dy;
      expect(tester.getTopLeft(_card('venue_added:b')).dy, lessThan(y));
      expect(tester.getTopLeft(_card('game_created:c')).dy, greaterThan(y));
      // The list still ends in the caught-up row, after the last card.
      await tester.dragUntilVisible(
        find.byType(ActiveCaughtUpRow),
        find.byType(CustomScrollView).first,
        const Offset(0, -200),
      );
      expect(find.byType(ActiveCaughtUpRow), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ActiveCaughtUpRow)).dy,
        greaterThan(tester.getTopLeft(_card('player_joined:d')).dy),
      );
    }, variant: desktopOnly);

    testWidgets('game card: type, Live, time, actor, date tile, tags — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeGame(
              type: 'game_started',
              at: activeNow.subtract(const Duration(minutes: 12)),
              live: true,
            ),
          ],
          hasMore: false,
        ),
      );
      const id = 'game_started:g1';
      expect(_in(id, find.text(l.act_type_game_started)), findsOneWidget);
      expect(_in(id, find.byType(ActiveLiveBadge)), findsOneWidget);
      expect(_in(id, find.text(l.act_live)), findsOneWidget);
      expect(_in(id, find.text(l.time_minutes_ago(12))), findsOneWidget);
      expect(_in(id, find.byType(DabblerAvatar)), findsOneWidget);
      expect(_in(id, find.text('Omar Hassan')), findsOneWidget);
      expect(_in(id, find.text(l.act_actor_host)), findsOneWidget);
      final tile = _in(id, find.byKey(const ValueKey('active-date-tile')));
      expect(tile, findsOneWidget);
      expect(tester.getSize(tile), const Size(45, 45));
      final start = DateTime(2026, 11, 20, 19);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(DateFormat.MMM(l.localeName).format(start)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          // DabblerText always draws Western digits.
          matching: find.text(
            DabblerType.toWesternDigits(
              DateFormat.d(l.localeName).format(start),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(_in(id, find.text('Sunday 5-a-side')), findsOneWidget);
      expect(_in(id, find.text('Al Wasl Sports Club')), findsOneWidget);
      expect(_in(id, find.text(ar ? 'كرة القدم' : 'Football')), findsOneWidget);
      expect(_in(id, find.text('Dubai')), findsOneWidget);
      // The type glyph leads the card in reading order.
      final card = tester.getRect(_card(id));
      final glyph = tester.getRect(_in(id, find.byType(DabblerIcon)).first);
      if (ar) {
        expect(card.right - glyph.right, moreOrLessEquals(13, epsilon: 0.5));
      } else {
        expect(glyph.left - card.left, moreOrLessEquals(13, epsilon: 0.5));
      }
    }, variant: desktopOnly);

    testWidgets('venue card: building tile, no actor, no Live — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[activeVenue(at: activeNow)],
          hasMore: false,
        ),
      );
      const id = 'venue_added:v1';
      expect(_in(id, find.text(l.act_type_venue_added)), findsOneWidget);
      final icons = tester
          .widgetList<DabblerIcon>(_in(id, find.byType(DabblerIcon)))
          .map((i) => i.name);
      expect(icons, contains('building-4'));
      expect(
        _in(id, find.byKey(const ValueKey('active-date-tile'))),
        findsNothing,
      );
      expect(_in(id, find.byType(DabblerAvatar)), findsNothing);
      expect(_in(id, find.byType(ActiveLiveBadge)), findsNothing);
      expect(_in(id, find.text('JLT Padel Club')), findsOneWidget);
      expect(_in(id, find.text('Jumeirah Lake Towers')), findsOneWidget);
    }, variant: desktopOnly);

    testWidgets('player card: actor row only, no listing — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[activePlayer(at: activeNow)],
          hasMore: false,
        ),
      );
      const id = 'player_joined:u1';
      expect(_in(id, find.text(l.act_type_player_joined)), findsOneWidget);
      expect(_in(id, find.byType(DabblerAvatar)), findsOneWidget);
      expect(_in(id, find.text(l.act_actor_joined)), findsOneWidget);
      expect(
        _in(id, find.byKey(const ValueKey('active-date-tile'))),
        findsNothing,
      );
      expect(_in(id, find.text('Abu Dhabi')), findsOneWidget);
    }, variant: desktopOnly);

    testWidgets('every card variant is tappable, players included — $dir', (
      tester,
    ) async {
      await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activePlayer(id: 'u1', at: activeNow),
            activeGame(id: 'g1', at: activeNow),
            activeVenue(id: 'v1', at: activeNow),
          ],
          hasMore: false,
        ),
      );
      for (final (String id, String route) in <(String, String)>[
        // The player opens their profile by profile id.
        ('player_joined:u1', '/user-profile/u1?profileId=u1'),
        ('game_created:g1', '/sports/games/g1'),
        ('venue_added:v1', '/sports/venues/v1'),
      ]) {
        activePushed.clear();
        await tester.ensureVisible(_card(id));
        await tester.pump();
        await tester.tap(_card(id));
        await tester.pumpAndSettle();
        expect(activePushed, <String>[route], reason: id);
        // Back to Home for the next card.
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.pop();
        await tester.pumpAndSettle();
      }
    }, variant: desktopOnly);

    testWidgets('loading shows three skeleton cards — $dir', (tester) async {
      await openActiveTab(
        tester,
        locale: locale,
        state: const ActiveFeedLoading(),
      );
      expect(find.byType(ActiveSkeletonList), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ActiveSkeletonList),
          matching: find.byType(DabblerSurface),
        ),
        findsNWidgets(3),
      );
      expect(find.byType(ActiveEventCard), findsNothing);
    }, variant: desktopOnly);

    testWidgets('empty: unfiltered, then filtered with Reset — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: const ActiveFeedData(events: <ActiveItem>[], hasMore: false),
      );
      expect(find.text(l.act_empty_title), findsOneWidget);
      expect(find.text(l.act_empty_text), findsOneWidget);
      expect(find.text(l.act_empty_refresh), findsOneWidget);
      expect(find.byType(ActiveCaughtUpRow), findsNothing);

      // Players returns nothing on live data: the filtered empty state.
      final players = find.byKey(const ValueKey('active-type-players'));
      await tester.ensureVisible(players);
      await tester.pump();
      await tester.tap(players);
      await tester.pump();
      expect(find.text(l.act_empty_filtered_title), findsOneWidget);
      expect(find.text(l.act_empty_filtered_text), findsOneWidget);
      final reset = find.widgetWithText(DabblerButton, l.act_reset_filters);
      expect(reset, findsOneWidget);
      await tester.tap(reset);
      await tester.pump();
      expect(activeFilterOf(tester), const ActiveFilter());
      expect(find.text(l.act_empty_title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);

    testWidgets('error: title, text and Try again — $dir', (tester) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: const ActiveFeedFailure('offline'),
      );
      expect(find.text(l.act_error_title), findsOneWidget);
      expect(find.text(l.act_error_text), findsOneWidget);
      expect(find.text(l.act_error_retry), findsOneWidget);
      expect(find.text('offline'), findsNothing);
    }, variant: desktopOnly);
  }
}
