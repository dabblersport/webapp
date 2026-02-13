import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/post.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/repositories/search_repository.dart';
import 'package:dabbler/data/repositories/search_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return SearchRepositoryImpl(svc);
});

// ---------------------------------------------------------------------------
// Search state
// ---------------------------------------------------------------------------

class SearchState {
  final String query;
  final bool isLoading;
  final String? error;
  final List<Profile> profiles;
  final List<Post> posts;
  final List<GameModel> games;
  final List<Venue> venues;

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.error,
    this.profiles = const [],
    this.posts = const [],
    this.games = const [],
    this.venues = const [],
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    String? error,
    List<Profile>? profiles,
    List<Post>? posts,
    List<GameModel>? games,
    List<Venue>? venues,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      profiles: profiles ?? this.profiles,
      posts: posts ?? this.posts,
      games: games ?? this.games,
      venues: venues ?? this.venues,
    );
  }

  bool get hasResults =>
      profiles.isNotEmpty ||
      posts.isNotEmpty ||
      games.isNotEmpty ||
      venues.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._repo) : super(const SearchState());

  final SearchRepository _repo;

  /// Run a search across all categories in parallel.
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(query: trimmed, isLoading: true, error: null);

    // Fire all four searches in parallel.
    final profilesFut = _repo.searchProfiles(query: trimmed);
    final postsFut = _repo.searchPosts(query: trimmed);
    final gamesFut = _repo.searchGames(query: trimmed);
    final venuesFut = _repo.searchVenues(query: trimmed);

    final profilesResult = await profilesFut;
    final postsResult = await postsFut;
    final gamesResult = await gamesFut;
    final venuesResult = await venuesFut;

    List<Profile> profiles = [];
    List<Post> posts = [];
    List<GameModel> games = [];
    List<Venue> venues = [];
    String? firstError;

    // Unpack results — use data where available, collect first error.
    profilesResult.fold(
      (f) => firstError ??= f.message,
      (data) => profiles = data,
    );
    postsResult.fold((f) => firstError ??= f.message, (data) => posts = data);
    gamesResult.fold((f) => firstError ??= f.message, (data) => games = data);
    venuesResult.fold((f) => firstError ??= f.message, (data) => venues = data);

    state = SearchState(
      query: trimmed,
      isLoading: false,
      error: firstError,
      profiles: profiles,
      posts: posts,
      games: games,
      venues: venues,
    );
  }

  void clear() => state = const SearchState();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  final repo = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repo);
});
