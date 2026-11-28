import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart'
    show JoinActionResult;
import 'package:dabbler/features/games/presentation/controllers/join_game_feedback.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_feedback.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/sports/data/sport_follow_repository.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/data/sport_overview_repository.dart';

// infra -> repo ---------------------------------------------------------------

final sportOverviewRepositoryProvider = Provider<SportOverviewRepository>(
  (ref) => SupabaseSportOverviewRepository(ref.watch(supabaseClientProvider)),
);

final sportFollowRepositoryProvider = Provider<SportFollowRepository>(
  (ref) => SupabaseSportFollowRepository(ref.watch(supabaseClientProvider)),
);

/// Loads the posts for [ids] with their authors and counts, in the order
/// given. Its own provider so a test can stand in for the post repository.
typedef SportPostsFetcher =
    Future<Result<List<Post>, Failure>> Function(List<String> ids);

final sportPostsFetcherProvider = Provider<SportPostsFetcher>(
  (ref) =>
      (List<String> ids) =>
          ref.watch(postRepositoryProvider).getPostsByIds(ids),
);

/// The join of a game and the RSVP of a meetup, as the Games and Meetups
/// listings run them (feedback center, real RPC, real result). Their own
/// providers so a test can stand in for the server.
typedef SportGameJoiner =
    Future<Result<JoinActionResult, Failure>> Function(
      ProviderContainer container,
      String gameId,
      AppLocalizations l,
    );

final sportGameJoinerProvider = Provider<SportGameJoiner>(
  (ref) => joinGameWithFeedback,
);

typedef SportMeetupRsvper =
    Future<Result<RsvpStatus, Failure>> Function(
      ProviderContainer container,
      String meetupId,
      RsvpAction action,
      AppLocalizations l,
    );

final sportMeetupRsvpProvider = Provider<SportMeetupRsvper>(
  (ref) => rsvpWithFeedback,
);

T _unwrap<T>(Result<T, Failure> result) =>
    result.fold((e) => throw e, (v) => v);

// sport -----------------------------------------------------------------------

/// The sport of the page. An unknown id ends in an error (the page's error
/// state), never a crash.
final sportInfoProvider = FutureProvider.autoDispose.family<SportInfo, String>(
  (ref, sportId) async =>
      _unwrap(await ref.watch(sportOverviewRepositoryProvider).sport(sportId)),
);

// city ------------------------------------------------------------------------

/// A page-local City choice for one sport page; null follows the device's city.
/// It is never written anywhere: not to the device location, saved places, the
/// service region or the public profile.
final sportPageCityOverrideProvider = StateProvider.autoDispose
    .family<SportPageCity?, String>((ref, sportId) => null);

/// The city the device is set to (read only), keyed to a `ref_cities.code`
/// when the data has that city.
final sportDeviceCityProvider = FutureProvider.autoDispose<SportPageCity>((
  ref,
) async {
  final ActiveLocationState? location = ref
      .watch(activeLocationProvider)
      .valueOrNull;
  final String? name = switch (location) {
    ActiveLocationReady(:final location) => location.area.city,
    ActiveLocationCityOnly(:final city) => city,
    _ => null,
  };
  final String? trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return SportPageCity.none;
  return resolveSportCity(ref.watch(sportOverviewRepositoryProvider), trimmed);
});

/// [name] with the `ref_cities` code the data is keyed by, when there is one.
Future<SportPageCity> resolveSportCity(
  SportOverviewRepository repo,
  String name,
) async {
  final Result<String?, Failure> code = await repo.cityCode(name);
  return SportPageCity(name: name, code: code.fold((_) => null, (c) => c));
}

/// The city a sport page is showing: its own choice, else the device's.
final sportPageCityProvider = FutureProvider.autoDispose
    .family<SportPageCity, String>((ref, sportId) async {
      final SportPageCity? chosen = ref.watch(
        sportPageCityOverrideProvider(sportId),
      );
      if (chosen != null) return chosen;
      return ref.watch(sportDeviceCityProvider.future);
    });

// section data ------------------------------------------------------------------

/// One sport in one city (null code: every city).
typedef SportScope = ({String sportId, String? cityCode});

final sportOverviewCountsProvider = FutureProvider.autoDispose
    .family<SportOverviewCounts, SportScope>(
      (ref, scope) async => _unwrap(
        await ref
            .watch(sportOverviewRepositoryProvider)
            .overview(scope.sportId, scope.cityCode),
      ),
    );

final sportGamesProvider = FutureProvider.autoDispose
    .family<List<NearbyGameModel>, SportScope>(
      (ref, scope) async => _unwrap(
        await ref
            .watch(sportOverviewRepositoryProvider)
            .games(scope.sportId, scope.cityCode),
      ),
    );

final sportMeetupsProvider = FutureProvider.autoDispose
    .family<List<MeetupListItem>, SportScope>(
      (ref, scope) async => _unwrap(
        await ref
            .watch(sportOverviewRepositoryProvider)
            .meetups(scope.sportId, scope.cityCode),
      ),
    );

final sportVenuesProvider = FutureProvider.autoDispose
    .family<List<SportVenue>, SportScope>(
      (ref, scope) async => _unwrap(
        await ref
            .watch(sportOverviewRepositoryProvider)
            .venues(scope.sportId, scope.cityCode),
      ),
    );

final sportSpacesProvider = FutureProvider.autoDispose
    .family<List<SportSpace>, SportScope>(
      (ref, scope) async => _unwrap(
        await ref
            .watch(sportOverviewRepositoryProvider)
            .spaces(scope.sportId, scope.cityCode),
      ),
    );

// posts -----------------------------------------------------------------------

class SportPostsState {
  const SportPostsState({
    this.posts = const <Post>[],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.loadMoreFailed = false,
  });

  final List<Post> posts;

  /// The first page is in flight (skeleton).
  final bool loading;
  final bool loadingMore;
  final bool hasMore;

  /// The first page failed (error with Retry).
  final Failure? error;

  /// A later page failed; the posts already loaded stay.
  final bool loadMoreFailed;
}

/// The sport-tagged feed, newest first. It never applies the Following
/// filter: a sport the viewer does not follow lists its posts all the same.
class SportPostsNotifier extends StateNotifier<SportPostsState> {
  SportPostsNotifier(this._repo, this._fetch, this._sportId)
    : super(const SportPostsState()) {
    load();
  }

  final SportOverviewRepository _repo;
  final SportPostsFetcher _fetch;
  final String _sportId;

  Future<void> load() async {
    state = const SportPostsState();
    final Result<List<Post>, Failure> page = await _page(0);
    if (!mounted) return;
    state = page.fold(
      (e) => SportPostsState(loading: false, error: e),
      (posts) => SportPostsState(
        posts: posts,
        loading: false,
        hasMore: posts.length >= kSportOverviewPostsPage,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    state = SportPostsState(
      posts: state.posts,
      loading: false,
      loadingMore: true,
      hasMore: state.hasMore,
    );
    final Result<List<Post>, Failure> page = await _page(state.posts.length);
    if (!mounted) return;
    state = page.fold(
      (e) => SportPostsState(
        posts: state.posts,
        loading: false,
        hasMore: state.hasMore,
        loadMoreFailed: true,
      ),
      (more) => SportPostsState(
        posts: <Post>[...state.posts, ...more],
        loading: false,
        hasMore: more.length >= kSportOverviewPostsPage,
      ),
    );
  }

  Future<Result<List<Post>, Failure>> _page(int offset) async {
    final Result<List<String>, Failure> ids = await _repo.postIds(
      _sportId,
      offset: offset,
    );
    if (ids is Err<List<String>, Failure>) {
      return Err<List<Post>, Failure>(ids.error);
    }
    final List<String> order = ids.requireValue;
    if (order.isEmpty) return const Ok<List<Post>, Failure>(<Post>[]);
    final Result<List<Post>, Failure> posts = await _fetch(order);
    // getPostsByIds does not promise the order asked for.
    return posts.map((List<Post> list) {
      final Map<String, Post> byId = <String, Post>{
        for (final Post p in list) p.id: p,
      };
      return <Post>[
        for (final String id in order)
          if (byId[id] != null) byId[id]!,
      ];
    });
  }
}

final sportPostsProvider = StateNotifierProvider.autoDispose
    .family<SportPostsNotifier, SportPostsState, String>(
      (ref, sportId) => SportPostsNotifier(
        ref.watch(sportOverviewRepositoryProvider),
        ref.watch(sportPostsFetcherProvider),
        sportId,
      ),
    );

// follow / my sports -----------------------------------------------------------

/// The sport-page write a [SportFollowState] is about.
enum SportWrite { follow, unfollow, addToMySports, removeFromMySports }

class SportFollowState {
  const SportFollowState({
    this.busy = false,
    this.busyWrite,
    this.error,
    this.write,
    this.notice,
  });

  final bool busy;

  /// The write in flight (which button spins).
  final SportWrite? busyWrite;

  /// The last attempt failed; nothing flipped. Retry repeats [write].
  final Failure? error;

  /// The write [error] or [notice] is about.
  final SportWrite? write;

  /// What the last write ended in, to toast (a refusal or a My sports
  /// change). Null when there is nothing to say.
  final SportFollowOutcome? notice;
}

/// The identity of a sport for [mySportCardProvider].
typedef SportRef = ({String id, String? key});

SportRef sportRefOf(SportInfo s) => (id: s.id, key: s.sportKey);

/// KAN-1060: the active persona's card for a sport (In my sports when not
/// [MySportCard.none]).
final mySportCardProvider = FutureProvider.autoDispose
    .family<MySportCard, SportRef>((ref, sport) async {
      final String? profileId = ref.watch(
        profileControllerProvider.select((s) => s.profile?.id),
      );
      if (profileId == null) return MySportCard.none;
      return _unwrap(
        await ref
            .watch(sportOverviewRepositoryProvider)
            .mySportCard(
              profileId,
              SportInfo(id: sport.id, nameEn: '', sportKey: sport.key),
            ),
      );
    });

class SportFollowController extends StateNotifier<SportFollowState> {
  SportFollowController(this._ref) : super(const SportFollowState());

  final Ref _ref;

  /// Whether the active persona follows [sportId], from its profile.
  bool isFollowing(String sportId) =>
      _ref
          .read(profileControllerProvider)
          .profile
          ?.interests
          ?.contains(sportId) ??
      false;

  Future<String?> _profileId() async {
    var profile = _ref.read(profileControllerProvider).profile;
    if (profile == null) {
      // Not loaded yet (page opened from a link, outside the shell): load the
      // active profile before deciding (KAN-970).
      await _ref.read(initializeProfileDataProvider.future);
      if (!mounted) return null;
      profile = _ref.read(profileControllerProvider).profile;
    }
    return profile?.id;
  }

  /// Follows or unfollows [sport] on the active persona. The profile is
  /// reloaded after a write, so the button (which reads the profile) flips
  /// only once the write succeeded.
  Future<void> toggle(SportInfo sport) async {
    if (state.busy) return;
    final String? id = await _profileId();
    if (id == null || !mounted) return;
    await run(
      isFollowing(sport.id) ? SportWrite.unfollow : SportWrite.follow,
      sport,
      profileId: id,
    );
  }

  /// Adds [sport] to My sports, or removes it when [inMySports].
  Future<void> toggleMySports(
    SportInfo sport, {
    required bool inMySports,
  }) async {
    if (state.busy) return;
    final String? id = await _profileId();
    if (id == null || !mounted) return;
    await run(
      inMySports ? SportWrite.removeFromMySports : SportWrite.addToMySports,
      sport,
      profileId: id,
    );
  }

  /// Repeats write [w] (the Retry of a failed one).
  Future<void> retry(SportWrite w, SportInfo sport) async {
    final String? id = await _profileId();
    if (id == null || !mounted) return;
    await run(w, sport, profileId: id);
  }

  Future<void> run(
    SportWrite write,
    SportInfo sport, {
    required String profileId,
  }) async {
    if (state.busy) return;
    state = SportFollowState(busy: true, busyWrite: write);
    final SportFollowRepository repo = _ref.read(sportFollowRepositoryProvider);
    final Result<SportFollowOutcome, Failure> result = switch (write) {
      SportWrite.follow => await repo.follow(profileId, sport),
      SportWrite.unfollow => await repo.unfollow(profileId, sport),
      SportWrite.addToMySports => await repo.addToMySports(profileId, sport),
      SportWrite.removeFromMySports => await repo.removeFromMySports(
        profileId,
        sport,
      ),
    };
    if (!mounted) return;
    await result.fold(
      (e) async => state = SportFollowState(error: e, write: write),
      (outcome) async {
        final bool wrote = switch (outcome) {
          SportFollowOutcome.followed ||
          SportFollowOutcome.unfollowed ||
          SportFollowOutcome.added ||
          SportFollowOutcome.removed ||
          SportFollowOutcome.levelSet => true,
          _ => false,
        };
        if (wrote) {
          await _ref.read(profileControllerProvider.notifier).refreshProfile();
          // KAN-1030: the counts are server-side; re-read them.
          _ref.invalidate(sportOverviewCountsProvider);
          _ref.invalidate(mySportCardProvider);
        }
        if (!mounted) return;
        state = SportFollowState(
          notice:
              outcome == SportFollowOutcome.followed ||
                  outcome == SportFollowOutcome.unfollowed ||
                  outcome == SportFollowOutcome.unchanged
              ? null
              : outcome,
          write: write,
        );
      },
    );
  }

  void clearNotice() {
    if (state.error != null || state.notice != null) {
      state = const SportFollowState();
    }
  }
}

final sportFollowControllerProvider =
    StateNotifierProvider.autoDispose<SportFollowController, SportFollowState>(
      (ref) => SportFollowController(ref),
    );
