import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/data/models/search/comment_search_result.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';

/// Aggregated result from the unified search RPC
/// (`rpc_unified_search_sectioned`).
///
/// Each list is populated only for the entity types that were requested
/// (based on the search [mode]). Empty lists are used — never null — so
/// the UI can safely read `.isEmpty`.
class SearchResultBundle {
  final List<Profile> profiles;
  final List<GameModel> games;
  final List<Venue> venues;
  final List<PostSearchResult> posts;
  final List<CommentSearchResult> comments;
  final List<HashtagSearchResult> hashtags;
  final List<MeetupSearchResult> meetups;

  const SearchResultBundle({
    this.profiles = const [],
    this.games = const [],
    this.venues = const [],
    this.posts = const [],
    this.comments = const [],
    this.hashtags = const [],
    this.meetups = const [],
  });

  bool get hasResults =>
      profiles.isNotEmpty ||
      games.isNotEmpty ||
      venues.isNotEmpty ||
      posts.isNotEmpty ||
      comments.isNotEmpty ||
      hashtags.isNotEmpty ||
      meetups.isNotEmpty;

  int get totalCount =>
      profiles.length +
      games.length +
      venues.length +
      posts.length +
      comments.length +
      hashtags.length +
      meetups.length;

  static const empty = SearchResultBundle();
}
