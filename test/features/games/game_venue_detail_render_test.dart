import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/games/venue.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/features/venues/providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';

/// Renders Game details (D01) and Venue details (D03) under the design-system
/// theme in LTR and RTL and writes PNGs to the Alpha plan folder.
const String _shotsDir = String.fromEnvironment(
  'PLACES_SHOTS_DIR',
  defaultValue: '/Users/moataz/Desktop/Dabbler-Alpha-Plan/places',
);

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

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale, {
  List<Override> overrides = const [],
  double height = 852,
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const Key key = Key('shot');
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) {
    debugPrint(d.toString());
    previous?.call(d);
  };
  addTearDown(() => FlutterError.onError = previous);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
          locale: locale,
        ),
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Fails with the full diagnostic (which widget overflowed) if the frame threw.
void _noException(WidgetTester tester) {
  final Object? error = tester.takeException();
  if (error == null) return;
  fail(error is FlutterError ? error.toStringDeep() : error.toString());
}

/// Unmounts the screen so no periodic timer outlives the test.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeGameController extends StateNotifier<GameViewState>
    implements GameViewController {
  _FakeGameController(
    super.state, {
    this.host = false,
    this.onRoster = false,
    this.waitlisted = false,
  });
  final bool host;
  final bool onRoster;
  final bool waitlisted;

  @override
  String? get currentUserId => 'me';
  @override
  bool get isHost => host;
  @override
  bool get isOnRoster => onRoster;
  @override
  bool get isOnWaitlist => waitlisted;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> resync() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GameView _game({
  bool free = false,
  int rosterCount = 4,
  bool cancelled = false,
  Duration startsIn = const Duration(days: 1),
  int? minSkill = 2,
  int? maxSkill = 4,
}) {
  final start = DateTime.now().add(startsIn);
  return GameView(
    id: 'g1',
    title: 'Tuesday 5-a-side',
    gameType: 'casual',
    startAt: start,
    endAt: start.add(const Duration(minutes: 90)),
    capacity: 10,
    benchSlots: 2,
    totalSlots: 12,
    rosterCount: rosterCount,
    listingVisibility: 'public',
    joinPolicy: 'request',
    allowSpectators: true,
    allowsWaitlist: true,
    isCancelled: cancelled,
    joiningRule: free ? 'free' : 'paid',
    costCover: free ? 'free' : 'split_equally',
    minSkill: minSkill,
    maxSkill: maxSkill,
    sportKey: 'football',
    sportNameEn: 'Football',
    variantNameEn: 'Futsal 5s',
    creatorProfileId: 'p1',
    creatorUsername: 'ahmed',
    creatorDisplayName: 'Ahmed Farouk',
    areaName: 'Dubai Sports City',
    venueName: 'Elite Football Arena',
    venueSpaceName: 'Space 4',
    venueId: 'v1',
  );
}

const List<GameRosterEntry> _roster = [
  GameRosterEntry(
    profileId: 'p1',
    userId: 'u1',
    role: 'host',
    displayName: 'Ahmed Farouk',
  ),
  GameRosterEntry(
    profileId: 'p2',
    userId: 'u2',
    role: 'player',
    displayName: 'Rahul Menon',
  ),
  GameRosterEntry(
    profileId: 'p3',
    userId: 'me',
    role: 'player',
    displayName: 'Aisha Khan',
  ),
  GameRosterEntry(
    profileId: 'p4',
    userId: 'u4',
    role: 'player',
    displayName: 'Yousef Amer',
  ),
];

const List<GameWaitlistEntry> _waitlist = [
  GameWaitlistEntry(
    profileId: 'p5',
    userId: 'u5',
    position: 1,
    displayName: 'Dana Youssef',
  ),
];

const List<GameJoinRequestEntry> _requests = [
  GameJoinRequestEntry(
    id: 'r1',
    profileId: 'p6',
    userId: 'u6',
    displayName: 'Omar Said',
  ),
];

Override _gameOverride(
  GameViewState state, {
  bool host = false,
  bool onRoster = false,
  bool waitlisted = false,
}) => gameViewControllerProvider.overrideWith(
  (ref, id) => _FakeGameController(
    state,
    host: host,
    onRoster: onRoster,
    waitlisted: waitlisted,
  ),
);

Venue _venue({List<String>? sports, int totalRatings = 128}) => Venue(
  id: 'v1',
  name: 'Elite Football Arena',
  description:
      'Eight bookable areas across football, padel and basketball, with '
      'floodlights on every outdoor space. Natural and artificial grass, '
      'changing rooms, a cafe and covered parking.',
  addressLine1: 'Sector 3, Dubai Silicon Oasis',
  city: 'Dubai',
  state: 'Dubai',
  country: 'UAE',
  postalCode: '00000',
  latitude: 25.1,
  longitude: 55.3,
  phone: '+971 4 123 4567',
  email: 'hello@elite.example',
  website: 'elite.example',
  openingTime: '06:00',
  closingTime: '23:30',
  rating: 4.6,
  totalRatings: totalRatings,
  pricePerHour: 120,
  currency: 'AED',
  supportedSports: sports ?? const ['football', 'padel', 'basketball'],
  amenities: const ['Parking', 'Wifi', 'Lighting', 'Cafe', 'Showers'],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

List<Override> _venueOverrides(Venue venue) => [
  venueDetailProvider.overrideWith((ref, id) async => venue),
  favoriteVenueIdsForCurrentUserProvider.overrideWith(
    (ref) async => <String>{},
  ),
];

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  final Map<
    String,
    ({Widget Function() screen, List<Override> Function() overrides})
  >
  gameScenes = {
    // Viewer is not in the game: join call to action, open spots, waitlist.
    'game-detail': (
      screen: () => const GameDetailScreen(gameId: 'g1'),
      overrides: () => [
        _gameOverride(
          GameViewState(game: _game(), roster: _roster, waitlist: _waitlist),
        ),
      ],
    ),
    // Viewer is on the roster: "You're in", leave call to action, You pill.
    'game-detail-joined': (
      screen: () => const GameDetailScreen(gameId: 'g1'),
      overrides: () => [
        _gameOverride(
          GameViewState(game: _game(free: true), roster: _roster),
          onRoster: true,
        ),
      ],
    ),
    // Host: join requests with approve / deny, edit call to action, remove.
    'game-detail-host': (
      screen: () => const GameDetailScreen(gameId: 'g1'),
      overrides: () => [
        _gameOverride(
          GameViewState(
            game: _game(),
            roster: _roster,
            pendingRequests: _requests,
          ),
          host: true,
          onRoster: true,
        ),
      ],
    ),
    'game-detail-loading': (
      screen: () => const GameDetailScreen(gameId: 'g1'),
      overrides: () => [_gameOverride(const GameViewState(isLoading: true))],
    ),
    'game-detail-error': (
      screen: () => const GameDetailScreen(gameId: 'g1'),
      overrides: () => [
        _gameOverride(const GameViewState(error: 'Game not found')),
      ],
    ),
  };

  final Map<
    String,
    ({Widget Function() screen, List<Override> Function() overrides})
  >
  venueScenes = {
    'venue-detail': (
      screen: () => const VenueDetailScreen(venueId: 'v1'),
      overrides: () => _venueOverrides(_venue()),
    ),
  };

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    for (final e in gameScenes.entries) {
      testWidgets('renders ${e.key} - $dir', (tester) async {
        await _pump(
          tester,
          e.value.screen(),
          locale,
          overrides: e.value.overrides(),
        );
        _noException(tester);
        expect(find.byType(DabblerPage), findsOneWidget);
        await _shoot(tester, const Key('shot'), '${e.key}-$dir');
        await _unmount(tester);
      }, variant: desktop);
    }

    for (final e in venueScenes.entries) {
      testWidgets('renders ${e.key} - $dir', (tester) async {
        await _pump(
          tester,
          e.value.screen(),
          locale,
          overrides: e.value.overrides(),
        );
        _noException(tester);
        expect(find.byType(DabblerPage), findsOneWidget);
        await _shoot(tester, const Key('shot'), '${e.key}-$dir');
        await _unmount(tester);
      }, variant: desktop);
    }

    // The whole page on one tall canvas, so the lower sections are inspectable.
    for (final e in [...gameScenes.entries, ...venueScenes.entries].where(
      (e) => !e.key.endsWith('loading') && !e.key.endsWith('error'),
    )) {
      testWidgets('renders ${e.key}-full - $dir', (tester) async {
        await _pump(
          tester,
          e.value.screen(),
          locale,
          overrides: e.value.overrides(),
          height: 2100,
        );
        _noException(tester);
        await _shoot(tester, const Key('shot'), '${e.key}-full-$dir');
        await _unmount(tester);
      }, variant: desktop);
    }

    testWidgets('renders venue-detail-loading - $dir', (tester) async {
      await _pump(
        tester,
        const VenueDetailScreen(venueId: 'v1'),
        locale,
        overrides: [
          venueDetailProvider.overrideWith(
            (ref, id) => Future<Venue>.delayed(const Duration(hours: 1)),
          ),
          favoriteVenueIdsForCurrentUserProvider.overrideWith(
            (ref) async => <String>{},
          ),
        ],
      );
      _noException(tester);
      await _shoot(tester, const Key('shot'), 'venue-detail-loading-$dir');
      await _unmount(tester);
      // The delayed future outlives the widget tree; let it complete.
      await tester.pump(const Duration(hours: 2));
    }, variant: desktop);

    testWidgets('renders venue-detail-error - $dir', (tester) async {
      await _pump(
        tester,
        const VenueDetailScreen(venueId: 'v1'),
        locale,
        overrides: [
          venueDetailProvider.overrideWith(
            (ref, id) => Future<Venue>.error(Exception('offline')),
          ),
          favoriteVenueIdsForCurrentUserProvider.overrideWith(
            (ref) async => <String>{},
          ),
        ],
      );
      _noException(tester);
      await _shoot(tester, const Key('shot'), 'venue-detail-error-$dir');
      await _unmount(tester);
    }, variant: desktop);

    testWidgets('venue space sheet opens - $dir', (tester) async {
      await _pump(
        tester,
        const VenueDetailScreen(venueId: 'v1'),
        locale,
        overrides: _venueOverrides(_venue()),
      );
      await tester.scrollUntilVisible(
        find.text('Court / Field').first,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Court / Field').first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _noException(tester);
      expect(find.text('Sport Space'), findsOneWidget);
      expect(find.text('Hours'), findsOneWidget);
      await _shoot(tester, const Key('shot'), 'venue-space-sheet-$dir');
      await _unmount(tester);
    }, variant: desktop);

    testWidgets('game leave confirmation - $dir', (tester) async {
      await _pump(
        tester,
        const GameDetailScreen(gameId: 'g1'),
        locale,
        overrides: [
          _gameOverride(
            GameViewState(game: _game(), roster: _roster),
            onRoster: true,
          ),
        ],
      );
      await tester.tap(find.text('Leave game'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _noException(tester);
      expect(find.text('Leave game?'), findsOneWidget);
      await _shoot(tester, const Key('shot'), 'game-leave-dialog-$dir');
      await _unmount(tester);
    }, variant: desktop);
  }

  testWidgets('game: no booking, meetup or message-squad action is built', (
    tester,
  ) async {
    await _pump(
      tester,
      const GameDetailScreen(gameId: 'g1'),
      const Locale('en'),
      overrides: [_gameOverride(GameViewState(game: _game(), roster: _roster))],
    );
    expect(find.text('Message'), findsNothing);
    expect(find.text('Message Squad'), findsNothing);
    expect(find.text('Request to join'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('venue: no booking action is built', (tester) async {
    await _pump(
      tester,
      const VenueDetailScreen(venueId: 'v1'),
      const Locale('en'),
      overrides: _venueOverrides(_venue()),
    );
    expect(find.text('Book a space'), findsNothing);
    expect(find.text('Book Space'), findsNothing);
    await _unmount(tester);
  });
}
