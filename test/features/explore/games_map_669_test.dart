import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/maps/map_config.dart';
import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/widgets/games_map_view.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-669: List / Map toggle on Games discovery. Pins are the upcoming public
/// games under the list's filters; a pin opens the same game card.
const String _shotsDir = String.fromEnvironment(
  'KAN669_SHOTS_DIR',
  defaultValue: 'build/test_shots/kan669',
);

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
  Sport(id: 's2', nameEn: 'Padel', nameAr: 'بادل', sportKey: 'padel'),
];

NearbyGameModel _game(
  String id, {
  required DateTime at,
  String sport = 'Football',
  bool isPublic = true,
  String status = 'upcoming',
  bool located = true,
}) => NearbyGameModel(
  id: id,
  title: 'Game $id',
  sportName: sport,
  scheduledAt: at,
  status: status,
  venueName: 'Venue',
  latitude: located ? 25.2 + id.length * 0.0004 : null,
  longitude: located ? 55.3 + id.length * 0.0002 : null,
  distanceMeters: 1000,
  playerCount: 4,
  spotsRemaining: 2,
  isPublic: isPublic,
);

DateTime _day(int plus) {
  final DateTime n = DateTime.now();
  return DateTime(n.year, n.month, n.day + plus, 12);
}

List<NearbyGameModel> _data() => <NearbyGameModel>[
  _game('tomorrow-foot', at: _day(1)),
  _game('later-padel', at: _day(3), sport: 'Padel'),
  _game('private', at: _day(2), isPublic: false),
  _game('cancelled', at: _day(2), status: 'cancelled'),
  _game('past', at: DateTime.now().subtract(const Duration(days: 1))),
  _game('nowhere', at: _day(2), located: false),
];

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

class _Run {
  int locates = 0;
  int drawers = 0;
  final List<String> opened = <String>[];
}

Future<_Run> _pump(
  WidgetTester tester, {
  List<NearbyGameModel>? games,
  LocationResult? located,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  Key? shotKey,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Run run = _Run();
  final List<NearbyGameModel> all = games ?? _data();
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const SectionThemed(
          theme: DabblerTheme.sport,
          child: GamesScreen(),
        ),
      ),
      GoRoute(
        path: '/sports/games/:id',
        builder: (_, state) {
          run.opened.add(state.pathParameters['id']!);
          return const Scaffold(body: Text('game-card'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_ReadyLocation.new),
        activeChallengeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        nearbyGamesProvider.overrideWith((ref, params) {
          final String? want = params.sportId == null
              ? null
              : _sports.firstWhere((s) => s.id == params.sportId).nameEn;
          return Future.value(
            all.where((g) => want == null || g.sportName == want).toList(),
          );
        }),
        myPinnedGamesProvider.overrideWith(
          (ref, sportId) async => const <NearbyGameModel>[],
        ),
        mapTileLayerOverrideProvider.overrideWithValue(
          () => const SizedBox.shrink(),
        ),
        mapLocatorProvider.overrideWithValue(() async {
          run.locates++;
          return located ??
              LocationSuccess(lat: 25.2, lng: 55.3, accuracyMeters: 10);
        }),
        mapSetLocationOpenerProvider.overrideWithValue((_) async {
          run.drawers++;
        }),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(
            key: shotKey ?? const Key('shot'),
            child: child,
          ),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            brightness == Brightness.dark
                ? ThemeData.dark()
                : ThemeData.light(),
          ),
          locale: locale,
        ),
      ),
    ),
  );
  await _settle(tester);
  return run;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _toggle(String label) => find.bySemanticsLabel(label);

Finder get _pins => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('map-marker-'),
);

Future<void> _openMap(WidgetTester tester) async {
  await tester.tap(_toggle('Show map'));
  await _settle(tester);
}

ProviderContainer _c(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GamesScreen)));

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  test('only upcoming, public, located games earn a pin', () {
    final now = DateTime.now();
    final ids = gameMapMarkers(_data(), now).map((m) => m.id).toList();
    expect(ids, <String>['tomorrow-foot', 'later-padel']);
  });

  testWidgets('TC1 list is the default and the toggle is visible', (t) async {
    await _pump(t);
    expect(_toggle('Show map'), findsOneWidget);
    expect(find.byType(GamesMapView), findsNothing);
    expect(_c(t).read(gamesMapModeProvider), isFalse);
  });

  testWidgets('TC2 map shows one pin per upcoming public game', (t) async {
    await _pump(t);
    await _openMap(t);
    expect(find.byType(GamesMapView), findsOneWidget);
    expect(_pins, findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('map-marker-tomorrow-foot')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('map-marker-private')), findsNothing);
    expect(find.byKey(const ValueKey('map-marker-cancelled')), findsNothing);
    expect(find.byKey(const ValueKey('map-marker-past')), findsNothing);
  });

  testWidgets('TC3/TC4/TC6 filters apply on entry, update in place, survive', (
    t,
  ) async {
    await _pump(t);
    // TC3: a sport filter set on the list applies when entering the map.
    await t.tap(find.text('Padel').first);
    await _settle(t);
    await _openMap(t);
    expect(_pins, findsOneWidget);
    expect(
      find.byKey(const ValueKey('map-marker-later-padel')),
      findsOneWidget,
    );

    // TC4: a filter change on the map updates the pins without leaving it.
    await t.tap(find.text('All sports').first);
    await _settle(t);
    expect(_pins, findsNWidgets(2));
    _c(t).read(gamesDateFilterProvider.notifier).state =
        GamesDateFilter.tomorrow;
    await _settle(t);
    expect(find.byType(GamesMapView), findsOneWidget);
    expect(_pins, findsOneWidget);
    expect(
      find.byKey(const ValueKey('map-marker-tomorrow-foot')),
      findsOneWidget,
    );

    // TC6: back to the list keeps the same filters.
    await t.tap(_toggle('Show list'));
    await _settle(t);
    expect(find.byType(GamesMapView), findsNothing);
    expect(_c(t).read(gamesDateFilterProvider), GamesDateFilter.tomorrow);
    expect(find.text('Game tomorrow-foot'), findsOneWidget);
    expect(find.text('Game later-padel'), findsNothing);
  });

  testWidgets('TC5 a pin opens the game card and back returns to the map', (
    t,
  ) async {
    final run = await _pump(t);
    await _openMap(t);
    await t.tap(find.byKey(const ValueKey('map-marker-tomorrow-foot')));
    await _settle(t);
    expect(run.opened, <String>['tomorrow-foot']);
    expect(find.text('game-card'), findsOneWidget);
    GoRouter.of(t.element(find.text('game-card'))).pop();
    await _settle(t);
    expect(find.byType(GamesMapView), findsOneWidget);
    expect(_pins, findsNWidgets(2));
  });

  testWidgets('TC7 denied location opens the drawer once, no re-prompt', (
    t,
  ) async {
    final run = await _pump(t, located: LocationDenied());
    await _openMap(t);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(run.locates, 1);
    expect(run.drawers, 1);
    expect(_pins, findsNWidgets(2), reason: 'pins still show after a denial');
  });

  testWidgets('TC8 no games: empty-state message, no crash', (t) async {
    await _pump(t, games: const <NearbyGameModel>[]);
    await _openMap(t);
    expect(find.text('No games on the map'), findsOneWidget);
    expect(_pins, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'TC9 OSM credit is visible and the tile layer sets a user agent',
    (t) async {
      await _pump(t);
      await _openMap(t);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(kMapUserAgentPackageName, isNotEmpty);
    },
  );

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    for (final Brightness b in Brightness.values) {
      final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
      final String mode = b == Brightness.dark ? 'dark' : 'light';
      testWidgets('screenshots map - $dir $mode', (t) async {
        const Key key = Key('shot');
        await _pump(t, locale: locale, brightness: b, shotKey: key);
        final String label = locale.languageCode == 'ar'
            ? 'عرض الخريطة'
            : 'Show map';
        await t.tap(_toggle(label));
        await _settle(t);
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final RenderRepaintBoundary boundary =
              t.renderObject(find.byKey(key)) as RenderRepaintBoundary;
          final ui.Image image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(_shotsDir).createSync(recursive: true);
          File(
            '$_shotsDir/map-$dir-$mode.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        });
      });
    }
  }
}
