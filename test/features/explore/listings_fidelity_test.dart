import 'dart:async';
import 'dart:math' as math;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Listings fidelity (phase 6): the Venues and Games listings measured
/// against `Listings.dc.html` — the card shell, the chrome-to-card and
/// card-to-card spacing, LTR and RTL, a 2x text scale, dark-mode contrast of
/// the text on a card, and the loading / empty / error states.
/// Measurements: `Dabbler-Alpha-Plan/listings/diff-table.md`.

class _Location extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
  Sport(id: 's2', nameEn: 'Padel', nameAr: 'بادل', sportKey: 'padel'),
];

List<NearbyGameModel> _games() {
  final DateTime now = DateTime.now();
  return <NearbyGameModel>[
    NearbyGameModel(
      id: 'g1',
      title: 'Tuesday 5-a-side',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(hours: 5)),
      status: 'upcoming',
      venueName: 'Dubai Sports City',
      distanceMeters: 3100,
      playerCount: 7,
      spotsRemaining: 3,
      isPublic: true,
      isJoined: true,
    ),
    NearbyGameModel(
      id: 'g2',
      title: 'Half court pickup',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(days: 1)),
      status: 'upcoming',
      venueName: 'Zayed Sports City',
      distanceMeters: 6300,
      playerCount: 9,
      spotsRemaining: 1,
      minSkill: 4,
      maxSkill: 5,
      isPublic: true,
    ),
    NearbyGameModel(
      id: 'g3',
      title: 'Padel doubles',
      sportName: 'Padel',
      scheduledAt: now.add(const Duration(days: 3)),
      status: 'upcoming',
      venueName: 'Al Quoz Courts',
      distanceMeters: 1200,
      playerCount: 4,
      spotsRemaining: 0,
      minSkill: 2,
      maxSkill: 3,
      isPublic: true,
    ),
  ];
}

const List<VenueWithSportModel> _venues = <VenueWithSportModel>[
  VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Dubai Sports City Pitch 3',
    city: 'Dubai',
    area: 'Sports City',
    isIndoor: false,
    pricePerHour: 180,
    amenities: <String>['Parking', 'Changing rooms', 'Cafe', 'Floodlights'],
  ),
  VenueWithSportModel(
    id: 'v2',
    sportId: 's1',
    nameEn: 'Zayed Indoor Arena',
    city: 'Abu Dhabi',
    isIndoor: true,
    pricePerHour: 0,
  ),
];

enum _Mode { content, loading, empty, error }

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Locale locale = const Locale('en'),
  _Mode mode = _Mode.content,
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Future<T> answer<T>(T content, T empty) => switch (mode) {
    _Mode.content => Future<T>.value(content),
    _Mode.loading => Completer<T>().future,
    _Mode.empty => Future<T>.value(empty),
    _Mode.error => Future<T>.error(StateError('offline')),
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_Location.new),
        activeChallengeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        nearbyGamesProvider.overrideWith(
          (ref, params) => answer(_games(), const <NearbyGameModel>[]),
        ),
        myPinnedGamesProvider.overrideWith(
          (ref, sportId) async => mode == _Mode.content
              ? <NearbyGameModel>[_games().first]
              : const <NearbyGameModel>[],
        ),
        venuesBySportWithFiltersProvider.overrideWith(
          (ref, f) => answer(_venues, const <VenueWithSportModel>[]),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            dark ? ThemeData.dark() : ThemeData.light(),
          ),
          locale: locale,
        ),
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

double _contrast(Color a, Color b) {
  final double l1 = a.computeLuminance();
  final double l2 = b.computeLuminance();
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

/// The listing cards on screen, top to bottom.
List<Rect> _cardRects(WidgetTester tester, Finder cards) => <Rect>[
  for (final Element e in cards.evaluate())
    tester.getRect(find.byWidget(e.widget)),
]..sort((Rect a, Rect b) => a.top.compareTo(b.top));

void _expectShell(WidgetTester tester, Finder card) {
  final DabblerCard shell = tester.widget<DabblerCard>(
    find.descendant(of: card, matching: find.byType(DabblerCard)).first,
  );
  // `background: --surface-card; border: 1px --outline-card;
  // border-radius: --radius-xl` (`Listings.dc.html:207, 752`).
  expect(shell.variant, DabblerCardVariant.white);
  expect(shell.radius, DabblerRadius.xl);
}

/// Every text run inside [card] in the ink the card is read in clears 4.5:1
/// on the card fill — brand ink and on-brand runs excepted (the provisional
/// dark brand, `colors.css:200`, clears 3:1).
void _expectDarkContrast(WidgetTester tester, Finder card) {
  final DabblerColors c = DabblerColors.of(tester.element(card));
  final Color fill = c.surfaceCard;
  for (final Text t in tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  )) {
    final Color? ink = t.style?.color;
    if (ink == null || ink.a == 0) continue;
    if (ink == c.onBrand || ink == c.brandPrimary) continue;
    // Tags and badges sit on their own fills (checked in the DS).
    if (find
        .ancestor(
          of: find.byWidget(t),
          matching: find.byType(DabblerListingTag),
        )
        .evaluate()
        .isNotEmpty) {
      continue;
    }
    expect(
      _contrast(ink, fill),
      greaterThanOrEqualTo(4.5),
      reason: '"${t.data}" on the card',
    );
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    group('Venues ($dir)', () {
      testWidgets('cards: white 18 shell, 15 under the tabs, 15 apart', (
        tester,
      ) async {
        await _pump(tester, const VenuesScreen(), locale: locale);
        expect(tester.takeException(), isNull);
        final Finder cards = find.byType(DabblerCardVenue);
        expect(cards, findsNWidgets(2));
        _expectShell(tester, cards.first);
        final List<Rect> r = _cardRects(tester, cards);
        final double tabs = tester.getBottomLeft(find.byType(DabblerTabs)).dy;
        expect(r[0].top - tabs, ListingLayout.listTop);
        expect(r[1].top - r[0].bottom, ListingLayout.venueCardGap);
        // The screen gutter, 18 each side, in both directions.
        expect(r[0].left, ListingLayout.gutter);
        expect(393 - r[0].right, ListingLayout.gutter);
        // The frame's tags: the setting on a brand-tint tag, sports outlined.
        expect(find.byType(DabblerListingTag), findsWidgets);
        expect(find.byType(DabblerBadge), findsNothing);
      }, variant: desktop);

      testWidgets('2x text: no overflow', (tester) async {
        await _pump(tester, const VenuesScreen(), locale: locale, textScale: 2);
        expect(tester.takeException(), isNull);
      }, variant: desktop);

      testWidgets('dark: the card text clears 4.5:1', (tester) async {
        await _pump(tester, const VenuesScreen(), locale: locale, dark: true);
        expect(tester.takeException(), isNull);
        _expectDarkContrast(tester, find.byType(DabblerCardVenue).first);
      }, variant: desktop);

      testWidgets('loading: three venue skeletons', (tester) async {
        await _pump(
          tester,
          const VenuesScreen(),
          locale: locale,
          mode: _Mode.loading,
        );
        expect(tester.takeException(), isNull);
        final List<DabblerListingSkeleton> s = tester
            .widgetList<DabblerListingSkeleton>(
              find.byType(DabblerListingSkeleton),
            )
            .toList();
        expect(s, hasLength(3));
        expect(
          s.every((x) => x.kind == DabblerListingSkeletonKind.venue),
          isTrue,
        );
      }, variant: desktop);

      testWidgets('empty: the listing empty state, 60 under the chrome', (
        tester,
      ) async {
        await _pump(
          tester,
          const VenuesScreen(),
          locale: locale,
          mode: _Mode.empty,
        );
        expect(tester.takeException(), isNull);
        final DabblerEmptyState e = tester.widget<DabblerEmptyState>(
          find.byType(DabblerEmptyState),
        );
        expect(e.size, DabblerEmptyStateSize.listing);
        expect(e.icon, 'location');
        final double tabs = tester.getBottomLeft(find.byType(DabblerTabs)).dy;
        expect(
          tester.getTopLeft(find.byType(DabblerEmptyState)).dy - tabs,
          ListingLayout.emptyTop,
        );
      }, variant: desktop);

      testWidgets('error: the error state with a retry', (tester) async {
        await _pump(
          tester,
          const VenuesScreen(),
          locale: locale,
          mode: _Mode.error,
        );
        expect(tester.takeException(), isNull);
        final DabblerEmptyState e = tester.widget<DabblerEmptyState>(
          find.byType(DabblerEmptyState),
        );
        expect(e.tone, DabblerEmptyStateTone.error);
        expect(e.onRetry, isNotNull);
      }, variant: desktop);
    });

    group('Games ($dir)', () {
      testWidgets('cards: white 18 shell, 20/26 time, tags, 12 apart', (
        tester,
      ) async {
        await _pump(tester, const GamesScreen(), locale: locale);
        expect(tester.takeException(), isNull);
        final Finder cards = find.byType(DabblerCardGame);
        expect(cards, findsNWidgets(2));
        _expectShell(tester, cards.first);
        final List<Rect> r = _cardRects(tester, cards);
        expect(r[1].top - r[0].bottom, ListingLayout.cardGap);
        expect(r[0].left, ListingLayout.gutter);
        expect(393 - r[0].right, ListingLayout.gutter);
        // The time is the figure-large step (`Listings.dc.html:227`).
        final Text time = tester.widget<Text>(
          find
              .descendant(of: cards.first, matching: find.byType(Text))
              .evaluate()
              .map((e) => find.byWidget(e.widget))
              .firstWhere(
                (f) =>
                    (tester.widget<Text>(f).style?.fontWeight ==
                        FontWeight.w700) &&
                    (tester.widget<Text>(f).style?.fontSize ?? 0) >= 19,
              ),
        );
        expect(
          time.style!.fontSize,
          DabblerType.figureLarge
              .resolveForDirection(
                dir == 'rtl' ? TextDirection.rtl : TextDirection.ltr,
              )
              .fontSize,
        );
        // Sport and skill on ListingTags, the sport in the viewer's language.
        expect(find.byType(DabblerListingTag), findsWidgets);
        expect(
          find.text(dir == 'rtl' ? 'كرة القدم' : 'Football'),
          findsWidgets,
        );
      }, variant: desktop);

      testWidgets('the one pinned game is the date-first upcoming tile', (
        tester,
      ) async {
        await _pump(tester, const GamesScreen(), locale: locale);
        final DabblerCardUpcoming u = tester.widget<DabblerCardUpcoming>(
          find.byType(DabblerCardUpcoming),
        );
        expect(u.month, isNotNull);
        expect(u.day, isNotNull);
        expect(u.rail, isFalse);
        // "Upcoming" 9 above the tile (`Listings.dc.html:115`).
        final AppLocalizations l = lookupAppLocalizations(locale);
        expect(
          tester.getTopLeft(find.byType(DabblerCardUpcoming)).dy -
              tester.getBottomLeft(find.text(l.listing_upcoming)).dy,
          ListingLayout.upcomingGap,
        );
      }, variant: desktop);

      testWidgets('2x text: no overflow', (tester) async {
        await _pump(tester, const GamesScreen(), locale: locale, textScale: 2);
        expect(tester.takeException(), isNull);
      }, variant: desktop);

      testWidgets('dark: the card text clears 4.5:1', (tester) async {
        await _pump(tester, const GamesScreen(), locale: locale, dark: true);
        expect(tester.takeException(), isNull);
        _expectDarkContrast(tester, find.byType(DabblerCardGame).first);
      }, variant: desktop);

      testWidgets('loading: three game skeletons', (tester) async {
        await _pump(
          tester,
          const GamesScreen(),
          locale: locale,
          mode: _Mode.loading,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widgetList<DabblerListingSkeleton>(
                find.byType(DabblerListingSkeleton),
              )
              .where((s) => s.kind == DabblerListingSkeletonKind.game),
          hasLength(3),
        );
      }, variant: desktop);

      testWidgets('empty: the listing empty state with the game glyph', (
        tester,
      ) async {
        await _pump(
          tester,
          const GamesScreen(),
          locale: locale,
          mode: _Mode.empty,
        );
        expect(tester.takeException(), isNull);
        final DabblerEmptyState e = tester.widget<DabblerEmptyState>(
          find.byType(DabblerEmptyState),
        );
        expect(e.size, DabblerEmptyStateSize.listing);
        expect(e.icon, 'game');
      }, variant: desktop);

      testWidgets('error: the error state with a retry', (tester) async {
        await _pump(
          tester,
          const GamesScreen(),
          locale: locale,
          mode: _Mode.error,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<DabblerEmptyState>(find.byType(DabblerEmptyState)).tone,
          DabblerEmptyStateTone.error,
        );
      }, variant: desktop);
    });

    testWidgets('chrome ($dir): 42 header circles, listing tabs', (
      tester,
    ) async {
      await _pump(tester, const GamesScreen(), locale: locale);
      final DabblerTabs tabs = tester.widget<DabblerTabs>(
        find.byType(DabblerTabs),
      );
      expect(tabs.variant, DabblerTabsVariant.listing);
      // The tab rail spans the screen; the tabs start in the gutter.
      expect(tester.getSize(find.byType(DabblerTabs)).width, 393);
      expect(DabblerPageHeader.actionDiameter, 42);
    }, variant: desktop);
  }
}
