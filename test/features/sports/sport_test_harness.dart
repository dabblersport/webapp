/// KAN-622: shared harness for the Sport Overview tests. Every data source is
/// faked: the repository contract of KAN-621's `rpc_sport_overview` is covered
/// here with fakes; live QA waits for the migration to be applied.
library;

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart'
    show JoinActionResult;
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/sports/data/sport_follow_repository.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/data/sport_overview_repository.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/features/sports/presentation/screens/sport_overview_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerToastProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const String kFootball = '4fd36109-12c2-4b17-a8a2-281be2b8649c';
const String kTennis = '5a3bf560-70c2-4be9-ad35-6fc4cbf33b16';

const SportInfo kFootballInfo = SportInfo(
  id: kFootball,
  nameEn: 'Football',
  nameAr: 'كرة القدم',
  sportKey: 'football',
  formatsEn: <String>['5-a-side', '7-a-side'],
  formatsAr: <String>['خماسي', 'سباعي'],
);

SportOverviewCounts counts({
  int followers = 1204,
  int games = 3,
  int meetups = 2,
  int venues = 4,
  int spaces = 9,
  int posts = 17,
  List<MutualFollower> mutual = const <MutualFollower>[],
}) => SportOverviewCounts(
  followers: followers,
  gamesNext7: games,
  meetupsNext7: meetups,
  venues: venues,
  spaces: spaces,
  posts: posts,
  news: 0,
  mutualFollowers: mutual,
);

NearbyGameModel game(
  String id, {
  String title = 'Friday five-a-side',
  double? price,
  int? spots = 4,
  int players = 6,
}) => NearbyGameModel(
  id: id,
  title: title,
  sportName: 'Football',
  scheduledAt: DateTime.now().add(const Duration(days: 1)),
  status: 'upcoming',
  venueName: 'Al Wasl Club',
  distanceMeters: 0,
  playerCount: players,
  spotsRemaining: spots,
  isPublic: true,
  priceAed: price,
);

MeetupListItem meetup(String id, {String title = 'Sunday kickabout'}) =>
    MeetupListItem(
      id: id,
      title: title,
      startAt: DateTime.now().add(const Duration(days: 2)),
      rsvpPolicy: RsvpPolicy.open,
      sportId: kFootball,
      sportNameEn: 'Football',
      areaName: 'Jumeirah',
    );

Post post(String id, {String body = 'Who is in for Friday?'}) => Post(
  id: id,
  authorProfileId: 'prof-$id',
  authorUserId: 'user-$id',
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  body: body,
  sport: 'Football',
  sportId: kFootball,
  tags: const <String>[],
  likeCount: 1,
  commentCount: 0,
  repostCount: 0,
  allowReposts: true,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  updatedAt: DateTime.now(),
);

/// A repository whose answers each test sets; every call is recorded.
class FakeSportOverviewRepository implements SportOverviewRepository {
  Result<SportInfo, Failure> sportResult = const Ok(kFootballInfo);
  Result<SportOverviewCounts, Failure> overviewResult = Ok(counts());
  Result<List<NearbyGameModel>, Failure> gamesResult = const Ok(
    <NearbyGameModel>[],
  );
  Result<List<MeetupListItem>, Failure> meetupsResult = const Ok(
    <MeetupListItem>[],
  );
  Result<List<SportVenue>, Failure> venuesResult = const Ok(<SportVenue>[]);
  Result<List<SportSpace>, Failure> spacesResult = const Ok(<SportSpace>[]);
  Result<List<String>, Failure> postIdsResult = const Ok(<String>[]);
  Result<bool, Failure> hasProfileResult = const Ok(true);
  Result<void, Failure> createProfileResult = const Ok(null);

  /// `ref_cities.code` by city name; a name not listed is unmapped.
  final Map<String, String> cityCodes = <String, String>{'Dubai': 'dubai'};

  /// When set, `overview` waits for it (a slow or hanging call).
  Completer<void>? overviewGate;

  final List<String> calls = <String>[];
  final List<String?> overviewCities = <String?>[];
  final List<String> createdProfiles = <String>[];
  int overviewCalls = 0;
  int gamesCalls = 0;

  @override
  Future<Result<SportInfo, Failure>> sport(String sportId) async {
    calls.add('sport:$sportId');
    return sportResult;
  }

  @override
  Future<Result<SportOverviewCounts, Failure>> overview(
    String sportId,
    String? cityCode,
  ) async {
    overviewCalls++;
    overviewCities.add(cityCode);
    calls.add('overview:$sportId:${cityCode ?? 'all'}');
    await overviewGate?.future;
    return overviewResult;
  }

  @override
  Future<Result<String?, Failure>> cityCode(String cityName) async =>
      Ok(cityCodes[cityName]);

  @override
  Future<Result<List<NearbyGameModel>, Failure>> games(
    String sportId,
    String? cityCode,
  ) async {
    gamesCalls++;
    calls.add('games:$sportId:${cityCode ?? 'all'}');
    return gamesResult;
  }

  @override
  Future<Result<List<MeetupListItem>, Failure>> meetups(
    String sportId,
    String? cityCode,
  ) async {
    calls.add('meetups:$sportId:${cityCode ?? 'all'}');
    return meetupsResult;
  }

  @override
  Future<Result<List<SportVenue>, Failure>> venues(
    String sportId,
    String? cityCode,
  ) async {
    calls.add('venues:$sportId:${cityCode ?? 'all'}');
    return venuesResult;
  }

  @override
  Future<Result<List<SportSpace>, Failure>> spaces(
    String sportId,
    String? cityCode,
  ) async {
    calls.add('spaces:$sportId:${cityCode ?? 'all'}');
    return spacesResult;
  }

  @override
  Future<Result<List<String>, Failure>> postIds(
    String sportId, {
    int offset = 0,
    int limit = kSportOverviewPostsPage,
  }) async {
    calls.add('postIds:$sportId:$offset');
    return postIdsResult;
  }

  @override
  Future<Result<bool, Failure>> hasSportProfile(
    String profileId,
    SportInfo sport,
  ) async => hasProfileResult;

  @override
  Future<Result<void, Failure>> createSportProfile(
    String profileId,
    SportInfo sport,
  ) async {
    createdProfiles.add('$profileId:${sport.id}');
    return createProfileResult;
  }
}

/// Follow / Unfollow whose outcome each test sets. A real implementation would
/// write `profiles.interests`; this one records what was asked.
class FakeSportFollowRepository implements SportFollowRepository {
  Result<SportFollowOutcome, Failure> followResult = const Ok(
    SportFollowOutcome.followed,
  );
  Result<SportFollowOutcome, Failure> unfollowResult = const Ok(
    SportFollowOutcome.unfollowed,
  );
  final List<String> follows = <String>[];
  final List<String> unfollows = <String>[];

  @override
  Future<Result<SportFollowOutcome, Failure>> follow(
    String profileId,
    SportInfo sport,
  ) async {
    follows.add('$profileId:${sport.id}');
    return followResult;
  }

  @override
  Future<Result<SportFollowOutcome, Failure>> unfollow(
    String profileId,
    SportInfo sport,
  ) async {
    unfollows.add('$profileId:${sport.id}');
    return unfollowResult;
  }
}

/// The signed-in persona. `refreshProfile` applies what the fake follow
/// repository "wrote", so the Follow button flips only after a write.
class FakeProfileController extends StateNotifier<ProfileState>
    implements ProfileController {
  FakeProfileController(List<String> interests)
    : super(ProfileState(profile: _profile(interests)));

  /// What the next refresh loads.
  List<String>? interestsOnRefresh;
  int refreshes = 0;

  static UserProfile _profile(List<String> interests) => UserProfile(
    id: 'me',
    userId: 'user-me',
    displayName: 'Me',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    personaType: 'player',
    profileType: 'player',
    interests: interests,
  );

  @override
  Future<void> refreshProfile() async {
    refreshes++;
    final List<String>? next = interestsOnRefresh;
    if (next != null) state = ProfileState(profile: _profile(next));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocation extends ActiveLocationNotifier {
  FakeLocation(this.city);

  /// Null: no location (the manual-city CTA state).
  final String? city;
  int manualCityCalls = 0;

  @override
  Future<ActiveLocationState> build() async => city == null
      ? ActiveLocationDenied()
      : ActiveLocationReady(
          ActiveLocation(
            lat: 25.2,
            lng: 55.3,
            area: Area(
              id: 'a1',
              name: 'Marina',
              district: city!,
              city: city!,
              country: 'AE',
              centerLat: 25.2,
              centerLng: 55.3,
            ),
            source: ActiveLocationSource.manual,
          ),
        );

  @override
  Future<void> useManualCity(
    String city, {
    String? cityId,
    String? country,
    String? countryCode,
  }) async {
    // The page-local City must never reach here: counting is the assertion.
    manualCityCalls++;
  }
}

class SportHarness {
  SportHarness({
    List<String> following = const <String>[],
    String? city = 'Dubai',
  }) : profile = FakeProfileController(following),
       location = FakeLocation(city);

  final FakeSportOverviewRepository repo = FakeSportOverviewRepository();
  final FakeSportFollowRepository follow = FakeSportFollowRepository();
  final FakeProfileController profile;
  final FakeLocation location;
  final List<String> pushed = <String>[];
  final List<String> joinedGames = <String>[];
  final List<String> rsvpMeetups = <String>[];
  List<Post> postsToReturn = const <Post>[];
}

/// Pumps [SportOverviewScreen] for [sportId] with every source faked.
Future<void> pumpSport(
  WidgetTester tester,
  SportHarness h, {
  String sportId = kFootball,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => SportOverviewScreen(sportId: sportId),
      ),
      GoRoute(
        path: '/:rest(.*)',
        builder: (_, GoRouterState s) {
          h.pushed.add(s.uri.toString());
          return const SizedBox.shrink();
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sportOverviewRepositoryProvider.overrideWithValue(h.repo),
        sportFollowRepositoryProvider.overrideWithValue(h.follow),
        sportPostsFetcherProvider.overrideWithValue(
          (List<String> ids) async => Ok<List<Post>, Failure>(h.postsToReturn),
        ),
        sportGameJoinerProvider.overrideWithValue((container, id, l) async {
          h.joinedGames.add(id);
          return const Ok<JoinActionResult, Failure>(JoinActionResult.joined);
        }),
        sportMeetupRsvpProvider.overrideWithValue((container, id, a, l) async {
          h.rsvpMeetups.add(id);
          return const Ok<RsvpStatus, Failure>(RsvpStatus.going);
        }),
        profileControllerProvider.overrideWith((ref) => h.profile),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        activeLocationProvider.overrideWith(() => h.location),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        hasLikedProvider.overrideWith((ref, id) async => false),
        hasRepostedProvider.overrideWith((ref, id) async => false),
        myReactionsProvider.overrideWith((ref, id) async => <String>{}),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => []),
        latestCommentProvider.overrideWith((ref, id) async => null),
        ...overrides,
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (BuildContext context, Widget? child) =>
            DabblerToastProvider(child: child!),
        routerConfig: router,
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
  await settle(tester);
}

/// Lets futures, the debounce and the page's animations land.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
