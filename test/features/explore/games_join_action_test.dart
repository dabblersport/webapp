import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';
import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// The Games listing card's "Join game" button runs the game detail's own
/// `GameViewController.joinGame` (the real RPC path, via a MockClient), with
/// the detail's outcomes, error copy and toasts, and no confirmation step.

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
];

List<NearbyGameModel> _games() {
  final DateTime now = DateTime.now();
  return <NearbyGameModel>[
    NearbyGameModel(
      id: 'open',
      title: 'Open game',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(days: 1)),
      status: 'upcoming',
      distanceMeters: 0,
      playerCount: 6,
      spotsRemaining: 4,
      isPublic: true,
    ),
    NearbyGameModel(
      id: 'full',
      title: 'Full game',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(days: 2)),
      status: 'upcoming',
      distanceMeters: 0,
      playerCount: 10,
      spotsRemaining: 0,
      isPublic: true,
    ),
    NearbyGameModel(
      id: 'mine',
      title: 'My game',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(days: 3)),
      status: 'upcoming',
      distanceMeters: 0,
      playerCount: 5,
      spotsRemaining: 5,
      isPublic: true,
      isJoined: true,
    ),
  ];
}

/// A real [GameViewController] on a MockClient whose join RPC answers [join].
GameViewController _controller(
  String id,
  Future<http.Response> Function(http.Request) join,
  List<http.Request> calls,
) {
  final client = buildTestSupabaseClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' &&
        path.contains(SupabaseConfig.vGameCardTable)) {
      return jsonObjectResponse(<String, dynamic>{
        'id': id,
        'title': 'Open game',
        'start_at': '2030-08-30T10:00:00Z',
        'end_at': '2030-08-30T11:00:00Z',
        'capacity': 10,
        'roster_count': 6,
      }, request: request);
    }
    if (request.method == 'POST' &&
        path.contains('/rpc/${SupabaseConfig.rpcJoinGameFn}')) {
      calls.add(request);
      return join(request);
    }
    return jsonListResponse(const [], request: request);
  });
  return GameViewController(supabase: client, gameId: id, currentUserId: 'u1');
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  Future<http.Response> Function(http.Request) join,
  List<http.Request> calls, {
  bool controller = true,
}) async {
  // Built outside the test's fake-async zone: the controller opens a realtime
  // socket whose heartbeat timer would otherwise count as a pending timer.
  final GameViewController? open = controller
      ? await tester.runAsync(() async {
          final c = _controller('open', join, calls);
          // Let its first load land, as it would while the list is on screen.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return c;
        })
      : null;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_Location.new),
        activeChallengeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        nearbyGamesProvider.overrideWith((ref, params) async => _games()),
        myPinnedGamesProvider.overrideWith(
          (ref, sportId) async => const <NearbyGameModel>[],
        ),
        gameViewControllerProvider.overrideWith(
          (ref, id) => id == 'open' && open != null
              ? open
              : _controller(id, join, calls),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: const GamesScreen(),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(initHomeTestSupabase);

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final l = lookupAppLocalizations(locale);

    testWidgets(
      'card states: join / full / already in - ${locale.languageCode}',
      (tester) async {
        final calls = <http.Request>[];
        await _pump(
          tester,
          locale,
          (r) async => jsonListResponse(const [], request: r),
          calls,
          controller: false,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(l.listing_join_game), findsOneWidget);
        // "Full" is the progress note and the disabled button.
        expect(find.text(l.listing_full), findsNWidgets(2));
        expect(find.text(l.listing_joined), findsWidgets);
        expect(calls, isEmpty);
      },
      variant: desktop,
    );
  }

  testWidgets('tapping Join game calls the join RPC for that game and toasts '
      'the detail screen\'s waitlist copy', (tester) async {
    final calls = <http.Request>[];
    await _pump(
      tester,
      const Locale('en'),
      (r) async => jsonListResponse(<Map<String, dynamic>>[
        <String, dynamic>{'result': 'waitlisted'},
      ], request: r),
      calls,
    );
    await tester.tap(find.text('Join game'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(calls, hasLength(1));
    expect(calls.single.body, contains('"p_game_id":"open"'));
    expect(find.text('Added to waitlist.'), findsOneWidget);
    // The button settles on the detail's waitlist state.
    expect(find.text('On waitlist'), findsOneWidget);
    expect(find.text('Join game'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  }, variant: desktop);

  testWidgets('a request-to-join answer toasts the detail copy and disables '
      'the button', (tester) async {
    final calls = <http.Request>[];
    await _pump(
      tester,
      const Locale('en'),
      (r) async => jsonListResponse(<Map<String, dynamic>>[
        <String, dynamic>{'result': 'request_submitted'},
      ], request: r),
      calls,
    );
    await tester.tap(find.text('Join game'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Join request sent.'), findsOneWidget);
    expect(find.text('Request sent'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  }, variant: desktop);

  testWidgets('a server error shows the detail screen\'s error toast and '
      'leaves the button usable', (tester) async {
    final calls = <http.Request>[];
    await _pump(
      tester,
      const Locale('en'),
      (r) async => postgrestErrorResponse(
        message: 'P0001: not_host',
        status: 400,
        request: r,
      ),
      calls,
    );
    await tester.tap(find.text('Join game'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Only the game creator can do that.'), findsOneWidget);
    expect(find.text('Join game'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  }, variant: desktop);
}
