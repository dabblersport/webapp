import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'post_providers.dart';

// =============================================================================
// FEED STATE
// =============================================================================

class FeedState {
  const FeedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.hasNewPosts = false,
    this.cursor,
  });

  final List<FeedItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  /// True when the realtime subscription has prepended new items and the user
  /// hasn't yet acknowledged the indicator.
  final bool hasNewPosts;

  /// Cursor for next page — `created_at` of last fetched row from the RPC.
  final DateTime? cursor;

  FeedState copyWith({
    List<FeedItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _sentinel,
    bool? hasNewPosts,
    Object? cursor = _sentinel,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
      hasNewPosts: hasNewPosts ?? this.hasNewPosts,
      cursor: cursor == _sentinel ? this.cursor : cursor as DateTime?,
    );
  }

  static const Object _sentinel = Object();
}

// =============================================================================
// FEED NOTIFIER
// =============================================================================

/// Manages the home feed using the `get_home_feed` RPC with cursor pagination.
///
/// On instantiation it:
///   1. Opens a Realtime channel subscribed to INSERT/DELETE/UPDATE on [posts].
///   2. Calls [load] to fetch the initial page via [get_home_feed].
class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier(this._repo, this._db) : super(const FeedState()) {
    _subscribeRealtime();
    load();
  }

  final PostRepository _repo;
  final SupabaseClient _db;
  RealtimeChannel? _channel;

  static const int _pageSize = 20;
  bool _channelReady = false;

  // ── Realtime ────────────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    _channel = _db
        .channel('home_feed_rt:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: _onNewPost,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'posts',
          callback: _onPostDeleted,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: _onPostUpdated,
        )
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
          debugPrint('[FeedRT] status: $status | error: $error');
        });
  }

  void _onPostDeleted(PostgresChangePayload payload) {
    final postId = payload.oldRecord['id'] as String?;
    if (postId == null || !mounted) return;
    state = state.copyWith(
      items: state.items.where((item) {
        if (item is FeedPostItem) return item.post.id != postId;
        return true;
      }).toList(),
    );
  }

  Future<void> _onNewPost(PostgresChangePayload payload) async {
    final postId = payload.newRecord['id'] as String?;
    if (postId == null || !mounted) return;

    final alreadyExists = state.items.any(
      (item) => item is FeedPostItem && item.post.id == postId,
    );
    if (alreadyExists) return;

    final result = await _repo.getPostsByIds([postId]);
    if (!mounted) return;

    result.fold((_) => null, (posts) {
      if (posts.isEmpty) return;
      state = state.copyWith(
        items: [FeedPostItem(posts.first), ...state.items],
        hasNewPosts: true,
      );
    });
  }

  void _onPostUpdated(PostgresChangePayload payload) {
    final postId = payload.newRecord['id'] as String?;
    if (postId == null || !mounted) return;
    refreshPost(postId);
  }

  Future<void> broadcastPostUpdate(String postId) async {
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

  Future<void> refreshPost(String postId) async {
    final idx = state.items.indexWhere(
      (item) => item is FeedPostItem && item.post.id == postId,
    );
    if (idx == -1) return;

    final result = await _repo.getPostsByIds([postId]);
    if (!mounted) return;

    result.fold((_) => null, (posts) {
      if (posts.isEmpty) return;
      final newList = List<FeedItem>.from(state.items);
      newList[idx] = FeedPostItem(posts.first);
      state = state.copyWith(items: newList);
    });
  }

  // ── Pagination ──────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      error: null,
      items: const [],
      cursor: null,
    );

    try {
      final items = await _fetchPage(cursor: null);
      if (!mounted) return;
      state = state.copyWith(
        items: items,
        isLoading: false,
        hasMore: items.length >= _pageSize,
        hasNewPosts: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || !mounted) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final newItems = await _fetchPage(cursor: state.cursor);
      if (!mounted) return;

      if (newItems.isEmpty) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }

      final existingIds = _itemIds(state.items);
      final deduped =
          newItems.where((i) => !existingIds.contains(_itemId(i))).toList();

      state = state.copyWith(
        items: [...state.items, ...deduped],
        isLoadingMore: false,
        hasMore: newItems.length >= _pageSize && deduped.isNotEmpty,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void clearNewPostsBadge() {
    if (state.hasNewPosts) state = state.copyWith(hasNewPosts: false);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<List<FeedItem>> _fetchPage({required DateTime? cursor}) async {
    final response = await _db.rpc('get_home_feed', params: {
      'p_limit': _pageSize,
      'p_cursor': cursor?.toUtc().toIso8601String(),
    });

    final rows = (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (rows.isEmpty) return const [];

    // Advance cursor from the last row.
    final lastCreatedAt = rows.last['created_at'];
    final newCursor = lastCreatedAt != null
        ? DateTime.tryParse(lastCreatedAt.toString())
        : null;

    // Partition activity IDs by type.
    final postIds = <String>[];
    final newsIds = <String>[];

    for (final row in rows) {
      final activityId = row['activity_id'] as String?;
      if (activityId == null) continue;
      switch (row['activity_type'] as String?) {
        case 'post':
        case 'repost':
          postIds.add(activityId);
        case 'news':
          newsIds.add(activityId);
      }
    }

    // Batch-fetch posts (enriched with sport/vibes).
    final postsById = <String, FeedPostItem>{};
    if (postIds.isNotEmpty) {
      final result = await _repo.getPostsByIds(postIds);
      result.fold((_) => null, (posts) {
        for (final p in posts) {
          postsById[p.id] = FeedPostItem(p);
        }
      });
    }

    // Batch-fetch news from published_news.
    final newsById = <String, FeedNewsItem>{};
    if (newsIds.isNotEmpty) {
      try {
        final newsRows = await _db
            .from('published_news')
            .select()
            .inFilter('id', newsIds);
        for (final row in newsRows as List<dynamic>) {
          final normalized =
              _normalizeNewsRow(Map<String, dynamic>.from(row as Map));
          try {
            final item = FeedNewsItem.fromJson(normalized);
            newsById[item.newsId] = item;
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Merge in RPC order; skip unsupported activity types.
    final result = <FeedItem>[];
    for (final row in rows) {
      final activityId = row['activity_id'] as String?;
      if (activityId == null) continue;
      switch (row['activity_type'] as String?) {
        case 'post':
        case 'repost':
          final item = postsById[activityId];
          if (item != null) result.add(item);
        case 'news':
          final item = newsById[activityId];
          if (item != null) result.add(item);
      }
    }

    if (newCursor != null && mounted) {
      state = state.copyWith(cursor: newCursor);
    }

    return result;
  }

  static Map<String, dynamic> _normalizeNewsRow(Map<String, dynamic> row) => {
        ...row,
        if (!row.containsKey('news_id')) 'news_id': row['id'],
        if (!row.containsKey('news_title')) 'news_title': row['title'],
        if (!row.containsKey('news_body')) 'news_body': row['body'],
        if (!row.containsKey('news_cover_image_url'))
          'news_cover_image_url': row['cover_image_url'],
        if (!row.containsKey('news_source_label'))
          'news_source_label': row['source_label'],
        if (!row.containsKey('news_source_url'))
          'news_source_url': row['source_url'],
        if (!row.containsKey('news_feed_label'))
          'news_feed_label': row['feed_label'],
      };

  static Set<String> _itemIds(List<FeedItem> items) =>
      items.map(_itemId).whereType<String>().toSet();

  static String? _itemId(FeedItem item) {
    if (item is FeedPostItem) return item.post.id;
    if (item is FeedNewsItem) return item.newsId;
    return null;
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
/// NOT autoDispose — subscription and cache persist across tab switches.
final feedNotifierProvider = StateNotifierProvider<FeedNotifier, FeedState>((
  ref,
) {
  final repo = ref.watch(postRepositoryProvider);
  final db = Supabase.instance.client;
  return FeedNotifier(repo, db);
});
