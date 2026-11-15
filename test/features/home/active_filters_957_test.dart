// KAN-957: the Active filter panel — chips, the "Filter by city" sheet, the
// summary line, "Reset filters" and persistence across tabs, in EN and AR.
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/widgets/active_filter_panel.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_957_support.dart';
import 'active_fixtures.dart';
import 'home_test_harness.dart';

final ActiveFeedData _data = ActiveFeedData(
  events: <ActiveItem>[activeGame(at: activeNow)],
  hasMore: false,
);

Finder _key(String k) => find.byKey(ValueKey<String>(k));

DabblerChip _chip(WidgetTester tester, String k) =>
    tester.widget<DabblerChip>(_key(k));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('the rail: city chip, divider, All and four types — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(tester, state: _data, locale: locale);
      expect(find.byType(ActiveFilterPanel), findsOneWidget);
      expect(_chip(tester, 'active-city-chip').label, l.act_city_all);
      expect(_chip(tester, 'active-city-chip').selected, isFalse);
      for (final (k, label) in <(String, String)>[
        ('all', l.act_filter_all),
        ('games', l.act_filter_games),
        ('meetups', l.act_filter_meetups),
        ('venues', l.act_filter_venues),
        ('players', l.act_filter_players),
      ]) {
        expect(_chip(tester, 'active-type-$k').label, label);
      }
      expect(_chip(tester, 'active-type-all').selected, isTrue);
      // Nothing is filtered: no summary, no reset.
      expect(_key('active-filter-summary'), findsNothing);
      expect(_key('active-reset-filters'), findsNothing);
      // The rail starts at the reading edge.
      final rail = tester.getRect(_key('active-filter-rail'));
      final city = tester.getRect(_key('active-city-chip'));
      if (dir == 'ltr') {
        expect(city.left, lessThan(rail.center.dx));
      } else {
        expect(city.right, greaterThan(rail.center.dx));
      }
    }, variant: desktopOnly);

    testWidgets('a type chip filters, shows the summary and resets — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(tester, state: _data, locale: locale);
      await tester.tap(_key('active-type-games'));
      await tester.pump();
      expect(activeFilterOf(tester).type, ActiveType.games);
      expect(_chip(tester, 'active-type-games').selected, isTrue);
      expect(_chip(tester, 'active-type-all').selected, isFalse);
      expect(find.text(l.act_summary(l.act_filter_games)), findsOneWidget);
      expect(find.text(l.act_reset_filters), findsOneWidget);

      await tester.tap(_key('active-reset-filters'));
      await tester.pump();
      expect(activeFilterOf(tester), const ActiveFilter());
      expect(_key('active-filter-summary'), findsNothing);
      expect(_chip(tester, 'active-type-all').selected, isTrue);
    }, variant: desktopOnly);

    testWidgets('the city sheet lists the cities and filters — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(tester, state: _data, locale: locale);
      await tester.tap(_key('active-city-chip'));
      await tester.pumpAndSettle();
      expect(find.text(l.act_city_sheet_title), findsOneWidget);
      expect(find.text(l.act_city_sheet_note), findsOneWidget);
      for (final c in <String>[l.act_city_all, 'Abu Dhabi', 'Dubai']) {
        final row = _key('active-city-row-$c');
        expect(row, findsOneWidget);
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      }
      // "All cities" is the selected row.
      expect(
        find.descendant(
          of: _key('active-city-row-${l.act_city_all}'),
          matching: _key('active-city-tick'),
        ),
        findsOneWidget,
      );

      await tester.tap(_key('active-city-row-Dubai'));
      await tester.pumpAndSettle();
      expect(find.text(l.act_city_sheet_title), findsNothing);
      expect(activeFilterOf(tester).city, 'Dubai');
      expect(_chip(tester, 'active-city-chip').label, 'Dubai');
      expect(_chip(tester, 'active-city-chip').selected, isTrue);
      expect(find.text(l.act_summary('Dubai')), findsOneWidget);

      // Reopened, Dubai carries the tick.
      await tester.tap(_key('active-city-chip'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('active-city-row-Dubai'),
          matching: _key('active-city-tick'),
        ),
        findsOneWidget,
      );
    }, variant: desktopOnly);

    testWidgets('the summary joins type and city on one line — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(tester, state: _data, locale: locale);
      setActiveFilter(
        tester,
        const ActiveFilter(city: 'Dubai', type: ActiveType.venues),
      );
      await tester.pump();
      final text = l.act_summary('${l.act_filter_venues} · Dubai');
      expect(find.text(text), findsOneWidget);
      final DabblerText summary = tester.widget(_key('active-filter-summary'));
      expect(summary.maxLines, 1);
      expect(summary.overflow, TextOverflow.ellipsis);
    }, variant: desktopOnly);

    testWidgets('filters persist across tab switches — $dir', (tester) async {
      final l = await openActiveTab(tester, state: _data, locale: locale);
      setActiveFilter(
        tester,
        const ActiveFilter(city: 'Dubai', type: ActiveType.meetups),
      );
      await tester.pump();
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      expect(find.byType(ActiveFilterPanel), findsNothing);
      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(activeFilterOf(tester).type, ActiveType.meetups);
      expect(_chip(tester, 'active-type-meetups').selected, isTrue);
      expect(_chip(tester, 'active-city-chip').label, 'Dubai');
    }, variant: desktopOnly);
  }

  test('activeFilterSummary is null with no filter', () {
    expect(const ActiveFilter().isActive, isFalse);
  });
}
