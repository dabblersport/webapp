import 'package:meta/meta.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/search/comment_search_result.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/data/models/search/search_result_bundle.dart';
import 'base_repository.dart';
import 'search_repository.dart';

@immutable
class SearchRepositoryImpl extends BaseRepository implements SearchRepository {
  const SearchRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;

  /// The authenticated user's ID – used to exclude "self" from profile results.
  String? get _currentUserId => _db.auth.currentUser?.id;

  @override
  Future<Result<SearchResultBundle, Failure>> unifiedSearch({
    required String query,
    required SearchMode mode,
    int limit = 20,
  }) async {
    return guard<SearchResultBundle>(() async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return SearchResultBundle.empty;

      // The DB function accepts only p_query and p_limit_per_section.
      // Mode-based filtering is handled client-side after parsing the response.
      final raw = await _db.rpc(
        'rpc_unified_search_sectioned',
        params: {'p_query': trimmed, 'p_limit_per_section': limit},
      );

      // ignore: avoid_print
      print('UNIFIED SEARCH RAW RESPONSE type=${raw.runtimeType}: $raw');

      // The RPC returns a single JSON object keyed by section name:
      //   { "profiles": [...], "games": [...], "posts": [...], ... }
      if (raw == null) return SearchResultBundle.empty;

      final Map<String, dynamic> sectionMap;
      if (raw is Map) {
        sectionMap = Map<String, dynamic>.from(raw);
      } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
        // Fallback: some PostgREST versions wrap single-row results in a list.
        sectionMap = Map<String, dynamic>.from(raw.first as Map);
      } else {
        return SearchResultBundle.empty;
      }

      final bundle = _parseSectionMap(sectionMap);

      // ignore: avoid_print
      print('RAW COMMENTS SECTION: ${sectionMap['comments']}');

      // Client-side mode filter: when the user typed a prefix (e.g. @, #, /g)
      // we only surface the relevant section(s) and clear the rest so the UI
      // auto-switches to the correct tab.
      return _filterByMode(bundle, mode);
    });
  }

  /// Zeroes out sections that are irrelevant for the given [mode].
  /// When mode is [SearchMode.all] the full bundle is returned unchanged.
  SearchResultBundle _filterByMode(SearchResultBundle bundle, SearchMode mode) {
    switch (mode) {
      case SearchMode.all:
        return bundle;
      case SearchMode.profiles:
        return SearchResultBundle(profiles: bundle.profiles);
      case SearchMode.games:
        return SearchResultBundle(games: bundle.games);
      case SearchMode.venues:
        return SearchResultBundle(venues: bundle.venues);
      case SearchMode.posts:
        return SearchResultBundle(posts: bundle.posts);
      case SearchMode.comments:
        return SearchResultBundle(comments: bundle.comments);
      case SearchMode.hashtags:
        return SearchResultBundle(hashtags: bundle.hashtags);
      case SearchMode.meetups:
        return SearchResultBundle(meetups: bundle.meetups);
    }
  }

  // ---------------------------------------------------------------------------
  // RPC response → bundle
  // ---------------------------------------------------------------------------

  /// Parses the sectioned map returned by [rpc_unified_search_sectioned].
  ///
  /// Expected shape (keys are section names, values are result arrays):
  /// ```json
  /// {
  ///   "profiles":  [ { ... }, ... ],
  ///   "games":     [ { ... }, ... ],
  ///   "venues":    [ { ... }, ... ],
  ///   "posts":     [ { ... }, ... ],
  ///   "comments":  [ { ... }, ... ],
  ///   "hashtags":  [ { ... }, ... ],
  ///   "meetups":   [ { ... }, ... ]
  /// }
  /// ```
  SearchResultBundle _parseSectionMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> rows(String key) => ((map[key] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final profileRows = rows('profiles');
    final gameRows = rows('games');
    final venueRows = rows('venues');
    final postRows = rows('posts');
    final commentRows = rows('comments');
    final hashtagRows = rows('hashtags');
    final meetupRows = rows('meetups');

    // ignore: avoid_print
    print('RAW PROFILES: $profileRows');
    // ignore: avoid_print
    print('RAW COMMENTS: $commentRows');
    // ignore: avoid_print
    print('RAW HASHTAGS: $hashtagRows');

    return SearchResultBundle(
      profiles: profileRows
          .map((r) {
            try {
              // The RPC returns unified fields → map to Profile's expected keys.
              final mapped = <String, dynamic>{
                'id': r['profile_id'] ?? r['entity_id'] ?? r['id'] ?? '',
                'user_id': r['entity_id'] ?? r['id'] ?? '',
                'profile_type': r['profile_type'] ?? 'player',
                'username': r['subtitle'] ?? r['username'] ?? '',
                'display_name': r['title'] ?? r['display_name'] ?? '',
                'avatar_url': r['image_url'] ?? r['avatar_url'],
                'is_active': r['is_active'],
              };
              return Profile.fromJson(mapped);
            } catch (e) {
              // ignore: avoid_print
              print('PARSE ERROR for Profile: $e');
              // ignore: avoid_print
              print('ROW: $r');
              return null;
            }
          })
          .whereType<Profile>()
          // Exclude the current user's profile from results.
          .where((p) => p.userId != _currentUserId)
          .toList(),
      games: gameRows
          .map((r) {
            try {
              // The RPC returns unified fields → map to GameModel's expected keys.
              final mapped = <String, dynamic>{
                'id': r['entity_id'] ?? r['id'] ?? '',
                'title': r['title'] ?? 'Untitled Game',
                'description': r['subtitle'] ?? r['description'] ?? '',
                'sport': r['sport'] ?? 'general',
                'start_at': r['start_at'] ?? DateTime.now().toIso8601String(),
                'end_at': r['end_at'],
                'host_user_id': r['host_user_id'] ?? '',
                'capacity': r['capacity'] ?? 10,
                'listing_visibility': r['listing_visibility'] ?? 'public',
                'is_cancelled': r['is_cancelled'] ?? false,
                'created_at':
                    r['created_at'] ?? DateTime.now().toIso8601String(),
                'updated_at':
                    r['updated_at'] ?? DateTime.now().toIso8601String(),
              };
              return GameModel.fromJson(mapped);
            } catch (e) {
              // ignore: avoid_print
              print('PARSE ERROR for GameModel: $e');
              // ignore: avoid_print
              print('ROW: $r');
              return null;
            }
          })
          .whereType<GameModel>()
          .toList(),
      venues: venueRows
          .map((r) {
            try {
              // The RPC returns unified fields → map to Venue's expected keys.
              final mapped = <String, dynamic>{
                'id': r['entity_id'] ?? r['id'] ?? '',
                'name': r['title'] ?? r['name'] ?? '',
                'district': r['subtitle'] ?? r['district'],
                'address': r['address'],
              };
              return Venue.fromJson(mapped);
            } catch (e) {
              // ignore: avoid_print
              print('PARSE ERROR for Venue: $e');
              // ignore: avoid_print
              print('ROW: $r');
              return null;
            }
          })
          .whereType<Venue>()
          .toList(),
      posts: postRows
          .map((r) {
            try {
              return PostSearchResult.fromJson(r);
            } catch (e) {
              // ignore: avoid_print
              print('PARSE ERROR for PostSearchResult: $e');
              // ignore: avoid_print
              print('ROW: $r');
              return null;
            }
          })
          .whereType<PostSearchResult>()
          .toList(),
      comments: commentRows
          .map((r) {
            try {
              return CommentSearchResult.fromJson(r);
            } catch (e) {
              // ignore: avoid_print
              print('PARSE ERROR for CommentSearchResult: $e');
              // ignore: avoid_print
              print('ROW: $r');
              return null;
            }
          })
          .whereType<CommentSearchResult>()
          .toList(),
      hashtags: hashtagRows
          .map((r) {
            try {
              return HashtagSearchResult.fromJson(r);
            } catch (e) {
              // ignore: avoid_print
              print('PARSE ERROR for HashtagSearchResult: $e');
              // ignore: avoid_print
              print('ROW: $r');
              return null;
            }
          })
          .whereType<HashtagSearchResult>()
          .toList(),
      meetups: meetupRows
          .map((r) {
            try {
              return MeetupSearchResult.fromJson(r);
            } catch (e) {
              // ignore: avoid_print
              print('PARSE ERROR for MeetupSearchResult: $e');
              // ignore: avoid_print
              print('ROW: $r');
              return null;
            }
          })
          .whereType<MeetupSearchResult>()
          .toList(),
    );
  }
}
