// KAN-957: the Active list — date groups, tappable cards and the loading,
// empty and error states, in EN and AR. The card itself (KAN-964) is
// covered by active_card_964_test.dart.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

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
      // The headers seen on the way down (KAN-964 cards are taller, so the
      // last group is built only once scrolled to).
      final headers = <String>[];
      void collect() {
        for (final h in tester.widgetList<ActiveGroupHeader>(
          find.byType(ActiveGroupHeader),
        )) {
          if (!headers.contains(h.label)) headers.add(h.label);
        }
      }

      collect();
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
      collect();
      expect(headers, <String>[
        l.act_group_today,
        l.act_group_yesterday,
        DateFormat.MMMEd(l.localeName).format(older),
      ]);
      expect(find.byType(ActiveCaughtUpRow), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ActiveCaughtUpRow)).dy,
        greaterThan(tester.getTopLeft(_card('player_joined:d')).dy),
      );
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
