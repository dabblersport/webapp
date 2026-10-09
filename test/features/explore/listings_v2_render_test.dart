import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/geometry_dump.dart';
import '../../support/render_mode.dart';

/// Listings v2 (Listings.dc.html 2026-10-08): the collapsing, section-tinted
/// header, rendered unscrolled and scrolled, with and without applied filters,
/// and measured against the frame's geometry.
const String _shotsDir = String.fromEnvironment(
  'LISTINGS_V2_DIR',
  defaultValue: '$kShotsRoot/listings-v2/app',
);
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

class _Location extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  dumpGeometry(tester, name);
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
  Sport(id: 's2', nameEn: 'Padel', nameAr: 'بادل', sportKey: 'padel'),
  Sport(
    id: 's3',
    nameEn: 'Basketball',
    nameAr: 'كرة السلة',
    sportKey: 'basketball',
  ),
  Sport(id: 's4', nameEn: 'Cricket', nameAr: 'كريكيت', sportKey: 'cricket'),
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
      sportName: 'Basketball',
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
      status: 'live',
      venueName: 'Al Quoz Courts',
      distanceMeters: 1200,
      playerCount: 4,
      spotsRemaining: 0,
      minSkill: 2,
      maxSkill: 3,
      isPublic: true,
    ),
    for (var i = 4; i <= 8; i++)
      NearbyGameModel(
        id: 'g$i',
        title: 'Evening game $i',
        sportName: 'Football',
        scheduledAt: DateTime(now.year, now.month, now.day, 23, 59),
        status: 'upcoming',
        venueName: 'Dubai Sports City',
        distanceMeters: 2000 + i * 100,
        playerCount: 6,
        spotsRemaining: 4,
        isPublic: true,
      ),
  ];
}

List<VenueWithSportModel> _venues() => <VenueWithSportModel>[
  const VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Dubai Sports City Pitch 3',
    city: 'Dubai',
    area: 'Sports City',
    isIndoor: false,
    pricePerHour: 180,
    amenities: ['Parking', 'Changing rooms', 'Cafe', 'Floodlights'],
  ),
  const VenueWithSportModel(
    id: 'v2',
    sportId: 's1',
    nameEn: 'Zayed Indoor Arena',
    city: 'Abu Dhabi',
    isIndoor: true,
    pricePerHour: 0,
  ),
  const VenueWithSportModel(
    id: 'v3',
    sportId: 's1',
    nameEn: 'Al Quoz Courts',
    city: 'Dubai',
    area: 'Al Quoz',
  ),
  for (var i = 4; i <= 9; i++)
    VenueWithSportModel(
      id: 'v$i',
      sportId: 's1',
      nameEn: 'Court $i',
      city: 'Dubai',
    ),
];

enum _Mode { content, loading, empty }

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale, {
  _Mode mode = _Mode.content,
  List<Override> extra = const <Override>[],
  Key key = const Key('shot'),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Future<List<NearbyGameModel>> games() => switch (mode) {
    _Mode.content => Future.value(_games()),
    _Mode.loading => Completer<List<NearbyGameModel>>().future,
    _Mode.empty => Future.value(const <NearbyGameModel>[]),
  };
  Future<List<VenueWithSportModel>> venues() => switch (mode) {
    _Mode.content => Future.value(_venues()),
    _Mode.loading => Completer<List<VenueWithSportModel>>().future,
    _Mode.empty => Future.value(const <VenueWithSportModel>[]),
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
        nearbyGamesProvider.overrideWith((ref, params) => games()),
        myPinnedGamesProvider.overrideWith(
          (ref, sportId) async => mode == _Mode.content
              ? [_games().first]
              : const <NearbyGameModel>[],
        ),
        venuesBySportWithFiltersProvider.overrideWith((ref, f) => venues()),
        ...extra,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settleImages(tester);
}

Future<void> _pumpListing(
  WidgetTester tester,
  Widget screen,
  DabblerTheme theme, {
  required bool filters,
}) async {
  await _pump(
    tester,
    SectionThemed(
      theme: theme,
      child: DabblerPage(body: screen),
    ),
    const Locale('en'),
    extra: <Override>[
      if (filters) ...<Override>[
        nearbyGamesFilterEnabledProvider.overrideWith((ref) => true),
        gamesDateFilterProvider.overrideWith((ref) => GamesDateFilter.today),
        nearbyGameSortProvider.overrideWith(
          (ref) => NearbySortOrder.defaultOrder,
        ),
      ],
    ],
  );
}

Future<void> _scroll(WidgetTester tester, Finder list) async {
  await tester.drag(list, const Offset(0, -240));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

double _opacityOf(WidgetTester tester, Finder f) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: f, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  final String mode = _dark ? 'dark' : 'light';
  const Key key = Key('shot');

  for (final bool filters in <bool>[true, false]) {
    final String fs = filters ? 'filters' : 'plain';

    testWidgets('games $mode $fs: top, then collapsed', (tester) async {
      await _pumpListing(
        tester,
        const GamesScreen(),
        DabblerTheme.sport,
        filters: filters,
      );
      expect(tester.takeException(), isNull);
      final Finder tabs = find.byType(DabblerTabs);
      // Frame geometry (status row excluded): the title row starts 6 down,
      // the tabs 79, the filters 120 (9 under the tabs), the list 158 + 12.
      expect(tester.getTopLeft(find.text('Games')).dy, closeTo(6, 4));
      expect(tester.getTopLeft(tabs).dy, closeTo(79, 2));
      if (filters) {
        expect(find.text('Clear all'), findsOneWidget);
      }
      await _shoot(tester, key, 'games-$mode-$fs-top');
      await _scroll(
        tester,
        filters
            ? find.text('Evening game 4')
            : find.byType(DabblerCardGame).first,
      );
      // Collapsed: the tabs fold away; with filters the title row goes too.
      expect(_opacityOf(tester, tabs), 0);
      if (filters) {
        expect(_opacityOf(tester, find.text('Games')), 0);
        expect(find.text('Clear all'), findsOneWidget);
      } else {
        expect(_opacityOf(tester, find.text('Games')), 1);
      }
      await _shoot(tester, key, 'games-$mode-$fs-collapsed');
    }, variant: desktop);

    testWidgets('venues $mode $fs: top, then collapsed', (tester) async {
      await _pumpListing(
        tester,
        const VenuesScreen(),
        DabblerTheme.main,
        filters: false,
      );
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'venues-$mode-top');
      await _scroll(tester, find.text('Zayed Indoor Arena'));
      await _shoot(tester, key, 'venues-$mode-collapsed');
    }, variant: desktop);
  }
}
