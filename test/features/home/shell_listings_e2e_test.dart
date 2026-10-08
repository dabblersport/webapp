import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/core/feedback/shell_action_area_host.dart';
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
    final Brightness b = renderThemeBase().brightness;
    final mode = b == Brightness.dark ? 'dark' : 'light';
    DabblerColors tokens(DabblerTheme t) =>
        DabblerColors.resolve(theme: t, brightness: b);
    final page = tokens(DabblerTheme.main).bgPrimary;

    // The expected band of a tinted listing for a theme: the DS tint.
    Color tint(DabblerTheme t) => Color.lerp(
      tokens(t).surfaceCard,
      tokens(t).brandPrimary,
      DabblerListingPage.tintShare,
    )!;
    final Color accent = b == Brightness.dark
        ? DabblerProvisionalDark.tileAccentSurface
        : DabblerColors.tileAccent.surface;

    // Every tab with ITS theme. Venues is `main` (not "no override"): it must
    // stay the main brand, never the sport (Games) or active (Meetups) one.
    final rows =
        <
          ({
            String route,
            String name,
            DabblerTheme theme,
            Color? band, // null: no band, the page ground
          })
        >[
          (route: '/home', name: 'home', theme: DabblerTheme.main, band: null),
          (
            route: RoutePaths.venuesTab,
            name: 'venues',
            theme: DabblerTheme.main,
            band: tint(DabblerTheme.main),
          ),
          (
            route: RoutePaths.gamesTab,
            name: 'games',
            theme: DabblerTheme.main,
            // Plain header, the design default (GAP #28): no band.
            band: null,
          ),
          (
            route: RoutePaths.meetups,
            name: 'meetups',
            theme: DabblerTheme.active,
            band: accent,
          ),
        ];
    final others = <DabblerTheme>[
      DabblerTheme.main,
      DabblerTheme.sport,
      DabblerTheme.active,
    ];
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    }

    final bottomBar = find.byType(DabblerNavigationBottomBar);
    final actionArea = find.byType(ShellActionAreaHost);
    final topFill = find.byType(DabblerTopFill);

    for (final r in rows) {
      if (r.route != '/home') router.go(r.route);
      await settle();
      final DabblerColors want = tokens(r.theme);

      // 1. The status band: the system status bar AND the shell's top fill
      //    are the DS band token for this theme (or the page ground at Home).
      final Color expectedBand = r.band ?? page;
      expect(
        _bars(tester).statusBarColor,
        expectedBand,
        reason: '${r.name}: status bar band',
      );
      if (r.band != null) {
        expect(
          _painted(tester, topFill),
          contains(expectedBand),
          reason: '${r.name}: top fill band',
        );
      }

      // 2. The bottom bar, by its own finder: the theme's brand, resolved
      //    for it and painted, and no other section's brand.
      expect(
        DabblerColors.of(tester.element(bottomBar)).brandPrimary,
        want.brandPrimary,
        reason: '${r.name}: bottom bar brand',
      );
      expect(
        _painted(tester, bottomBar),
        contains(want.brandPrimary),
        reason: '${r.name}: bottom bar fill',
      );

      // 3. The Action Area host, by its own finder.
      expect(
        DabblerColors.of(tester.element(actionArea)).brandPrimary,
        want.brandPrimary,
        reason: '${r.name}: Action Area brand',
      );
      expect(
        _painted(tester, actionArea),
        contains(want.brandPrimary),
        reason: '${r.name}: Action Area fill',
      );

      // 4. Never another section's brand.
      for (final t in others.where(
        (t) => tokens(t).brandPrimary != want.brandPrimary,
      )) {
        expect(
          _painted(tester, bottomBar),
          isNot(contains(tokens(t).brandPrimary)),
          reason: '${r.name}: bottom bar is not ${t.name}',
        );
      }
      await _shoot(tester, 'shell-$mode-2-${r.name}');

      // Scroll: the band folds, still under the status bar.
      if (r.band != null) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -260));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(_bars(tester).statusBarColor, expectedBand);
        await _shoot(tester, 'shell-$mode-3-${r.name}-collapsed');
      }
    }

    // The Venues-stays-main regression: its bottom bar and band are the MAIN
    // brand, never the sport (Games) or active (Meetups) one.
    router.go(RoutePaths.venuesTab);
    await settle();
    final venuesBar = DabblerColors.of(tester.element(bottomBar)).brandPrimary;
    final venuesBand = _bars(tester).statusBarColor;
    final sportBand = tint(DabblerTheme.sport);
    expect(venuesBar, tokens(DabblerTheme.main).brandPrimary);
    expect(venuesBar, isNot(tokens(DabblerTheme.sport).brandPrimary));
    expect(venuesBar, isNot(tokens(DabblerTheme.active).brandPrimary));
    expect(venuesBand, isNot(sportBand));
    expect(venuesBand, isNot(accent));

    // Back to Home: the band and its status colour are released.
    router.go('/home');
    await settle();
    expect(_bars(tester).statusBarColor, page);
  });
}

/// The colours painted by plain boxes under [root] (DecoratedBox fills and
/// ColoredBox colours): what actually reaches the pixels of a DS widget.
Set<Color> _painted(WidgetTester tester, Finder root) {
  final out = <Color>{};
  for (final e
      in find
          .descendant(of: root, matching: find.byType(DecoratedBox))
          .evaluate()) {
    final d = (e.widget as DecoratedBox).decoration;
    if (d is BoxDecoration && d.color != null) out.add(d.color!);
  }
  for (final e
      in find
          .descendant(of: root, matching: find.byType(ColoredBox))
          .evaluate()) {
    out.add((e.widget as ColoredBox).color);
  }
  return out;
}
