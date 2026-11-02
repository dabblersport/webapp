// KAN-689: tap-through for the Contributor own profile. Real ProfileScreen on a
// recording router; every assertion is the route and arguments a tap lands on.
import 'package:dabbler/data/models/profile/profile_statistics.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/controllers/sports_profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_game_counts_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/profile_screen.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/public_activity_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

class _Profile extends StateNotifier<ProfileState>
    implements ProfileController {
  _Profile(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sports extends StateNotifier<SportsProfileState>
    implements SportsProfileController {
  _Sports(List<SportProfile> profiles)
    : super(SportsProfileState(profiles: profiles));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Persona extends PersonaServiceNotifier {
  _Persona(PersonaState initial) : super(Supabase.instance.client) {
    state = initial;
  }
  @override
  Future<void> fetchUserPersonas() async {}
}

class _Acts extends StateNotifier<PublicActivitiesState>
    implements PublicActivitiesNotifier {
  _Acts() : super(const PublicActivitiesState(loaded: true));
  @override
  Future<void> load() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> ensureLoaded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


UserProfile _me() => UserProfile(
  id: 'profile-c',
  userId: 'user-1',
  username: 'moataz.m',
  displayName: 'Moataz Mustapha',
  personaType: 'contributor',
  profileType: 'personal',
  primarySport: 'sport-football',
  interests: const ['sport-football', 'sport-padel'],
  statistics: const ProfileStatistics(),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const List<Sport> _sports = [
  Sport(id: 'sport-football', nameEn: 'Football', sportKey: 'football', emoji: 'x'),
  Sport(id: 'sport-padel', nameEn: 'Padel', sportKey: 'padel', emoji: 'x'),
];

final DateTime _soon = DateTime.now().add(const Duration(days: 2));

GameCounts _counts({bool empty = false}) => computeGameCounts(
  empty
      ? <GameCountRow>[]
      : <GameCountRow>[
          GameCountRow(
            id: 'g-play',
            title: 'Padel doubles',
            startAt: _soon,
            isCancelled: false,
            isOrganiser: false,
            participation: GameParticipation.joined,
          ),
          GameCountRow(
            id: 'g-org',
            title: 'Thursday football',
            startAt: _soon.add(const Duration(days: 1)),
            isCancelled: false,
            isOrganiser: true,
          ),
        ],
);

class _Landed {
  Uri? uri;
  Object? extra;
  Map<String, String> params = const {};
  void reset() {
    uri = null;
    extra = null;
    params = const {};
  }
}

Future<_Landed> _pump(WidgetTester tester, {bool empty = false}) async {
  tester.view.physicalSize = const Size(393, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Landed landed = _Landed();
  Widget stop(GoRouterState s) {
    landed.uri = s.uri;
    landed.extra = s.extra;
    landed.params = s.pathParameters;
    return const Scaffold(body: Text('landed'));
  }

  final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '${RoutePaths.followers}/:profileId',
        name: RouteNames.followers,
        builder: (_, s) => stop(s),
      ),
      GoRoute(
        path: '${RoutePaths.following}/:profileId',
        name: RouteNames.following,
        builder: (_, s) => stop(s),
      ),
      GoRoute(path: '/:rest(.*)', builder: (_, s) => stop(s)),
    ],
  );
  addTearDown(router.dispose);

  Future<List<Post>> posts(Ref ref, ({String profileId, int page}) p) async =>
      <Post>[];
  const Locale locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith(
          (ref) => _Profile(ProfileState(profile: _me())),
        ),
        sportsProfileControllerProvider.overrideWith(
          (ref) => _Sports(const <SportProfile>[]),
        ),
        profileTakedownProvider.overrideWith((ref, id) async => false),
        myPostsCountProvider.overrideWith((ref) async => 12),
        followingCountProvider.overrideWith((ref, id) async => 48),
        followersCountProvider.overrideWith((ref, id) async => 1204),
        sportsProvider.overrideWith((ref) async => _sports),
        profileGameCountsProvider.overrideWith(
          (ref, args) async => _counts(empty: empty),
        ),
        userPostsProvider.overrideWith(posts),
        userCommentedPostsProvider.overrideWith(posts),
        userLikedPostsProvider.overrideWith(posts),
        userRepostedPostsProvider.overrideWith(posts),
        userActivitiesProvider.overrideWith((ref, id) => _Acts()),
        activeProfileTypeProvider.overrideWith((ref) => 'contributor'),
        availableProfilesProvider.overrideWith((ref) async => <UserProfile>[]),
        personaServiceProvider.overrideWith(
          (ref) => _Persona(const PersonaState()),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => DabblerToastProvider(child: child!),
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
      ),
    ),
  );
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return landed;
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  testWidgets('hero with no sport chosen opens /activities', (tester) async {
    final _Landed l = await _pump(tester);
    await tester.tap(find.byType(DabblerStatTile).first);
    await _settle(tester);
    expect(l.uri?.path, RoutePaths.activities);
  });

  testWidgets('hero with a sport chosen opens that personal Sport Profile', (
    tester,
  ) async {
    final _Landed l = await _pump(tester);
    await tester.tap(find.text('Football').first);
    await _settle(tester);
    await tester.tap(find.byType(DabblerStatTile).first);
    await _settle(tester);
    expect(l.uri?.path, RoutePaths.sportProfile);
    expect(l.uri?.queryParameters['profileId'], 'profile-c');
    expect(l.uri?.queryParameters['userId'], 'user-1');
    expect(l.uri?.queryParameters['sportId'], 'sport-football');
    expect(l.uri?.queryParameters['persona'], 'contributor');
  });

  testWidgets('Followers and Following push the own profile id', (tester) async {
    final _Landed l = await _pump(tester);
    await tester.tap(find.textContaining('Followers').first);
    await _settle(tester);
    expect(l.uri?.path, '${RoutePaths.followers}/profile-c');
    expect(l.params['profileId'], 'profile-c');
    GoRouter.of(tester.element(find.text('landed'))).pop();
    await _settle(tester);
    l.reset();
    await tester.tap(find.textContaining('Following').first);
    await _settle(tester);
    expect(l.uri?.path, '${RoutePaths.following}/profile-c');
    expect(l.params['profileId'], 'profile-c');
  });

  testWidgets('Upcoming and organised rows open the game; Create game opens the composer', (
    tester,
  ) async {
    final _Landed l = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('contributor-game-g-play')));
    await _settle(tester);
    expect(l.uri?.path, RoutePaths.gameDetail('g-play'));
    GoRouter.of(tester.element(find.text('landed'))).pop();
    await _settle(tester);
    l.reset();
    // g-org sits in Upcoming and in Games I organise; tap the organised copy.
    await tester.tap(
      find.byKey(const ValueKey<String>('contributor-game-g-org')).last,
    );
    await _settle(tester);
    expect(l.uri?.path, RoutePaths.gameDetail('g-org'));
    GoRouter.of(tester.element(find.text('landed'))).pop();
    await _settle(tester);
    l.reset();
    await tester.tap(find.text('Create game'));
    await _settle(tester);
    expect(l.uri?.path, RoutePaths.createGame);
  });

  testWidgets('new contributor: hero is inert, Find a game opens the Games tab', (
    tester,
  ) async {
    final _Landed l = await _pump(tester, empty: true);
    await tester.tap(find.byType(DabblerStatTile).first);
    await _settle(tester);
    expect(l.uri, isNull);
    await tester.tap(find.text('Find a game'));
    await _settle(tester);
    expect(l.uri?.path, RoutePaths.gamesTab);
  });
}
