import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/explore/presentation/widgets/location_permission_drawer.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/explore/presentation/widgets/sport_specific_filters.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/widgets/empty_states/no_upcoming_games_widget.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
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
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import '../../support/render_mode.dart';

/// Renders the Games and Venues listings (content, loading, empty, filter
/// sheet) and the explore drawers/widgets under the design-system theme in LTR
/// and RTL, and writes PNGs to the Alpha plan folder.
const String _shotsDir = String.fromEnvironment(
  'PLACES_SHOTS_DIR',
  defaultValue: '$kShotsRoot/places',
);

/// Where the games-match C4 renders go (`games-{dir}-{light|dark}-{state}`).
const String _c4Dir = String.fromEnvironment(
  'GAMES_C4_DIR',
  defaultValue: '$kShotsRoot/games-match1',
);

Future<void> _shootC4(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_c4Dir).createSync(recursive: true);
    File('$_c4Dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

class _Location extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

/// A ready location (Dubai), for frames the design draws with one.
class _ReadyLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.2,
      lng: 55.3,
      area: const Area(
        id: 'a1',
        name: 'Al Barsha',
        district: 'Dubai',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.3,
      ),
      source: ActiveLocationSource.manual,
    ),
  );
}

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf',
    'Glory-Regular.ttf',
    'Glory-Medium.ttf',
    'Glory-SemiBold.ttf',
    'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf',
    'meral-sans-regular.ttf',
    'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf',
    'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader = FontLoader(
      'packages/iconsax_flutter/FlutterIconsax',
    )..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
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
      endAt: now.add(const Duration(days: 1, minutes: 90)),
      variantNameEn: 'Half court',
      variantNameAr: 'نصف ملعب',
      hostVerified: true,
      favoriteCount: 12,
      favouritedByMe: true,
    ),
    NearbyGameModel(
      id: 'g4',
      title: 'Sunset futsal',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(minutes: 40)),
      status: 'upcoming',
      venueName: 'Kite Beach',
      distanceMeters: 2400,
      playerCount: 6,
      spotsRemaining: 4,
      isPublic: true,
      endAt: now.add(const Duration(minutes: 100)),
      variantNameEn: 'Futsal 5s',
      variantNameAr: 'خماسي صالات',
      favoriteCount: 2,
    ),
    NearbyGameModel(
      id: 'g5',
      title: 'Weekend kickabout',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(days: 2)),
      status: 'upcoming',
      venueName: 'Al Barsha Pond Park',
      distanceMeters: 4100,
      playerCount: 5,
      spotsRemaining: 7,
      isPublic: true,
      endAt: now.add(const Duration(days: 2, minutes: 60)),
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
      endAt: now.add(const Duration(days: 3, minutes: 60)),
      variantNameEn: 'Doubles',
      variantNameAr: 'زوجي',
      favoriteCount: 3,
    ),
  ];
}

List<VenueWithSportModel> _venues() => const <VenueWithSportModel>[
  VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Dubai Sports City Pitch 3',
    city: 'Dubai',
    area: 'Sports City',
    isIndoor: false,
    pricePerHour: 180,
    amenities: ['Parking', 'Changing rooms', 'Cafe', 'Floodlights'],
  ),
  VenueWithSportModel(
    id: 'v2',
    sportId: 's1',
    nameEn: 'Zayed Indoor Arena',
    city: 'Abu Dhabi',
    isIndoor: true,
    pricePerHour: 0,
  ),
  VenueWithSportModel(
    id: 'v3',
    sportId: 's1',
    nameEn: 'Al Quoz Courts',
    city: 'Dubai',
    area: 'Al Quoz',
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
  Size size = const Size(393, 852),
  bool locationReady = false,
}) async {
  tester.view.physicalSize = size;
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
        activeLocationProvider.overrideWith(
          locationReady ? _ReadyLocation.new : _Location.new,
        ),
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

/// Opens [builder] in the app's DS-backed adaptive sheet, as sports_screen does.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.builder, this.title});

  final WidgetBuilder builder;

  /// The sheet's header title, as the call sites in sports_screen pass it.
  final String? title;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDabblerSheet<void>(
        context: context,
        title: widget.title,
        detent: DabblerSheetDetent.content,
        builder: widget.builder,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const DabblerPage(body: SizedBox());
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final l = lookupAppLocalizations(locale);
    const Key key = Key('shot');

    testWidgets('games listing - $dir', (tester) async {
      await _pump(tester, const GamesScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text(l.nav_games), findsOneWidget);
      // The viewer's own game counts down in the Upcoming rail.
      expect(find.text(l.listing_upcoming), findsOneWidget);
      expect(find.byType(DabblerCardUpcoming), findsOneWidget);
      expect(find.text('Tuesday 5-a-side'), findsOneWidget);
      expect(find.byType(DabblerCardGame), findsWidgets);
      expect(find.text('Half court pickup'), findsOneWidget);
      // One spot left reads in the singular and flags the near-full game.
      expect(find.text(l.listing_spots_almost_full(1)), findsOneWidget);
      // The full game shows the note and a disabled "Full" button; the open
      // one the design's "Join game" button (`Listings.dc.html:258`).
      expect(find.text(l.listing_join_game), findsWidgets);
      // Phase B card fields (GAP #1, #2, #4, #6, #8, #10).
      expect(find.text(l.listing_free), findsWidgets);
      expect(find.text(l.listing_no_charge), findsWidgets);
      expect(
        find.text(dir == 'rtl' ? 'نصف ملعب' : 'Half court'),
        findsOneWidget,
      );
      expect(find.text(l.listing_starts_soon), findsOneWidget);
      expect(find.text(l.listing_skill_all_levels), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(l.listing_favourite_remove)), findsWidgets);
      expect(find.bySemanticsLabel(l.listing_share_game), findsWidgets);
      await _shoot(tester, key, 'games-listing-$dir');
      // The full game sits further down: its note and disabled button.
      await tester.dragUntilVisible(
        find.text('Padel doubles'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.listing_full), findsNWidgets(2));
    }, variant: desktop);

    final String theme =
        const String.fromEnvironment('RENDER_DARK') == '1' ? 'dark' : 'light';
    for (final String state in const ['default', 'filters', 'empty']) {
      testWidgets('games C4 $state - $dir $theme', (tester) async {
        await _pump(
          tester,
          const GamesScreen(),
          locale,
          mode: state == 'empty' ? _Mode.empty : _Mode.content,
          // Tall enough to show every spots tone (info, warning, error).
          size: const Size(393, 2200),
          locationReady: state == 'empty',
          extra: [
            // The design's empty frame is the filtered one: Within 5 km on,
            // a ready location, nothing in range.
            if (state == 'empty')
              nearbyGamesFilterEnabledProvider.overrideWith((ref) => true),
            if (state == 'filters') ...[
              gamesDateFilterProvider.overrideWith(
                (ref) => GamesDateFilter.thisWeek,
              ),
              gamesSkillFilterProvider.overrideWith(
                (ref) => GamesSkillFilter.intermediate,
              ),
              nearbyGameSortProvider.overrideWith(
                (ref) => NearbySortOrder.nearest,
              ),
            ],
          ],
        );
        expect(tester.takeException(), isNull);
        await _shootC4(tester, key, 'games-$dir-$theme-$state');
      }, variant: desktop);
    }

    testWidgets('games listing: filter sheet - $dir', (tester) async {
      await _pump(
        tester,
        const GamesScreen(),
        locale,
        extra: [
          gamesDateFilterProvider.overrideWith(
            (ref) => GamesDateFilter.thisWeek,
          ),
          gamesSkillFilterProvider.overrideWith(
            (ref) => GamesSkillFilter.intermediate,
          ),
        ],
      );
      // The applied rail shows under the header.
      expect(find.text(l.listing_this_week), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^${l.listing_filters}')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text(l.listing_group_skill), findsOneWidget);
      expect(find.text(l.listing_group_distance), findsOneWidget);
      expect(
        find.textContaining(l.listing_show_games(0).substring(0, 2)),
        findsOneWidget,
      );
      // The design has no Availability group (GAP #18); it has the weekend.
      expect(find.text(l.listing_open_spots), findsNothing);
      expect(find.text(l.listing_group_availability), findsNothing);
      expect(find.text(l.listing_this_weekend), findsOneWidget);
      // "Filters" and Reset sit in the sheet header, Reset once.
      expect(find.text(l.listing_filters), findsOneWidget);
      expect(find.text(l.listing_reset), findsOneWidget);
      await _shoot(tester, key, 'games-filter-sheet-$dir');
    }, variant: desktop);

    testWidgets('games listing: rail tap opens the sheet - $dir', (tester) async {
      await _pump(
        tester,
        const GamesScreen(),
        locale,
        extra: [
          gamesDateFilterProvider.overrideWith(
            (ref) => GamesDateFilter.thisWeekend,
          ),
        ],
      );
      expect(find.text(l.listing_this_weekend), findsOneWidget);
      expect(find.text(l.listing_group_skill), findsNothing);
      await tester.tap(find.bySemanticsLabel(l.listing_filters_open));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text(l.listing_group_skill), findsOneWidget);
    }, variant: desktop);

    testWidgets('games listing: loading - $dir', (tester) async {
      await _pump(tester, const GamesScreen(), locale, mode: _Mode.loading);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerSkeleton), findsWidgets);
      await _shoot(tester, key, 'games-skeleton-$dir');
    }, variant: desktop);

    testWidgets('games listing: empty - $dir', (tester) async {
      await _pump(tester, const GamesScreen(), locale, mode: _Mode.empty);
      expect(tester.takeException(), isNull);
      expect(find.text(l.listing_games_none_title), findsOneWidget);
      await _shoot(tester, key, 'games-empty-$dir');
    }, variant: desktop);

    testWidgets('games listing: empty under filters - $dir', (tester) async {
      await _pump(
        tester,
        const GamesScreen(),
        locale,
        mode: _Mode.empty,
        extra: [
          gamesDateFilterProvider.overrideWith(
            (ref) => GamesDateFilter.thisWeekend,
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l.listing_games_nearby_title), findsOneWidget);
      expect(
        find.text(l.listing_games_empty_window(l.listing_window_weekend)),
        findsOneWidget,
      );
      expect(find.text(l.listing_change_filters), findsOneWidget);
    }, variant: desktop);

    testWidgets('venues listing - $dir', (tester) async {
      await _pump(tester, const VenuesScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text(dir == 'rtl' ? 'ملاعب' : 'Venues'), findsOneWidget);
      expect(find.text('Dubai Sports City Pitch 3'), findsOneWidget);
      expect(find.byType(DabblerCardVenue), findsWidgets);
      // The favourite is the DS heart + share group.
      expect(find.byType(DabblerListingSocial), findsWidgets);
      await _shoot(tester, key, 'venues-listing-$dir');
    }, variant: desktop);

    testWidgets('venues listing: filter sheet - $dir', (tester) async {
      await _pump(tester, const VenuesScreen(), locale);
      await tester.tap(find.bySemanticsLabel(RegExp('^${l.listing_filters}')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text(l.listing_within_km(5)), findsWidgets);
      expect(find.text(l.listing_reset), findsOneWidget);
      // The frame's header is the title and Reset only: no close button.
      expect(
        find.bySemanticsLabel(DabblerSheet.defaultCloseLabel),
        findsNothing,
      );
      await _shoot(tester, key, 'venues-filter-sheet-$dir');
    }, variant: desktop);

    testWidgets('venues listing: loading - $dir', (tester) async {
      await _pump(tester, const VenuesScreen(), locale, mode: _Mode.loading);
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'venues-skeleton-$dir');
    }, variant: desktop);

    testWidgets('venues listing: empty - $dir', (tester) async {
      await _pump(tester, const VenuesScreen(), locale, mode: _Mode.empty);
      expect(tester.takeException(), isNull);
      expect(find.text(l.listing_venues_none_title), findsOneWidget);
      await _shoot(tester, key, 'venues-empty-$dir');
    }, variant: desktop);

    testWidgets('location permission drawer - $dir', (tester) async {
      await _pump(
        tester,
        _SheetHost(
          title: 'Enable Location',
          builder: (ctx) => LocationPermissionDrawer(
            onAllowLocation: () {},
            onRemindLater: () {},
            onNoThanks: () {},
          ),
        ),
        locale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Enable Location'), findsOneWidget);
      await _shoot(tester, key, 'location-permission-$dir');
    }, variant: desktop);

    testWidgets('manual location drawer - $dir', (tester) async {
      await _pump(
        tester,
        _SheetHost(
          title: 'Select Location',
          builder: (ctx) => const ManualLocationDrawer(),
        ),
        locale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Select Location'), findsOneWidget);
      expect(find.text('Downtown Dubai'), findsOneWidget);
      await _shoot(tester, key, 'manual-location-$dir');
    }, variant: desktop);

    testWidgets('no upcoming games widgets - $dir', (tester) async {
      await _pump(
        tester,
        const DabblerPage(
          body: SingleChildScrollView(
            child: NoUpcomingGamesWidget(
              hasJoinedGames: true,
              hasPastGames: true,
            ),
          ),
        ),
        locale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('No upcoming games'), findsOneWidget);
      await _shoot(tester, key, 'games-empty-no-upcoming-$dir');
    }, variant: desktop);

    testWidgets('first-time games widget - $dir', (tester) async {
      await _pump(
        tester,
        const DabblerPage(
          body: SingleChildScrollView(child: FirstTimeUserGamesWidget()),
        ),
        locale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Welcome to Dabbler!'), findsOneWidget);
      await _shoot(tester, key, 'games-first-time-$dir');
    }, variant: desktop);

    testWidgets('sport specific filters - $dir', (tester) async {
      final List<String> changes = <String>[];
      await _pump(
        tester,
        DabblerPage(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: CricketFilters(
              selectedFilters: const <String, dynamic>{'gameType': 'T20'},
              onFilterChanged: (k, v) => changes.add('$k=$v'),
            ),
          ),
        ),
        locale,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerChip), findsWidgets);
      await _shoot(tester, key, 'sport-filters-$dir');
    }, variant: desktop);
  }

  testWidgets('sport filter chip reports a pick once, never a de-select', (
    tester,
  ) async {
    final List<String> changes = <String>[];
    await _pump(
      tester,
      DabblerPage(
        body: SingleChildScrollView(
          child: FootballFilters(
            selectedFilters: const <String, dynamic>{},
            onFilterChanged: (k, v) => changes.add('$k=$v'),
          ),
        ),
      ),
      const Locale('en'),
    );
    // "All" is the selected chip when nothing is chosen: tapping it is a no-op.
    await tester.tap(find.text('All').first);
    await tester.pump();
    expect(changes, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
