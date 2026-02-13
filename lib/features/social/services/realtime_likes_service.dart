import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real-time service for managing like updates across the app
/// Provides streams that emit when posts/comments are liked/unliked by any user
///
/// Handles channel timeouts gracefully with automatic retry and exponential
/// backoff. All channels are properly cleaned up on [dispose].
class RealtimeLikesService {
  static final RealtimeLikesService _instance =
      RealtimeLikesService._internal();
  factory RealtimeLikesService() => _instance;
  RealtimeLikesService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream controllers for broadcasting like updates
  final _postLikeUpdatesController =
      StreamController<PostLikeUpdate>.broadcast();
  final _commentLikeUpdatesController =
      StreamController<CommentLikeUpdate>.broadcast();
  final _postCommentUpdatesController =
      StreamController<PostCommentUpdate>.broadcast();

  // Track active subscriptions
  RealtimeChannel? _postLikesChannel;
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _commentLikesChannel;
  RealtimeChannel? _commentsChannel;
  RealtimeChannel? _postCommentsChannel;

  // Retry state per channel
  final Map<String, int> _retryAttempts = {};
  final Map<String, Timer?> _retryTimers = {};
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 5);

  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Initialize real-time subscriptions.
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Does NOT throw on channel timeout; logs and retries instead.
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    _subscribeToPostLikes();
    _subscribeToPostUpdates();
    _subscribeToCommentLikes();
    _subscribeToCommentUpdates();
    _subscribeToPostComments();

    _isInitialized = true;
  }

  /// Centralized subscribe helper with status callback and retry logic.
  void _subscribeWithRetry(RealtimeChannel channel, String channelName) {
    _retryAttempts[channelName] = 0;

    channel.subscribe((status, [error]) {
      if (_isDisposed) return;

      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _retryAttempts[channelName] = 0;
          debugPrint('Realtime: $channelName subscribed');
          break;
        case RealtimeSubscribeStatus.timedOut:
          final attempt = (_retryAttempts[channelName] ?? 0) + 1;
          _retryAttempts[channelName] = attempt;
          debugPrint(
            'Realtime: $channelName timed out (attempt $attempt/$_maxRetries)',
          );
          if (attempt <= _maxRetries) {
            final delay = _baseRetryDelay * attempt; // linear backoff
            _retryTimers[channelName]?.cancel();
            _retryTimers[channelName] = Timer(delay, () {
              if (!_isDisposed) {
                debugPrint('Realtime: retrying $channelName...');
                channel.subscribe();
              }
            });
          } else {
            debugPrint('Realtime: $channelName exhausted retries, giving up');
          }
          break;
        case RealtimeSubscribeStatus.channelError:
          debugPrint('Realtime: $channelName error: $error');
          break;
        case RealtimeSubscribeStatus.closed:
          debugPrint('Realtime: $channelName closed');
          break;
      }
    });
  }

  /// Subscribe to post_likes table changes (INSERT/DELETE)
  void _subscribeToPostLikes() {
    _postLikesChannel = _supabase.channel('realtime:post_likes');

    _postLikesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_likes',
          callback: (payload) {
            final postId = payload.newRecord['post_id'] as String?;
            final userId = payload.newRecord['user_id'] as String?;
            if (postId != null && userId != null) {
              _postLikeUpdatesController.add(
                PostLikeUpdate(
                  postId: postId,
                  userId: userId,
                  isLiked: true,
                  timestamp: DateTime.now(),
                ),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'post_likes',
          callback: (payload) {
            final postId = payload.oldRecord['post_id'] as String?;
            final userId = payload.oldRecord['user_id'] as String?;
            if (postId != null && userId != null) {
              _postLikeUpdatesController.add(
                PostLikeUpdate(
                  postId: postId,
                  userId: userId,
                  isLiked: false,
                  timestamp: DateTime.now(),
                ),
              );
            }
          },
        );

    _subscribeWithRetry(_postLikesChannel!, 'post_likes');
  }

  /// Subscribe to posts table updates (like_count changes)
  void _subscribeToPostUpdates() {
    _postsChannel = _supabase.channel('realtime:posts_likes');

    _postsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'posts',
      callback: (payload) {
        final postId = payload.newRecord['id'] as String?;
        final newLikeCount = payload.newRecord['like_count'] as int?;
        final oldLikeCount = payload.oldRecord['like_count'] as int?;

        // Only emit update if like_count actually changed
        // This prevents double-invalidation when comment_count changes
        if (postId != null &&
            newLikeCount != null &&
            newLikeCount != oldLikeCount) {
          _postLikeUpdatesController.add(
            PostLikeUpdate(
              postId: postId,
              userId: '', // Aggregate update, no specific user
              isLiked: true, // Doesn't matter for count updates
              timestamp: DateTime.now(),
              newLikeCount: newLikeCount,
            ),
          );
        }
      },
    );

    _subscribeWithRetry(_postsChannel!, 'posts_likes');
  }

  /// Subscribe to comment_likes table changes
  void _subscribeToCommentLikes() {
    _commentLikesChannel = _supabase.channel('realtime:comment_likes');

    _commentLikesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comment_likes',
          callback: (payload) {
            final commentId = payload.newRecord['comment_id'] as String?;
            final userId = payload.newRecord['user_id'] as String?;
            if (commentId != null && userId != null) {
              _commentLikeUpdatesController.add(
                CommentLikeUpdate(
                  commentId: commentId,
                  userId: userId,
                  isLiked: true,
                  timestamp: DateTime.now(),
                ),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comment_likes',
          callback: (payload) {
            final commentId = payload.oldRecord['comment_id'] as String?;
            final userId = payload.oldRecord['user_id'] as String?;
            if (commentId != null && userId != null) {
              _commentLikeUpdatesController.add(
                CommentLikeUpdate(
                  commentId: commentId,
                  userId: userId,
                  isLiked: false,
                  timestamp: DateTime.now(),
                ),
              );
            }
          },
        );

    _subscribeWithRetry(_commentLikesChannel!, 'comment_likes');
  }

  /// Subscribe to post_comments table updates (like_count changes)
  void _subscribeToCommentUpdates() {
    _commentsChannel = _supabase.channel('realtime:comments_likes');

    _commentsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'post_comments',
      callback: (payload) {
        final commentId = payload.newRecord['id'] as String?;
        final likeCount = payload.newRecord['like_count'] as int?;
        if (commentId != null && likeCount != null) {
          _commentLikeUpdatesController.add(
            CommentLikeUpdate(
              commentId: commentId,
              userId: '',
              isLiked: true,
              timestamp: DateTime.now(),
              newLikeCount: likeCount,
            ),
          );
        }
      },
    );

    _subscribeWithRetry(_commentsChannel!, 'comments_likes');
  }

  /// Subscribe to post_comments table for new comments (INSERT/DELETE)
  void _subscribeToPostComments() {
    _postCommentsChannel = _supabase.channel('realtime:post_comments');

    _postCommentsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_comments',
          callback: (payload) {
            final postId = payload.newRecord['post_id'] as String?;
            final commentId = payload.newRecord['id'] as String?;
            if (postId != null && commentId != null) {
              _postCommentUpdatesController.add(
                PostCommentUpdate(
                  postId: postId,
                  commentId: commentId,
                  isDeleted: false,
                  timestamp: DateTime.now(),
                ),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'post_comments',
          callback: (payload) {
            final postId = payload.oldRecord['post_id'] as String?;
            final commentId = payload.oldRecord['id'] as String?;
            if (postId != null && commentId != null) {
              _postCommentUpdatesController.add(
                PostCommentUpdate(
                  postId: postId,
                  commentId: commentId,
                  isDeleted: true,
                  timestamp: DateTime.now(),
                ),
              );
            }
          },
        );

    _subscribeWithRetry(_postCommentsChannel!, 'post_comments');
  }

  /// Stream of post like updates
  Stream<PostLikeUpdate> get postLikeUpdates =>
      _postLikeUpdatesController.stream;

  /// Stream of comment like updates
  Stream<CommentLikeUpdate> get commentLikeUpdates =>
      _commentLikeUpdatesController.stream;

  /// Stream of post comment updates (new/deleted comments)
  Stream<PostCommentUpdate> get postCommentUpdates =>
      _postCommentUpdatesController.stream;

  /// Stream of updates for a specific post
  Stream<PostLikeUpdate> postUpdates(String postId) {
    return _postLikeUpdatesController.stream.where(
      (update) => update.postId == postId,
    );
  }

  /// Stream of updates for a specific comment
  Stream<CommentLikeUpdate> commentUpdates(String commentId) {
    return _commentLikeUpdatesController.stream.where(
      (update) => update.commentId == commentId,
    );
  }

  /// Stream of comment updates for a specific post
  Stream<PostCommentUpdate> postCommentUpdatesForPost(String postId) {
    return _postCommentUpdatesController.stream.where(
      (update) => update.postId == postId,
    );
  }

  /// Check if user has liked a specific post
  Future<bool> isPostLikedByUser(String postId, String userId) async {
    try {
      final result = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  /// Get current like count for a post
  Future<int> getPostLikeCount(String postId) async {
    try {
      final result = await _supabase
          .from('posts')
          .select('like_count')
          .eq('id', postId)
          .maybeSingle();
      return result?['like_count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Cleanup and unsubscribe from all channels
  Future<void> dispose() async {
    _isDisposed = true;

    // Cancel all retry timers
    for (final timer in _retryTimers.values) {
      timer?.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();

    await _postLikesChannel?.unsubscribe();
    await _postsChannel?.unsubscribe();
    await _commentLikesChannel?.unsubscribe();
    await _commentsChannel?.unsubscribe();
    await _postCommentsChannel?.unsubscribe();

    _postLikesChannel = null;
    _postsChannel = null;
    _commentLikesChannel = null;
    _commentsChannel = null;
    _postCommentsChannel = null;

    await _postLikeUpdatesController.close();
    await _commentLikeUpdatesController.close();
    await _postCommentUpdatesController.close();

    _isInitialized = false;
  }
}

/// Model for post like updates
class PostLikeUpdate {
  final String postId;
  final String userId;
  final bool isLiked;
  final DateTime timestamp;
  final int? newLikeCount;

  PostLikeUpdate({
    required this.postId,
    required this.userId,
    required this.isLiked,
    required this.timestamp,
    this.newLikeCount,
  });

  @override
  String toString() =>
      'PostLikeUpdate(postId: $postId, userId: $userId, isLiked: $isLiked, count: $newLikeCount)';
}

/// Model for comment like updates
class CommentLikeUpdate {
  final String commentId;
  final String userId;
  final bool isLiked;
  final DateTime timestamp;
  final int? newLikeCount;

  CommentLikeUpdate({
    required this.commentId,
    required this.userId,
    required this.isLiked,
    required this.timestamp,
    this.newLikeCount,
  });

  @override
  String toString() =>
      'CommentLikeUpdate(commentId: $commentId, userId: $userId, isLiked: $isLiked, count: $newLikeCount)';
}

/// Model for post comment updates (new/deleted comments)
class PostCommentUpdate {
  final String postId;
  final String commentId;
  final bool isDeleted;
  final DateTime timestamp;

  PostCommentUpdate({
    required this.postId,
    required this.commentId,
    required this.isDeleted,
    required this.timestamp,
  });

  @override
  String toString() =>
      'PostCommentUpdate(postId: $postId, commentId: $commentId, isDeleted: $isDeleted)';
}
