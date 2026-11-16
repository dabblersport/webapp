// KAN-959 / KAN-962: the tab filter pill (selected tab only, transparent at
// rest), filter rows opened by a re-tap on the selected tab, multi-select tags
// per tab where the first tag clears, the Active type order and the city
// sheet note, in EN and AR.
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/home/presentation/widgets/active_filter_panel.dart';
import 'package:dabbler/features/home/presentation/widgets/home_tab_filters.dart';
import 'package:dabbler/features/home/presentation/widgets/home_tab_tags.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_957_support.dart';
import 'home_test_harness.dart';

Finder _key(String k) => find.byKey(ValueKey<String>(k));

HomeTabFilterPill _pill(WidgetTester tester, FeedTab tab) =>
    tester.widget<HomeTabFilterPill>(_key('home-tab-filter-${tab.name}'));

/// The count shown inside [tab]'s pill, or null when it shows none.
String? _count(WidgetTester tester, FeedTab tab) {
  final f = find.descendant(
    of: _key('home-tab-filter-${tab.name}'),
    matching: _key('home-tab-filter-count'),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.widget<DabblerText>(f).data;
}

DabblerChip _tag(WidgetTester tester, HomeTabTag t) =>
    tester.widget<DabblerChip>(_key('home-tag-${t.name}'));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

Future<AppLocalizations> _pump(WidgetTester tester, Locale locale) async {
  await pumpHome(
    tester,
    feedState: const FeedData(items: <FeedItem>[], hasMore: false),
    activeState: const ActiveFeedData(events: <ActiveItem>[], hasMore: false),
    locale: locale,
    overrides: <Override>[
      activeCitiesProvider.overrideWith((ref) async => <String>['Dubai']),
      listingCityProvider.overrideWithValue(
        const ListingCity('Dubai', country: 'UAE', countryCode: 'AE'),
      ),
    ],
  );
  await tester.pump();
  return lookupAppLocalizations(locale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in activeLocales) {
    final ar = locale.languageCode == 'ar';
    final dir = ar ? 'rtl' : 'ltr';

    testWidgets('the pill shows on the selected tab only, transparent at '
        'rest — $dir', (tester) async {
      final l = await _pump(tester, locale);
      for (final selected in FeedTab.values) {
        await tapFeedTab(tester, selected.label(l));
        for (final tab in FeedTab.values) {
          expect(
            _key('home-tab-filter-${tab.name}'),
            tab == selected && feedTabHasFilters(tab)
                ? findsOneWidget
                : findsNothing,
            reason: '${selected.name} selected, ${tab.name}',
          );
        }
        if (!feedTabHasFilters(selected)) continue;
        expect(_count(tester, selected), isNull);
        expect(_pill(tester, selected).highlighted, isFalse);
        // At rest the pill has no surface: transparent, ink glyph.
        expect(
          find.descendant(
            of: _key('home-tab-filter-${selected.name}'),
            matching: find.byType(DabblerSurface),
          ),
          findsNothing,
        );
      }
      expect(feedTabHasFilters(FeedTab.following), isFalse);
    }, variant: desktopOnly);

    testWidgets('re-tap toggles the row and the pill stays at rest; a switch '
        'closes it — $dir', (tester) async {
      final l = await _pump(tester, locale);
      for (final tab in <FeedTab>[
        FeedTab.forYou,
        FeedTab.nearby,
        FeedTab.news,
      ]) {
        // From a tab without filters, so this tap only selects.
        await tapFeedTab(tester, FeedTab.following.label(l));
        await tapFeedTab(tester, tab.label(l));
        expect(find.byType(HomeTabTagRail), findsNothing, reason: tab.name);
        await tapFeedTab(tester, tab.label(l));
        expect(_key('home-tag-rail-${tab.name}'), findsOneWidget);
        expect(_pill(tester, tab).highlighted, isFalse, reason: 'open, 0');
        await tapFeedTab(tester, tab.label(l));
        expect(find.byType(HomeTabTagRail), findsNothing);
        // Open, then switch away: the next tab starts closed.
        await tapFeedTab(tester, tab.label(l));
        await tapFeedTab(tester, FeedTab.following.label(l));
        expect(find.byType(HomeTabTagRail), findsNothing);
      }
      await tapFeedTab(tester, FeedTab.active.label(l));
      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(find.byType(ActiveFilterPanel), findsOneWidget);
      expect(find.byType(HomeTabTagRail), findsNothing);
      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(find.byType(ActiveFilterPanel), findsNothing);

      // Following has no filters: a re-tap opens nothing.
      await tapFeedTab(tester, FeedTab.following.label(l));
      await tapFeedTab(tester, FeedTab.following.label(l));
      expect(find.byType(HomeTabTagRail), findsNothing);
      expect(find.byType(ActiveFilterPanel), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);

    testWidgets('each tab shows its tags in order with their glyphs — $dir', (
      tester,
    ) async {
      final l = await _pump(tester, locale);
      final expected = <FeedTab, List<(HomeTabTag, String, String?)>>{
        FeedTab.forYou: [
          (HomeTabTag.allSports, l.home_sport_all, null),
          (HomeTabTag.mySports, l.home_tag_my_sports, 'medal-star'),
        ],
        FeedTab.nearby: [
          (HomeTabTag.city, 'Dubai', 'location'),
          (HomeTabTag.country, 'UAE', 'map'),
          (HomeTabTag.anywhere, l.home_tag_anywhere, 'global'),
        ],
        FeedTab.news: [
          (HomeTabTag.newsFollowing, l.home_tag_news_following, 'people'),
          (HomeTabTag.newsAll, l.home_tag_news_all, 'document-text'),
        ],
      };
      for (final MapEntry(key: tab, value: tags) in expected.entries) {
        await tapFeedTab(tester, FeedTab.following.label(l));
        await tapFeedTab(tester, tab.label(l));
        await tapFeedTab(tester, tab.label(l));
        double? lastLeft;
        for (final (i, (tag, label, icon)) in tags.indexed) {
          final chip = _tag(tester, tag);
          expect(chip.label, label, reason: tag.name);
          expect((chip.leadingIcon as DabblerIcon?)?.name, icon);
          // The first tag is on while nothing is picked.
          expect(chip.selected, i == 0, reason: tag.name);
          final left = tester.getRect(_key('home-tag-${tag.name}')).left;
          if (lastLeft != null) {
            expect(ar ? left < lastLeft : left > lastLeft, isTrue);
          }
          lastLeft = left;
        }
      }
    }, variant: desktopOnly);

    testWidgets('tags are multi-select per tab; the first clears; the count '
        'is the picks and persists — $dir', (tester) async {
      final l = await _pump(tester, locale);
      await tapFeedTab(tester, FeedTab.nearby.label(l));
      await tapFeedTab(tester, FeedTab.nearby.label(l));
      List<HomeTabTag>? picks(FeedTab t) =>
          _container(tester).read(homeTabPicksProvider)[t];

      await tester.tap(_key('home-tag-country'));
      await tester.pump();
      expect(picks(FeedTab.nearby), [HomeTabTag.country]);
      expect(_tag(tester, HomeTabTag.city).selected, isFalse);
      expect(_tag(tester, HomeTabTag.country).selected, isTrue);
      expect(_count(tester, FeedTab.nearby), '1');
      expect(_pill(tester, FeedTab.nearby).highlighted, isTrue);

      await tester.tap(_key('home-tag-anywhere'));
      await tester.pump();
      expect(picks(FeedTab.nearby), [HomeTabTag.country, HomeTabTag.anywhere]);
      expect(_count(tester, FeedTab.nearby), '2');

      // Tapping a picked tag drops it.
      await tester.tap(_key('home-tag-country'));
      await tester.pump();
      expect(picks(FeedTab.nearby), [HomeTabTag.anywhere]);
      expect(_count(tester, FeedTab.nearby), '1');

      // Another tab's picks are its own.
      await tapFeedTab(tester, FeedTab.news.label(l));
      expect(_count(tester, FeedTab.news), isNull);
      await tapFeedTab(tester, FeedTab.news.label(l));
      await tester.tap(_key('home-tag-newsAll'));
      await tester.pump();
      expect(_count(tester, FeedTab.news), '1');
      expect(_tag(tester, HomeTabTag.newsFollowing).selected, isFalse);

      // Back on Nearby: closed, still counted.
      await tapFeedTab(tester, FeedTab.nearby.label(l));
      expect(find.byType(HomeTabTagRail), findsNothing);
      expect(_count(tester, FeedTab.nearby), '1');

      // The first tag clears the picks.
      await tapFeedTab(tester, FeedTab.nearby.label(l));
      await tester.tap(_key('home-tag-city'));
      await tester.pump();
      expect(picks(FeedTab.nearby), isEmpty);
      expect(_tag(tester, HomeTabTag.city).selected, isTrue);
      expect(_count(tester, FeedTab.nearby), isNull);
      expect(_pill(tester, FeedTab.nearby).highlighted, isFalse);
      expect(picks(FeedTab.news), [HomeTabTag.newsAll]);
    }, variant: desktopOnly);

    testWidgets('Active: All, Players, Venues, Games, Meetups; the pill counts '
        'type and city — $dir', (tester) async {
      final l = await openActiveTab(
        tester,
        state: const ActiveFeedData(events: <ActiveItem>[], hasMore: false),
        locale: locale,
      );
      double? lastLeft;
      for (final k in ['all', 'players', 'venues', 'games', 'meetups']) {
        final left = tester.getRect(_key('active-type-$k')).left;
        if (lastLeft != null) {
          expect(ar ? left < lastLeft : left > lastLeft, isTrue, reason: k);
        }
        lastLeft = left;
      }
      expect(_count(tester, FeedTab.active), isNull);
      expect(_pill(tester, FeedTab.active).highlighted, isFalse);

      await tester.ensureVisible(_key('active-type-games'));
      await tester.pump();
      await tester.tap(_key('active-type-games'));
      await tester.pump();
      expect(_count(tester, FeedTab.active), '1');
      setActiveFilter(
        tester,
        const ActiveFilter(city: 'Dubai', type: ActiveType.games),
      );
      await tester.pump();
      expect(_count(tester, FeedTab.active), '2');
      final city = tester.widget<DabblerChip>(_key('active-city-chip'));
      expect(city.selected, isTrue);
      expect(city.label, 'Dubai');

      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(_count(tester, FeedTab.active), '2');
      setActiveFilter(tester, const ActiveFilter());
      await tester.pump();
      expect(_count(tester, FeedTab.active), isNull);
    }, variant: desktopOnly);

    for (final gps in <bool>[false, true]) {
      testWidgets('the city sheet note follows location access '
          '(${gps ? 'allowed' : 'not allowed'}) — $dir', (tester) async {
        await pumpHome(
          tester,
          feedState: const FeedData(items: <FeedItem>[], hasMore: false),
          activeState: const ActiveFeedData(
            events: <ActiveItem>[],
            hasMore: false,
          ),
          locale: locale,
          overrides: <Override>[
            activeCitiesProvider.overrideWith((ref) async => <String>['Dubai']),
            locationPermissionProvider.overrideWith((ref) async => gps),
          ],
        );
        final l = lookupAppLocalizations(locale);
        await tapFeedTab(tester, FeedTab.active.label(l));
        await tapFeedTab(tester, FeedTab.active.label(l));
        await tester.tap(_key('active-city-chip'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<DabblerText>(_key('active-city-note')).data,
          gps ? l.act_city_sheet_note_gps : l.act_city_sheet_note,
        );
      }, variant: desktopOnly);
    }

    testWidgets('My sports and News Following with no followed sport show '
        'the localized empty state — $dir', (tester) async {
      // The default profile follows no sport.
      await pumpHome(
        tester,
        feedState: const FeedData(items: <FeedItem>[], hasMore: false),
        newsState: const NewsTabState(loaded: true, hasMore: false),
        locale: locale,
      );
      await tester.pump();
      final l = lookupAppLocalizations(locale);
      expect(_key('for-you-no-sports'), findsNothing);
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      await tester.tap(_key('home-tag-mySports'));
      await tester.pump();
      expect(_key('for-you-no-sports'), findsOneWidget);
      expect(find.text(l.home_no_followed_sports), findsOneWidget);
      expect(find.text(l.home_no_followed_sports_hint), findsOneWidget);
      await tester.tap(_key('home-tag-allSports'));
      await tester.pump();
      expect(_key('for-you-no-sports'), findsNothing);

      // News opens on Following, the default tag.
      await tapFeedTab(tester, FeedTab.news.label(l));
      expect(_key('news-no-sports'), findsOneWidget);
      expect(find.text(l.home_no_followed_sports), findsOneWidget);
      await tapFeedTab(tester, FeedTab.news.label(l));
      await tester.tap(_key('home-tag-newsAll'));
      await tester.pump();
      expect(_key('news-no-sports'), findsNothing);
      expect(find.text(l.news_empty_title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);
  }

  test('toggleHomeTabPick: the first tag clears, others toggle in order', () {
    var p = const <FeedTab, List<HomeTabTag>>{};
    p = toggleHomeTabPick(p, FeedTab.forYou, HomeTabTag.mySports);
    expect(p[FeedTab.forYou], [HomeTabTag.mySports]);
    p = toggleHomeTabPick(p, FeedTab.forYou, HomeTabTag.mySports);
    expect(p[FeedTab.forYou], isEmpty);
    p = toggleHomeTabPick(p, FeedTab.nearby, HomeTabTag.anywhere);
    p = toggleHomeTabPick(p, FeedTab.nearby, HomeTabTag.country);
    expect(p[FeedTab.nearby], [HomeTabTag.anywhere, HomeTabTag.country]);
    p = toggleHomeTabPick(p, FeedTab.nearby, HomeTabTag.city);
    expect(p[FeedTab.nearby], isEmpty);
    // A tag of another tab is ignored.
    expect(toggleHomeTabPick(p, FeedTab.news, HomeTabTag.mySports), same(p));
    expect(
      homeTabTagOn(const [], FeedTab.news, HomeTabTag.newsFollowing),
      isTrue,
    );
    expect(homeTabTagOn(const [], FeedTab.news, HomeTabTag.newsAll), isFalse);
  });

  test('activeFilterCount', () {
    expect(activeFilterCount(const ActiveFilter()), 0);
    expect(activeFilterCount(const ActiveFilter(city: 'Dubai')), 1);
    expect(activeFilterCount(const ActiveFilter(type: ActiveType.venues)), 1);
    expect(
      activeFilterCount(
        const ActiveFilter(city: 'Dubai', type: ActiveType.venues),
      ),
      2,
    );
  });
}
