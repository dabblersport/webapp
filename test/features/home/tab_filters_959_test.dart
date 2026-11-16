// KAN-959: the tab filter pill, filter rows opened only by a re-tap on the
// selected tab, and the For you sport filter, in EN and AR.
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/home/presentation/widgets/active_filter_panel.dart';
import 'package:dabbler/features/home/presentation/widgets/home_tab_filters.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/for_you_sport_filter.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_957_support.dart';
import 'home_test_harness.dart';

const padel = '33333333-3333-3333-3333-333333333333';
const tennis = '22222222-2222-2222-2222-222222222222';

const List<Sport> _sports = <Sport>[
  Sport(id: padel, nameEn: 'Padel', nameAr: 'بادل'),
  Sport(id: tennis, nameEn: 'Tennis', nameAr: 'تنس'),
];

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

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

Future<AppLocalizations> _pump(WidgetTester tester, Locale locale) async {
  await pumpHome(
    tester,
    feedState: const FeedData(items: <FeedItem>[], hasMore: false),
    activeState: const ActiveFeedData(events: <ActiveItem>[], hasMore: false),
    locale: locale,
    sports: _sports,
    overrides: <Override>[
      activeCitiesProvider.overrideWith((ref) async => <String>['Dubai']),
    ],
  );
  await tester.pump();
  return lookupAppLocalizations(locale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  for (final locale in activeLocales) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('pill on For you and Active only, no count at rest — $dir', (
      tester,
    ) async {
      await _pump(tester, locale);
      for (final tab in FeedTab.values) {
        expect(
          _key('home-tab-filter-${tab.name}'),
          feedTabHasFilters(tab) ? findsOneWidget : findsNothing,
          reason: tab.name,
        );
      }
      for (final tab in [FeedTab.forYou, FeedTab.active]) {
        expect(_count(tester, tab), isNull);
        expect(_pill(tester, tab).highlighted, isFalse);
        expect(
          find.descendant(
            of: _key('home-tab-filter-${tab.name}'),
            matching: find.byWidgetPredicate(
              (w) => w is DabblerIcon && w.name == 'setting-4',
            ),
          ),
          findsOneWidget,
        );
      }
    }, variant: desktopOnly);

    testWidgets('re-tap toggles the row; a switch closes it — $dir', (
      tester,
    ) async {
      final l = await _pump(tester, locale);
      // For you is selected; its row starts hidden.
      expect(find.byType(ForYouSportRail), findsNothing);
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      expect(find.byType(ForYouSportRail), findsOneWidget);
      expect(_pill(tester, FeedTab.forYou).highlighted, isTrue, reason: 'open');
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      expect(find.byType(ForYouSportRail), findsNothing);
      expect(_pill(tester, FeedTab.forYou).highlighted, isFalse);

      // Open For you, then switch to Active: Active starts closed.
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(find.byType(ForYouSportRail), findsNothing);
      expect(find.byType(ActiveFilterPanel), findsNothing);
      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(find.byType(ActiveFilterPanel), findsOneWidget);
      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(find.byType(ActiveFilterPanel), findsNothing);

      // Back to For you: closed again.
      await tapFeedTab(tester, FeedTab.active.label(l));
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      expect(find.byType(ForYouSportRail), findsNothing);
      expect(find.byType(ActiveFilterPanel), findsNothing);

      // A tab with no filters never opens a row.
      await tapFeedTab(tester, FeedTab.news.label(l));
      await tapFeedTab(tester, FeedTab.news.label(l));
      expect(find.byType(ForYouSportRail), findsNothing);
      expect(find.byType(ActiveFilterPanel), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: desktopOnly);

    testWidgets('For you rail: All sports, then the sports; choosing counts '
        'and persists, All sports clears — $dir', (tester) async {
      final l = await _pump(tester, locale);
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      final all = tester.widget<DabblerChip>(_key('for-you-sport-all'));
      expect(all.label, l.home_sport_all);
      expect(all.selected, isTrue);
      final ar = locale.languageCode == 'ar';
      expect(
        tester.widget<DabblerChip>(_key('for-you-sport-$padel')).label,
        ar ? 'بادل' : 'Padel',
      );
      expect(
        tester.widget<DabblerChip>(_key('for-you-sport-$tennis')).label,
        ar ? 'تنس' : 'Tennis',
      );
      // "All sports" comes first, at the reading edge.
      final allRect = tester.getRect(_key('for-you-sport-all'));
      final padelRect = tester.getRect(_key('for-you-sport-$padel'));
      expect(
        ar ? allRect.left > padelRect.left : allRect.left < padelRect.left,
        isTrue,
      );

      await tester.tap(_key('for-you-sport-$padel'));
      await tester.pump();
      expect(_container(tester).read(forYouSportProvider), padel);
      expect(
        tester.widget<DabblerChip>(_key('for-you-sport-$padel')).selected,
        isTrue,
      );
      expect(_count(tester, FeedTab.forYou), '1');

      // Persists across a tab switch; the pill still counts while closed.
      await tapFeedTab(tester, FeedTab.following.label(l));
      await tapFeedTab(tester, FeedTab.forYou.label(l));
      expect(find.byType(ForYouSportRail), findsNothing);
      expect(_container(tester).read(forYouSportProvider), padel);
      expect(_count(tester, FeedTab.forYou), '1');
      expect(_pill(tester, FeedTab.forYou).highlighted, isTrue);

      await tapFeedTab(tester, FeedTab.forYou.label(l));
      await tester.tap(_key('for-you-sport-all'));
      await tester.pump();
      expect(_container(tester).read(forYouSportProvider), isNull);
      expect(_count(tester, FeedTab.forYou), isNull);
    }, variant: desktopOnly);

    testWidgets('Active pill counts the type and the city — $dir', (
      tester,
    ) async {
      final l = await openActiveTab(
        tester,
        state: const ActiveFeedData(events: <ActiveItem>[], hasMore: false),
        locale: locale,
      );
      expect(_count(tester, FeedTab.active), isNull);
      expect(_pill(tester, FeedTab.active).highlighted, isTrue, reason: 'open');

      await tester.tap(_key('active-type-games'));
      await tester.pump();
      expect(_count(tester, FeedTab.active), '1');

      setActiveFilter(
        tester,
        const ActiveFilter(city: 'Dubai', type: ActiveType.games),
      );
      await tester.pump();
      expect(_count(tester, FeedTab.active), '2');

      setActiveFilter(tester, const ActiveFilter(city: 'Dubai'));
      await tester.pump();
      expect(_count(tester, FeedTab.active), '1');

      // Closed, the count stays and the pill stays highlighted.
      await tapFeedTab(tester, FeedTab.active.label(l));
      expect(find.byType(ActiveFilterPanel), findsNothing);
      expect(_count(tester, FeedTab.active), '1');
      expect(_pill(tester, FeedTab.active).highlighted, isTrue);

      setActiveFilter(tester, const ActiveFilter());
      await tester.pump();
      expect(_count(tester, FeedTab.active), isNull);
      expect(_pill(tester, FeedTab.active).highlighted, isFalse);
    }, variant: desktopOnly);
  }

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
