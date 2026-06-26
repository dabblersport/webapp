import 'dart:async';
import 'package:dabbler/core/config/supabase_config.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'post_providers.dart';

// =============================================================================
// FEED STATE
// =============================================================================

/// Home feed state as a sealed union so illegal flag combinations (e.g. an
/// error while loading, or pagination flags without data) are unrepresentable.
///
/// Variants:
///   [FeedLoading] — initial first load, no data yet.
///   [FeedFailure] — initial load failed, no data.
///   [FeedData]    — data present; carries pagination + realtime sub-state.
///
/// Base getters let widgets keep reading `isLoading` / `items` / `hasMore`
/// without pattern-matching, while the notifier can only emit a valid variant.
sealed class FeedState {
  const FeedState();

  List<FeedItem> get items => const [];
  bool get isLoading => false;
  bool get isLoadingMore => false;
  bool get hasMore => false;
  String? get error => null;
  bool get hasNewPosts => false;
}

final class FeedLoading extends FeedState {
  const FeedLoading();

  @override
  bool get isLoading => true;
  @override
  bool get hasMore => true;
}

final class FeedFailure extends FeedState {
  const FeedFailure(this.message);

  final String message;

  @override
  String? get error => message;
}

final class FeedData extends FeedState {
  const FeedData({
    required this.items,
    this.hasMore = true,
    this.loadingMore = false,
    this.hasNewPosts = false,
    this.cursor,
  });

  @override
  final List<FeedItem> items;
  @override
  final bool hasMore;

  final bool loadingMore;
  @override
  bool get isLoadingMore => loadingMore;

  /// True when the realtime subscription has prepended new items and the user
  /// hasn't yet acknowledged the indicator.
  @override
  final bool hasNewPosts;

  /// Cursor for next page — `created_at` of last fetched row from the RPC.
  final DateTime? cursor;

  FeedData copyWith({
    List<FeedItem>? items,
    bool? hasMore,
    bool? loadingMore,
    bool? hasNewPosts,
    Object? cursor = _sentinel,
  }) {
    return FeedData(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
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
  FeedNotifier(this._repo, this._db) : super(const FeedLoading()) {
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
    final data = state;
    if (data is! FeedData) return;
    state = data.copyWith(
      items: data.items.where((item) {
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
      final data = state;
      if (data is! FeedData) return;
      state = data.copyWith(
        items: [FeedPostItem(posts.first), ...data.items],
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
      final data = state;
      if (data is! FeedData) return;
      final newList = List<FeedItem>.from(data.items);
      newList[idx] = FeedPostItem(posts.first);
      state = data.copyWith(items: newList);
    });
  }

  // ── Pagination ──────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (!mounted) return;
    state = const FeedLoading();

    try {
      final page = await _fetchPage(cursor: null);
      if (!mounted) return;
      state = FeedData(
        items: page.items,
        hasMore: page.items.length >= _pageSize,
        cursor: page.cursor,
        hasNewPosts: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = FeedFailure(e.toString());
    }
  }

  Future<void> loadMore() async {
    final data = state;
    if (data is! FeedData || data.loadingMore || !data.hasMore || !mounted) {
      return;
    }

    state = data.copyWith(loadingMore: true);

    try {
      final page = await _fetchPage(cursor: data.cursor);
      if (!mounted) return;
      final current = state;
      if (current is! FeedData) return;

      if (page.items.isEmpty) {
        state = current.copyWith(hasMore: false, loadingMore: false);
        return;
      }

      final existingIds = _itemIds(current.items);
      final deduped =
          page.items.where((i) => !existingIds.contains(_itemId(i))).toList();

      state = current.copyWith(
        items: [...current.items, ...deduped],
        loadingMore: false,
        hasMore: page.items.length >= _pageSize && deduped.isNotEmpty,
        cursor: page.cursor,
      );
    } catch (e) {
      if (!mounted) return;
      final current = state;
      // A load-more failure keeps existing data; just stop the spinner.
      if (current is FeedData) {
        state = current.copyWith(loadingMore: false);
      }
    }
  }

  void clearNewPostsBadge() {
    final data = state;
    if (data is FeedData && data.hasNewPosts) {
      state = data.copyWith(hasNewPosts: false);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<({List<FeedItem> items, DateTime? cursor})> _fetchPage({
    required DateTime? cursor,
  }) async {
    final response = await _db.rpc(SupabaseConfig.getHomeFeedFn, params: {
      'p_limit': _pageSize,
      'p_cursor': cursor?.toUtc().toIso8601String(),
    });

    final rows = (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (rows.isEmpty) return (items: const <FeedItem>[], cursor: cursor);

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
            .from(SupabaseConfig.publishedNewsTable)
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

    return (items: result, cursor: newCursor ?? cursor);
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
