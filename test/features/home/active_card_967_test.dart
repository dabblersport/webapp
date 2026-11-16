// KAN-967: the Active card types the design added (ActivityCard.dc.html,
// Home Feed.dc.html actCardNew / pairSlims): the trending strip and the pair
// of boxes, the player award, the featured venue (week, month, day) and the
// new venue rating, in EN and AR.
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/features/home/presentation/widgets/active_feed_list.dart';
import 'package:dabbler/features/home/presentation/widgets/active_filter_panel.dart';
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

String _w(String s) => DabblerType.toWesternDigits(s);

DateTime _ago(Duration d) => activeNow.subtract(d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  test('rows parse the KAN-967 columns, and round-trip', () {
    final row = activeVenueHonour(type: 'venue_day').toRow();
    final back = ActiveItem.fromRow(row)!;
    expect(back.reasons, hasLength(3));
    expect(back.reasons.first.text, '19:00');
    expect(back.distanceKm, 2.1);
    expect(back.rating, 4.8);
    final award = ActiveItem.fromRow(activeAward().toRow())!;
    // CEO 2026-11-16: players show Games / Rating / Hosted.
    expect(award.stats.map((s) => s.key), <String>[
      'games',
      'rating',
      'hosted',
    ]);
    // The live columns: no reasons or distance (venue of the day is later),
    // venue_rating_avg on a rating row.
    final live =
        Map<String, dynamic>.from(
            activeVenueHonour(type: 'venue_rating').toRow(),
          )
          ..remove('reasons')
          ..remove('distance_km');
    final parsed = ActiveItem.fromRow(live)!;
    expect(parsed.reasons, isEmpty);
    expect(parsed.distanceKm, isNull);
    expect(parsed.venueRatingAvg, 4.8);
    expect(parsed.rating, 5);
    expect(award.periodStart, DateTime(2026, 11, 16));
    expect(ActiveHonours.isoWeek(DateTime(2026, 11, 16)), 47);
    expect(activeTypeChipOrder[1], ActiveType.trending);
    expect(ActiveType.ofEvent('venue_rating'), ActiveType.venues);
    expect(ActiveType.ofEvent('player_month'), ActiveType.players);
  });

  test(
    'pairSlims: two trending items in a row pair; a third stays a strip',
    () {
      final a = activeTrend(id: 'a');
      final b = activeTrend(id: 'b', hashtag: true);
      final c = activeTrend(id: 'c');
      final g = activeGame(id: 'g');
      final cards = activeCardsOf(<ActiveItem>[a, b, c, g, a]);
      expect(cards.map((w) => w.runtimeType), <Type>[
        ActiveTrendPair,
        ActiveEventCard,
        ActiveEventCard,
        ActiveEventCard,
      ]);
    },
  );

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final ar = locale.languageCode == 'ar';

    testWidgets('trending: a strip alone, a pair when back to back — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeTrend(id: 's1', at: activeNow),
            activeGame(id: 'g1', at: _ago(const Duration(minutes: 20))),
            activeTrend(
              id: 'h1',
              hashtag: true,
              at: _ago(const Duration(minutes: 50)),
              metricKind: 'posts_today',
              metricValue: 214,
            ),
            activeTrend(
              id: 's2',
              at: _ago(const Duration(minutes: 51)),
              title: 'Cricket',
              sports: const <String>['Cricket'],
              sportsAr: const <String>['كريكيت'],
              metricKind: 'players_growth_pct',
              metricValue: 22,
            ),
          ],
          hasMore: false,
        ),
      );
      // The lone item is the full-width strip.
      final strip = tester.widget<DabblerActivitySlim>(
        _in('trending_sport:s1', find.byType(DabblerActivitySlim)),
      );
      expect(strip.tone, DabblerActivityTones.info);
      expect(strip.icon, 'trend-up');
      expect(strip.kicker, l.act_kicker_trending_sport);
      expect(strip.value, ar ? 'بادل' : 'Padel');
      expect(strip.metric, l.act_metric_games_growth(38));
      // The two in a row are one pair of boxes, hashtag first.
      final pair = find.byType(ActiveTrendPair);
      expect(pair, findsOneWidget);
      final boxes = tester
          .widgetList<DabblerActivityTrendBox>(
            find.descendant(
              of: pair,
              matching: find.byType(DabblerActivityTrendBox),
            ),
          )
          .toList();
      expect(boxes, hasLength(2));
      expect(boxes[0].icon, 'hashtag');
      expect(boxes[0].tone, DabblerActivityTones.main);
      expect(boxes[0].value, '#dabblernight');
      expect(boxes[0].metric, l.act_metric_posts_today(214));
      expect(boxes[1].kicker, l.act_kicker_trending_sport);
      expect(boxes[1].metric, l.act_metric_players_growth(22));
      final r0 = tester.getRect(find.byType(DabblerActivityTrendBox).first);
      final r1 = tester.getRect(find.byType(DabblerActivityTrendBox).last);
      expect(r0.top, r1.top);
      expect(r0.width, r1.width);
      // The first box is at the inline start.
      expect(ar ? r0.left > r1.left : r0.left < r1.left, isTrue);
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);

    testWidgets('player of the week and month — $dir', (tester) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeAward(at: activeNow),
            activeAward(
              id: 'p2',
              month: true,
              at: _ago(const Duration(minutes: 30)),
            ),
          ],
          hasMore: false,
        ),
      );
      const week = 'player_week:p1';
      final card = tester.widget<DabblerActivityCard>(
        _in(week, find.byType(DabblerActivityCard)),
      );
      expect(card.tone, DabblerActivityTones.active);
      expect(card.mark, 'medal-star');
      expect(
        tester
            .widget<DabblerActivityBadge>(
              _in(week, find.byType(DabblerActivityBadge)),
            )
            .label,
        l.act_week(47),
      );
      // The time is the period too (`time: 'Week 47'`).
      expect(_in(week, find.text(_w(l.act_week(47)))), findsNWidgets(2));
      final award = tester.widget<DabblerActivityAward>(
        _in(week, find.byType(DabblerActivityAward)),
      );
      expect(award.headline, 'Khalid Al Mansouri');
      expect(award.sub, '${ar ? 'كرة القدم' : 'Football'} · Dubai');
      expect(award.mark, 'medal-star');
      final stats = tester.widget<DabblerActivityStats>(
        _in(week, find.byType(DabblerActivityStats)),
      );
      expect(stats.items, <(String, String)>[
        ('6', l.act_stat_label_games),
        ('4.9', l.act_stat_label_rating),
        ('2', l.act_stat_label_hosted),
      ]);
      expect(
        tester
            .widget<DabblerActivityAction>(
              _in(week, find.byType(DabblerActivityAction)),
            )
            .label,
        l.act_cta_view_profile,
      );
      // No host avatar in the footer: the award's 80 avatar only.
      expect(
        tester
            .widgetList<DabblerAvatar>(_in(week, find.byType(DabblerAvatar)))
            .map((a) => a.size),
        <DabblerAvatarSize>[DabblerAvatarSize.xl],
      );

      await tester.ensureVisible(_card('player_month:p2'));
      await tester.pump();
      final month = tester.widget<DabblerActivityCard>(
        _in('player_month:p2', find.byType(DabblerActivityCard)),
      );
      expect(month.tone.surface, DabblerActivityTones.gold.surface);
      expect(month.mark, 'crown');
      expect(
        tester
            .widget<DabblerActivityBadge>(
              _in('player_month:p2', find.byType(DabblerActivityBadge)),
            )
            .label,
        DateFormat.MMMM(l.localeName).format(DateTime(2026, 10)),
      );
    }, variant: desktopOnly);

    testWidgets('venue of the week: photo, rating, courts, figures — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[activeVenueHonour(at: activeNow)],
          hasMore: false,
        ),
      );
      const id = 'venue_week:v9';
      final card = tester.widget<DabblerActivityCard>(
        _in(id, find.byType(DabblerActivityCard)),
      );
      expect(card.tone, DabblerActivityTones.sport);
      expect(card.mark, 'award');
      expect(
        tester
            .widget<DabblerActivityPhoto>(
              _in(id, find.byType(DabblerActivityPhoto)),
            )
            .ratingText,
        l.act_rating_reviews('4.8', 204),
      );
      final title = tester.widget<DabblerText>(
        _in(
          id,
          find.widgetWithText(DabblerText, 'Nad Al Sheba Sports Complex'),
        ).first,
      );
      expect(title.style, DabblerType.displayFeature);
      expect(
        _in(id, find.text(_w('Nad Al Sheba · ${l.act_venue_spaces(4)}'))),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DabblerActivityStats>(
              _in(id, find.byType(DabblerActivityStats)),
            )
            .items
            .first,
        ('128', l.act_stat_label_bookings),
      );
      expect(
        tester
            .widget<DabblerActivityAction>(
              _in(id, find.byType(DabblerActivityAction)),
            )
            .label,
        l.act_cta_book_court,
      );
    }, variant: desktopOnly);

    testWidgets('venue of the day: reasons, distance, Today — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeVenueHonour(type: 'venue_day', at: activeNow),
          ],
          hasMore: false,
        ),
      );
      const id = 'venue_day:v9';
      final card = tester.widget<DabblerActivityCard>(
        _in(id, find.byType(DabblerActivityCard)),
      );
      expect(card.tone, DabblerActivityTones.bright);
      expect(card.mark, 'magic-star');
      expect(
        tester
            .widget<DabblerActivityKicker>(
              _in(id, find.byType(DabblerActivityKicker)),
            )
            .label,
        l.act_kicker_venue_day,
      );
      expect(_in(id, find.text(l.act_group_today)), findsOneWidget);
      final reasons = tester
          .widgetList<DabblerActivityReason>(
            _in(id, find.byType(DabblerActivityReason)),
          )
          .map((r) => (r.icon, r.text))
          .toList();
      expect(reasons, <(String, String)>[
        (
          'clock',
          l.act_reason_free_from(
            DateFormat.jm(l.localeName).format(DateTime(2000, 1, 1, 19)),
          ),
        ),
        ('location', l.act_reason_km('2.1')),
        ('ticket-2', l.act_reason_price('120')),
      ]);
      expect(
        _in(id, find.text(_w('Nad Al Sheba · ${l.act_km_from_you('2.1')}'))),
        findsOneWidget,
      );
      expect(_in(id, find.byType(DabblerActivityStats)), findsNothing);
      expect(
        tester
            .widget<DabblerActivityAction>(
              _in(id, find.byType(DabblerActivityAction)),
            )
            .label,
        l.act_cta_book_now,
      );
    }, variant: desktopOnly);

    testWidgets('new venue rating: quote, rater, venue row — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        locale: locale,
        state: ActiveFeedData(
          events: <ActiveItem>[
            activeVenueHonour(
              type: 'venue_rating',
              at: _ago(const Duration(hours: 2)),
            ),
          ],
          hasMore: false,
        ),
      );
      const id = 'venue_rating:v9';
      final card = tester.widget<DabblerActivityCard>(
        _in(id, find.byType(DabblerActivityCard)),
      );
      expect(card.tone, DabblerActivityTones.social);
      expect(card.mark, 'star');
      final review = tester.widget<DabblerActivityReview>(
        _in(id, find.byType(DabblerActivityReview)),
      );
      expect(review.name, 'Aisha Khan');
      expect(review.rating, 5);
      expect(review.ratingLabel, l.act_rating_label('5'));
      expect(review.quote, 'Best lit pitch in Al Quoz.');
      expect(
        review.line,
        l.act_played_here(
          DateFormat.EEEE(l.localeName).format(DateTime(2026, 11, 10)),
        ),
      );
      final row = tester.widget<DabblerActivityVenueRow>(
        _in(id, find.byType(DabblerActivityVenueRow)),
      );
      expect(row.title, 'Al Quoz Pitches');
      // The venue's average (4.8) in the venue row; the rater's 5 stars
      // by the rater's name.
      expect(row.detail, 'Al Quoz · ${l.act_rating_from('4.8', 186)}');
      // The time is the clock (two hours ago), the action Read reviews.
      expect(
        _in(
          id,
          find.text(
            _w(
              DateFormat.jm(
                l.localeName,
              ).format(_ago(const Duration(hours: 2))),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DabblerActivityAction>(
              _in(id, find.byType(DabblerActivityAction)),
            )
            .label,
        l.act_cta_read_reviews,
      );
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);
  }
}
