import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'post_providers.dart';

// =============================================================================
// FEED STATE
// =============================================================================

class FeedState {
  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.hasNewPosts = false,
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  /// True when the realtime subscription has prepended new posts and the user
  /// hasn't yet acknowledged the indicator.
  final bool hasNewPosts;

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _sentinel,
    bool? hasNewPosts,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
      hasNewPosts: hasNewPosts ?? this.hasNewPosts,
    );
  }

  static const Object _sentinel = Object();
}

// =============================================================================
// FEED NOTIFIER
// =============================================================================

/// Manages the home feed with Supabase Realtime subscriptions.
///
/// On instantiation it:
///   1. Opens a Realtime channel and subscribes to INSERT/DELETE events on
///      [posts], [post_likes], [post_comments], and [post_reactions].
///   2. Calls [load] to fetch the initial page.
///
/// New post events prepend the post to the list and set [FeedState.hasNewPosts].
/// Like / comment / reaction events re-fetch the affected post in-place so
/// counts update automatically.
class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._repo, this._db) : super(const FeedState()) {
    _subscribeRealtime();
    load();
  }

  final PostRepository _repo;
  final SupabaseClient _db;
  RealtimeChannel? _channel;

  static const int _pageSize = 20;
  int _activePage = 0;
  bool _channelReady = false;

  // ── Realtime ────────────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    _channel = _db
        .channel('home_feed_rt')
        // postgres_changes: new posts
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: _onNewPost,
        )
        // postgres_changes: deleted posts
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'posts',
          callback: _onPostDeleted,
        )
        // postgres_changes: posts row updated (counter triggers)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: _onPostUpdated,
        )
        // broadcast: cross-device interaction updates (bypasses RLS)
        .onBroadcast(
          event: 'post_updated',
          callback: (payload) {
            final postId = payload['post_id'] as String?;
            debugPrint('[FeedRT] broadcast received: post_id=$postId');
            if (postId != null && mounted) refreshPost(postId);
          },
        )
        .subscribe((status, error) {
          _channelReady = (status == RealtimeSubscribeStatus.subscribed);
          debugPrint(
            '[FeedRT] channel status: $status | error: $error'
            ' | ready: $_channelReady',
          );
        });
  }

  void _onPostDeleted(PostgresChangePayload payload) {
    final postId = payload.oldRecord['id'] as String?;
    if (postId == null || !mounted) return;
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  Future<void> _onNewPost(PostgresChangePayload payload) async {
    final postId = payload.newRecord['id'] as String?;
    if (postId == null || !mounted) return;

    // Skip duplicates (own post may already be appended optimistically).
    if (state.posts.any((p) => p.id == postId)) return;

    final result = await _repo.getPost(postId);
    if (!mounted) return;

    result.fold(
      (_) => null, // silently ignore fetch errors
      (post) => state = state.copyWith(
        posts: [post, ...state.posts],
        hasNewPosts: true,
      ),
    );
  }

  void _onPostUpdated(PostgresChangePayload payload) {
    final postId = payload.newRecord['id'] as String?;
    if (postId == null || !mounted) return;
    // Always re-fetch so enriched fields (sport, vibes) are preserved.
    refreshPost(postId);
  }

  /// Sends a broadcast on the channel so ALL other connected devices refresh
  /// [postId]. Also refreshes locally so the sender sees updated counts.
  Future<void> broadcastPostUpdate(String postId) async {
    // Refresh locally on the acting device immediately.
    unawaited(refreshPost(postId));
    if (!_channelReady) {
      debugPrint('[FeedRT] broadcast skipped — channel not ready yet');
      return;
    }
    final result = await _channel?.sendBroadcastMessage(
      event: 'post_updated',
      payload: {'post_id': postId},
    );
    debugPrint('[FeedRT] broadcast sent: post_id=$postId result=$result');
  }

  /// Re-fetches [postId] and replaces its entry in [state.posts] in-place.
  Future<void> refreshPost(String postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return; // post isn't in the current feed

    final result = await _repo.getPost(postId);
    if (!mounted) return;

    result.fold((_) => null, (updated) {
      final newList = List<Post>.from(state.posts);
      newList[idx] = updated;
      state = state.copyWith(posts: newList);
    });
  }

  // ── Pagination ──────────────────────────────────────────────────────────────

  /// Load first page from scratch (also used for pull-to-refresh).
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    _activePage = 0;

    final result = await _repo.getHomeFeed(limit: _pageSize, offset: 0);
    if (!mounted) return;

    result.fold(
      (err) => state = state.copyWith(isLoading: false, error: err.message),
      (posts) => state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: posts.length >= _pageSize,
        hasNewPosts: false,
      ),
    );
  }

  /// Load the next page and append unique posts.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || !mounted) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = _activePage + 1;

    final result = await _repo.getHomeFeed(
      limit: _pageSize,
      offset: nextPage * _pageSize,
    );
    if (!mounted) return;

    result.fold((_) => state = state.copyWith(isLoadingMore: false), (
      newPosts,
    ) {
      if (newPosts.isEmpty) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }
      _activePage = nextPage;
      final existingIds = state.posts.map((p) => p.id).toSet();
      final deduped = newPosts
          .where((p) => !existingIds.contains(p.id))
          .toList();
      state = state.copyWith(
        posts: [...state.posts, ...deduped],
        isLoadingMore: false,
        hasMore: newPosts.length >= _pageSize && deduped.isNotEmpty,
      );
    });
  }

  /// Dismiss the new-posts badge without navigating anywhere.
  void clearNewPostsBadge() {
    if (state.hasNewPosts) state = state.copyWith(hasNewPosts: false);
  }

  @override
  void dispose() {
    if (_channel != null) {
      _db.removeChannel(_channel!);
      _channel = null;
    }
    super.dispose();
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

/// Global real-time aware home-feed provider.
///
/// NOT autoDispose — we want the subscription and post cache to persist across
/// tab switches; the notifier unsubscribes when the widget tree is torn down.
final feedNotifierProvider = StateNotifierProvider<FeedNotifier, FeedState>((
  ref,
) {
  final repo = ref.watch(postRepositoryProvider);
  final db = Supabase.instance.client;
  return FeedNotifier(repo, db);
});
