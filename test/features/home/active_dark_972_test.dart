// KAN-972: the Active looks follow the theme (EN/AR × light/dark): each card
// draws its look's tone pair for the ambient brightness, and its content
// reads the ambient colours (no light island).
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_957_support.dart';
import 'active_fixtures.dart';
import 'home_test_harness.dart';

DateTime _ago(Duration d) => activeNow.subtract(d);

final List<(String, ActiveItem, String, DabblerActivityTone)> _looks =
    <(String, ActiveItem, String, DabblerActivityTone)>[
      (
        'upcoming game',
        activeGame(at: activeNow, count: 6, capacity: 14),
        'game_created:g1',
        DabblerActivityTone.main,
      ),
      (
        'live game',
        activeGame(
          type: 'game_started',
          at: activeNow,
          startAt: _ago(const Duration(hours: 1)),
          endAt: activeNow.add(const Duration(hours: 1)),
          live: true,
        ),
        'game_started:g1',
        DabblerActivityTone.sport,
      ),
      (
        'finished game',
        activeGame(
          type: 'game_ended',
          at: activeNow,
          startAt: _ago(const Duration(hours: 3)),
          endAt: _ago(const Duration(hours: 1)),
        ),
        'game_ended:g1',
        DabblerActivityTone.ended,
      ),
      (
        'finished meetup',
        activeGame(
          kind: 'meetup',
          type: 'meetup_completed',
          at: activeNow,
          startAt: _ago(const Duration(hours: 4)),
          endAt: _ago(const Duration(hours: 2)),
        ),
        'meetup_completed:g1',
        DabblerActivityTone.accent,
      ),
      (
        'player',
        activePlayer(at: activeNow),
        'player_joined:u1',
        DabblerActivityTone.social,
      ),
      (
        'venue',
        activeVenue(at: activeNow),
        'venue_added:v1',
        DabblerActivityTone.bright,
      ),
      (
        'trending sport',
        activeTrend(at: activeNow),
        'trending_sport:t1',
        DabblerActivityTone.info,
      ),
      (
        'player of the month',
        activeAward(month: true, at: activeNow),
        'player_month:p1',
        DabblerActivityTone.gold,
      ),
      (
        'venue rating',
        activeVenueHonour(type: 'venue_rating', at: activeNow),
        'venue_rating:v9',
        DabblerActivityTone.social,
      ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    for (final b in Brightness.values) {
      final mode = b == Brightness.dark ? 'dark' : 'light';
      for (final (name, row, id, tone) in _looks) {
        testWidgets('$name follows $mode — $dir', (tester) async {
          await openActiveTab(
            tester,
            locale: locale,
            brightness: b,
            state: ActiveFeedData(events: <ActiveItem>[row], hasMore: false),
          );
          final card = find.byKey(ValueKey<String>(id));
          final colors = DabblerColors.of(tester.element(card));
          expect(colors.brightness, b);
          final pair = tone.resolve(b);
          if (row.isSlim) {
            final strip = tester.widget<DabblerActivitySlim>(
              find.descendant(
                of: card,
                matching: find.byType(DabblerActivitySlim),
              ),
            );
            expect(strip.tone, pair);
          } else {
            final c = tester.widget<DabblerActivityCard>(
              find.descendant(
                of: card,
                matching: find.byType(DabblerActivityCard),
              ),
            );
            expect(c.tone, pair);
            final ground = tester.widget<ColoredBox>(
              find
                  .descendant(of: card, matching: find.byType(ColoredBox))
                  .first,
            );
            expect(ground.color, pair.surface);
            // The action button: the ink filled, the card surface label.
            final action = tester.widget<DabblerActivityAction>(
              find.descendant(
                of: card,
                matching: find.byType(DabblerActivityAction),
              ),
            );
            expect(action.ink, pair.ink);
          }
          // No light island: text inside resolves the ambient colours.
          final inner = find
              .descendant(of: card, matching: find.byType(Text))
              .first;
          expect(DabblerColors.of(tester.element(inner)).brightness, b);
          if (b == Brightness.dark) {
            expect(pair.surface.computeLuminance(), lessThan(0.05));
          }
          expect(tester.takeException(), isNull);
        }, variant: desktopOnly);
      }
    }
  }
}
