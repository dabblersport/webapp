import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/core/system_ui/system_chrome_sync.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../meetups/meetup_screens_harness.dart';
import '../../support/render_mode.dart';
import 'home_test_harness.dart' show FakeFeed, initHomeTestSupabase;

/// The REAL shell end to end: go_router `StatefulShellRoute` +
/// `MainNavigationScreen` (SectionThemed, the Action Area host, the bottom
/// bar) + the real Games, Venues and Meetups screens (ListingScaffold,
/// DabblerListingPage, DabblerTopFill, SystemChromeSurface), with a 50px
/// status-bar inset, on all four tabs. Home is a placeholder page (the
/// feed's own providers are out of scope here). Writes PNGs when
/// `--dart-define=SHOOT=true`.
const String _dir = String.fromEnvironment(
  'LISTINGS_V2_DIR',
  defaultValue: '$kShotsRoot/listings-v2/app-shell',
);

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

List<NearbyGameModel> _games() => <NearbyGameModel>[
  for (var i = 1; i <= 6; i++)
    NearbyGameModel(
      id: 'g$i',
      title: 'Evening game $i',
      sportName: 'Football',
      scheduledAt: DateTime.now().add(Duration(hours: 3 + i)),
      status: 'upcoming',
      venueName: 'Dubai Sports City',
      distanceMeters: 2000 + i * 100,
      playerCount: 6,
      spotsRemaining: 4,
      isPublic: true,
    ),
];

List<VenueWithSportModel> _venues() => <VenueWithSportModel>[
  for (var i = 1; i <= 6; i++)
    VenueWithSportModel(
      id: 'v$i',
      sportId: 's1',
      nameEn: 'Court $i',
      city: 'Dubai',
    ),
];

const double _status = 50;
const Key _key = Key('shell');

Future<GoRouter> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeMeetupRepository()
    ..list = <MeetupListItem>[
      for (var i = 0; i < 6; i++)
        meetupRow(
          'm$i',
          title: 'Sunrise run $i',
          startsIn: Duration(hours: 5 + i),
        ),
    ];
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) =>
                    const Center(child: DabblerEmptyState(title: 'Home')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/community', builder: (_, __) => const SizedBox()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.venuesTab,
                builder: (_, __) => const VenuesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.gamesTab,
                builder: (_, __) => const GamesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.meetups,
                builder: (_, __) => const MeetupsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initializeProfileDataProvider.overrideWith((ref) async => false),
        meetupActorProfileIdProvider.overrideWithValue(null),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        meetupsEnabledProvider.overrideWithValue(true),
        feedNotifierProvider.overrideWith(
          (ref) => FakeFeed(const FeedLoading()),
        ),
        activeLocationProvider.overrideWith(_Location.new),
        activeChallengeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        nearbyGamesProvider.overrideWith((ref, p) async => _games()),
        myPinnedGamesProvider.overrideWith(
          (ref, s) async => const <NearbyGameModel>[],
        ),
        venuesBySportWithFiltersProvider.overrideWith(
          (ref, f) async => _venues(),
        ),
        nearbyGamesFilterEnabledProvider.overrideWith((ref) => true),
        nearbyGameSortProvider.overrideWith(
          (ref) => NearbySortOrder.defaultOrder,
        ),
        meetupRepositoryProvider.overrideWithValue(repo),
        meetupRadiusProvider.overrideWith((ref) => 5000),
        isFollowingProvider.overrideWith((ref, p) async => false),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        builder: (context, child) {
          // A 50px status bar over the app, as on a phone.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(padding: mq.padding.copyWith(top: _status)),
            child: DabblerToastProvider(
              child: RepaintBoundary(
                key: _key,
                child: SystemChromeSync(child: child!),
              ),
            ),
          );
        },
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return router;
}

SystemUiOverlayStyle _bars(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(SystemChromeSync),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    )
    .value;

Future<void> _shoot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SHOOT')) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  testWidgets('Home -> Venues -> Games -> Meetups through the real shell', (
    tester,
  ) async {
    final router = await _pump(tester);
    final mode = renderThemeBase().brightness == Brightness.dark
        ? 'dark'
        : 'light';
    final page = DabblerColors.resolve(
      theme: DabblerTheme.main,
      brightness: renderThemeBase().brightness,
    ).bgPrimary;

    // Home: no band, the page ground behind the status bar.
    expect(_bars(tester).statusBarColor, page);
    await _shoot(tester, 'shell-$mode-1-home');

    for (final (String route, String name, DabblerTheme? section)
        in <(String, String, DabblerTheme?)>[
          (RoutePaths.venuesTab, 'venues', null),
          (RoutePaths.gamesTab, 'games', DabblerTheme.sport),
          (RoutePaths.meetups, 'meetups', DabblerTheme.active),
        ]) {
      router.go(route);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      // The band is under the status bar: the system status bar follows it,
      // and it is not the page ground.
      final bar = _bars(tester).statusBarColor!;
      expect(bar, isNot(page), reason: '$name status bar is the band');
      // The shell paints the same colour across the 50px inset.
      final strip = find.descendant(
        of: find.byType(DabblerTopFill),
        matching: find.byType(ColoredBox),
      );
      expect(
        tester.widgetList<ColoredBox>(strip).map((c) => c.color),
        contains(bar),
        reason: '$name top fill',
      );
      await _shoot(tester, 'shell-$mode-2-$name');
      // Scroll: the band folds, still under the status bar.
      await tester.drag(find.byType(ListView).last, const Offset(0, -260));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_bars(tester).statusBarColor, bar);
      await _shoot(tester, 'shell-$mode-3-$name-collapsed');
      expect(
        section == null ||
            section == DabblerTheme.sport ||
            section == DabblerTheme.active,
        isTrue,
      );
    }

    // Back to Home: the band and its status colour are released.
    router.go('/home');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_bars(tester).statusBarColor, page);
  });
}
