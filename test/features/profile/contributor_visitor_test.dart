// KAN-688: the Contributor visitor view. Data / failed / gap states of the
// bento and Upcoming, no owner leakage, Follow / Message / Invite gating, the
// blocked state, and that visiting never writes the signed-in user's own
// profile controller.
import 'dart:async';

import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart' as sp;
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/controllers/sports_profile_controller.dart';
import 'package:dabbler/features/profile/presentation/models/contributor_profile_data.dart';
import 'package:dabbler/features/profile/presentation/providers/contributor_profile_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/visited_profile_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/user_profile_screen.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/contributor_games_sections.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_header.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/visitor/contributor_visitor_bento.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/visitor/contributor_visitor_sections.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/visitor/contributor_visitor_upcoming.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile_message_action.dart';
import 'package:dabbler/features/ratings/presentation/widgets/rating_summary.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' hide Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

class _FakeProfile extends StateNotifier<ProfileState>
    implements ProfileController {
  _FakeProfile(super.state);
  int loads = 0;
  @override
  Future<void> loadProfile(
    String userId, {
    String? profileType,
    bool filterActive = true,
    String? profileId,
  }) async {
    loads++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSports extends StateNotifier<SportsProfileState>
    implements SportsProfileController {
  _FakeSports()
    : super(const SportsProfileState(profiles: <sp.SportProfile>[]));
  @override
  Future<void> loadSportsProfiles(String userId, {String? profileId}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Anchored to the real clock: the screen filters Upcoming against
// DateTime.now() (buildContributorScope), so fixed fixture dates go stale.
final DateTime _now = DateTime.now();

UserProfile _omar({bool emptyBio = false}) => UserProfile(
  id: 'p-omar',
  userId: 'u-omar',
  username: 'omar_k',
  displayName: 'Omar Khalil',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  bio: emptyBio ? null : 'Weekend padel, Tuesday football.',
  city: 'Dubai',
  personaType: 'contributor',
  primarySport: 's-padel',
  interests: const <String>['s-padel', 's-football'],
);

UserProfile _me() => UserProfile(
  id: 'p-me',
  userId: 'u-me',
  username: 'me',
  displayName: 'Me',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  personaType: 'contributor',
);

const List<Sport> _sports = <Sport>[
  Sport(id: 's-padel', nameEn: 'Padel', sportKey: 'padel'),
  Sport(id: 's-football', nameEn: 'Football', sportKey: 'football'),
];

List<ContributorEntity> _games() => <ContributorEntity>[
  ContributorEntity(
    kind: ContributorEntityKind.game,
    id: 'g-past',
    title: 'Sunday ladder',
    startAt: _now.subtract(const Duration(days: 3)),
    sportId: 's-padel',
    takesPart: true,
  ),
  ContributorEntity(
    kind: ContributorEntityKind.game,
    id: 'g-next',
    title: 'Padel doubles',
    startAt: _now.add(const Duration(days: 2)),
    sportId: 's-padel',
    isOrganiser: true,
    takesPart: true,
  ),
  ContributorEntity(
    kind: ContributorEntityKind.game,
    id: 'g-foot',
    title: 'Five-a-side',
    startAt: _now.add(const Duration(days: 4)),
    sportId: 's-football',
    takesPart: true,
  ),
];

ContributorProfileData _data({
  SourceState<List<ContributorEntity>>? games,
  SourceState<List<ContributorEntity>>? meetups,
  SourceState<List<ContributorSport>>? sports,
}) => ContributorProfileData(
  profileId: 'p-omar',
  isOwner: false,
  games: games ?? SourceData<List<ContributorEntity>>(_games()),
  meetups:
      meetups ??
      const SourceData<List<ContributorEntity>>(<ContributorEntity>[]),
  sports:
      sports ??
      const SourceData<List<ContributorSport>>(<ContributorSport>[
        ContributorSport(sportId: 's-padel', sportKey: 'padel'),
        ContributorSport(sportId: 's-football', sportKey: 'football'),
      ]),
);

late _FakeProfile _global;

// Upcoming dates can have the same text as a header count.
Finder _headerCount(String count) => find.descendant(
  of: find.byType(OwnProfileHeader),
  matching: find.text(count),
);

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// What the last pushed route carried (KAN-689 tap-through assertions).
class _Landed {
  Uri? uri;
  Map<String, String> params = const {};
  void reset() {
    uri = null;
    params = const {};
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Future<ContributorProfileData> Function()? data,
  bool blocked = false,
  bool messageOn = false,
  bool countsFail = false,
  _Landed? landed,
  bool emptyBio = false,
}) async {
  tester.view.physicalSize = const Size(393, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _global = _FakeProfile(ProfileState(profile: _me()));
  Widget stop(GoRouterState st) {
    landed?.uri = st.uri;
    landed?.params = st.pathParameters;
    return const Scaffold(body: Text('landed'));
  }

  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const UserProfileScreen(userId: 'u-omar'),
      ),
      GoRoute(
        path: '${RoutePaths.followers}/:profileId',
        name: RouteNames.followers,
        builder: (_, st) => stop(st),
      ),
      GoRoute(
        path: '${RoutePaths.following}/:profileId',
        name: RouteNames.following,
        builder: (_, st) => stop(st),
      ),
      GoRoute(path: '/:rest(.*)', builder: (_, st) => stop(st)),
    ],
  );
  addTearDown(router.dispose);
  const Locale locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        profileControllerProvider.overrideWith((ref) => _global),
        visitedProfileControllerProvider.overrideWith(
          (ref, key) =>
              _FakeProfile(ProfileState(profile: _omar(emptyBio: emptyBio))),
        ),
        visitedSportsProfileControllerProvider.overrideWith(
          (ref, key) => _FakeSports(),
        ),
        contributorProfileProvider.overrideWith(
          (ref, args) => (data ?? () async => _data())(),
        ),
        profileMessageActionFlagsProvider.overrideWithValue((
          messaging: messageOn,
          direct: messageOn,
        )),
        currentUserProvider.overrideWithValue(null),
        myProfileIdProvider.overrideWith((ref) async => 'p-me'),
        sportsProvider.overrideWith((ref) async => _sports),
        visitedFollowingCountProvider.overrideWith(
          (ref, id) async => countsFail ? throw StateError('x') : 12,
        ),
        visitedFollowersCountProvider.overrideWith(
          (ref, id) async => countsFail ? throw StateError('x') : 34,
        ),
        visitedPostsCountProvider.overrideWith(
          (ref, id) async => countsFail ? throw StateError('x') : 77,
        ),
        isFollowingProvider.overrideWith((ref, key) async => false),
        isBlockedProvider.overrideWith((ref, key) async => blocked),
        isUserBlockedProvider.overrideWith((ref, id) async => blocked),
        userPostsProvider.overrideWith((ref, key) async => []),
        userCommentedPostsProvider.overrideWith((ref, key) async => []),
        userLikedPostsProvider.overrideWith((ref, key) async => []),
        userRepostedPostsProvider.overrideWith((ref, key) async => []),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        builder: (context, child) => DabblerToastProvider(child: child!),
        routerConfig: router,
      ),
    ),
  );
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _tileValue(WidgetTester tester, Key key) =>
    tester.widget<DabblerStatTile>(find.byKey(key)).value;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  testWidgets('bento: Sport profiles alone in its row spans the full width', (
    tester,
  ) async {
    await _pump(tester);
    final Rect hero = tester.getRect(
      find.byKey(ContributorVisitorBento.heroKey),
    );
    final Rect played = tester.getRect(
      find.byKey(ContributorVisitorBento.playedKey),
    );
    final Rect sports = tester.getRect(
      find.byKey(ContributorVisitorBento.sportsKey),
    );
    expect(sports.left, hero.left);
    expect(sports.right, played.right);
    expect(sports.top, greaterThan(hero.bottom));
  });

  testWidgets('data: Contributor body, bento from the read model', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ContributorVisitorSections), findsOneWidget);
    // Three games across sports, Played counts the past one, Organised one.
    expect(_tileValue(tester, ContributorVisitorBento.heroKey), isNot('—'));
    expect(_tileValue(tester, ContributorVisitorBento.sportsKey), '2');
    // Show-up / Minutes / Partners are declared gaps: omitted, not zero.
    expect(find.byType(DabblerStatTile), findsNWidgets(4));
    // Header counters are Followers / Following / Posts, all real.
    expect(_headerCount('34'), findsOneWidget);
    expect(_headerCount('12'), findsOneWidget);
    expect(_headerCount('77'), findsOneWidget);
  });

  testWidgets('following count is distinct from an upcoming date', (
    tester,
  ) async {
    final _Landed l = _Landed();
    await _pump(
      tester,
      landed: l,
      data: () async => _data(
        games: SourceData<List<ContributorEntity>>(<ContributorEntity>[
          ContributorEntity(
            kind: ContributorEntityKind.game,
            id: 'g-day-12',
            title: 'Upcoming game',
            startAt: DateTime(_now.year, _now.month + 1, 12),
            sportId: 's-padel',
            takesPart: true,
          ),
        ]),
      ),
    );
    expect(find.text('12'), findsNWidgets(2));
    await tester.tap(_headerCount('12'));
    await settle(tester);
    expect(l.uri?.path, '${RoutePaths.following}/p-omar');
  });

  testWidgets('selecting a sport scopes the bento and drops Sport profiles', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Football').first);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(ContributorVisitorBento.sportsKey), findsNothing);
    final DabblerStatTile hero = tester.widget<DabblerStatTile>(
      find.byKey(ContributorVisitorBento.heroKey),
    );
    expect(hero.label, 'Football matches');
  });

  testWidgets('loading is a spinner, never a zero', (tester) async {
    await _pump(tester, data: () => Completer<ContributorProfileData>().future);
    expect(find.byKey(ContributorVisitorSections.loadingKey), findsOneWidget);
    expect(find.byKey(ContributorVisitorBento.heroKey), findsNothing);
  });

  testWidgets('failed games: hero is a retry, Played/Organised omitted', (
    tester,
  ) async {
    await _pump(
      tester,
      data: () async => _data(
        games: SourceFailed<List<ContributorEntity>>(StateError('x')),
        meetups: SourceFailed<List<ContributorEntity>>(StateError('x')),
      ),
    );
    expect(_tileValue(tester, ContributorVisitorBento.heroKey), '—');
    expect(find.byKey(ContributorVisitorBento.playedKey), findsNothing);
    expect(find.byKey(ContributorVisitorBento.organisedKey), findsNothing);
    expect(
      find.byKey(ContributorVisitorUpcomingFailed.retryKey),
      findsOneWidget,
    );
  });

  testWidgets('whole read failing is a retry, not a zero', (tester) async {
    await _pump(tester, data: () async => throw StateError('offline'));
    expect(tester.takeException(), isNull);
    expect(_tileValue(tester, ContributorVisitorBento.heroKey), '—');
  });

  testWidgets('sports gap: Sport profiles tile omitted, not zero', (
    tester,
  ) async {
    await _pump(
      tester,
      data: () async => _data(
        sports: const SourceGap<List<ContributorSport>>(
          ContributorGap('sports', 'unread'),
        ),
      ),
    );
    expect(find.byKey(ContributorVisitorBento.sportsKey), findsNothing);
  });

  testWidgets('Upcoming lists future public games with role tags', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Padel doubles'), findsOneWidget);
    expect(find.text('Five-a-side'), findsOneWidget);
    expect(find.text('Sunday ladder'), findsNothing);
    expect(find.text('Organising · Playing'), findsOneWidget);
    expect(find.text('Playing'), findsWidgets);
  });

  testWidgets('no owner leakage', (tester) async {
    await _pump(tester);
    expect(find.byType(ContributorGamesSections), findsNothing);
    expect(find.byType(RatingSummary), findsNothing);
    expect(find.text('Manage'), findsNothing);
    expect(find.text('Games I organise'), findsNothing);
    expect(find.text('Switch profile'), findsNothing);
  });

  testWidgets('Follow shown; Message gated by both flags; no Invite', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.byType(ProfileMessageAction), findsNothing);

    await _pump(tester, messageOn: true);
    expect(find.byType(ProfileMessageAction), findsOneWidget);
  });

  testWidgets('Invite: icon-only third button, labelled, starts nothing', (
    tester,
  ) async {
    await _pump(tester, messageOn: true);
    final Finder invite = find.byKey(ProfileInviteAction.buttonKey);
    expect(invite, findsOneWidget);
    expect(find.bySemanticsLabel('Invite'), findsWidgets);
    // Third in the row, after Follow and Message.
    expect(
      tester.getTopLeft(invite).dx,
      greaterThan(tester.getTopLeft(find.byType(ProfileMessageAction)).dx),
    );
    expect(tester.widget<DabblerButton>(invite).onPressed, isNull);
  });

  testWidgets('hero says Games played, All sports links out', (tester) async {
    await _pump(tester);
    final DabblerStatTile hero = tester.widget<DabblerStatTile>(
      find.byKey(ContributorVisitorBento.heroKey),
    );
    expect(hero.label, 'Games played');
    expect(hero.onTap, isNotNull);
  });

  testWidgets('empty bio: visitor sees no owner prompt', (tester) async {
    await _pump(tester, emptyBio: true);
    expect(
      find.text('Add a short bio so teammates know what to expect.'),
      findsNothing,
    );
  });

  testWidgets('empty bio: the owner view keeps its prompt', (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: OwnProfileHeader(
              profile: _omar(emptyBio: true),
              posts: 0,
              following: 0,
              followers: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('Add a short bio so teammates know what to expect.'),
      findsOneWidget,
    );
  });

  testWidgets('blocked shows Unblock instead of Follow', (tester) async {
    await _pump(tester, blocked: true);
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('failed counters show a retry, not 0', (tester) async {
    await _pump(tester, countsFail: true);
    expect(find.text('Retry'), findsWidgets);
    final OwnProfileHeader header = tester.widget<OwnProfileHeader>(
      find.byType(OwnProfileHeader),
    );
    expect(header.followersState, ProfileCounterState.failed);
    expect(header.postsState, ProfileCounterState.failed);
  });

  testWidgets("visiting never loads into the viewer's own controller", (
    tester,
  ) async {
    await _pump(tester);
    expect(_global.loads, 0);
    expect(_global.state.profile?.id, 'p-me');
  });

  testWidgets('copy-link pill is on the Contributor header', (tester) async {
    await _pump(tester);
    expect(find.byKey(OwnProfileHeader.copyLinkKey), findsOneWidget);
  });

  testWidgets('taps: selected-sport hero opens the visited Sport Profile', (
    tester,
  ) async {
    final _Landed l = _Landed();
    await _pump(tester, landed: l);
    await tester.tap(find.text('Football').first);
    await settle(tester);
    await tester.tap(find.byKey(ContributorVisitorBento.heroKey));
    await settle(tester);
    expect(l.uri?.path, RoutePaths.sportProfile);
    expect(l.uri?.queryParameters['profileId'], 'p-omar');
    expect(l.uri?.queryParameters['userId'], 'u-omar');
    expect(l.uri?.queryParameters['sportId'], 's-football');
  });

  testWidgets('taps: All-sports hero opens /activities (KAN-688 ruling)', (
    tester,
  ) async {
    final _Landed l = _Landed();
    await _pump(tester, landed: l);
    await tester.tap(find.byKey(ContributorVisitorBento.heroKey));
    await settle(tester);
    expect(l.uri?.path, '/activities');
  });

  testWidgets('taps: Upcoming row opens the game', (tester) async {
    final _Landed l = _Landed();
    await _pump(tester, landed: l);
    await tester.tap(find.text('Padel doubles'));
    await settle(tester);
    expect(l.uri?.path, RoutePaths.gameDetail('g-next'));
  });

  testWidgets('taps: Followers and Following push the visited profile id', (
    tester,
  ) async {
    final _Landed l = _Landed();
    await _pump(tester, landed: l);
    await tester.tap(_headerCount('34'));
    await settle(tester);
    expect(l.uri?.path, '${RoutePaths.followers}/p-omar');
    expect(l.params['profileId'], 'p-omar');
    GoRouter.of(tester.element(find.text('landed'))).pop();
    await settle(tester);
    l.reset();
    await tester.tap(_headerCount('12'));
    await settle(tester);
    expect(l.uri?.path, '${RoutePaths.following}/p-omar');
    expect(l.params['profileId'], 'p-omar');
  });
}
