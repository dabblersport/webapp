import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/social/post.dart';
import '../models/social/comment.dart';

/// Abstract contract for all post & feed operations.
///
/// RLS handles visibility — queries are kept minimal.
/// `can_view_post()` is enforced at the database layer.
abstract class PostRepository {
  // ── Feeds ──────────────────────────────────────────────────────────

  /// Home feed (public + followed users). RLS filtered.
  Future<Result<List<Post>, Failure>> getHomeFeed({
    int limit = 20,
    int offset = 0,
  });

  /// Posts visible through the caller's circles.
  Future<Result<List<Post>, Failure>> getCircleFeed({
    required String circleId,
    int limit = 20,
    int offset = 0,
  });

  /// Posts scoped to a squad.
  Future<Result<List<Post>, Failure>> getSquadFeed({
    required String squadId,
    int limit = 20,
    int offset = 0,
  });

  /// All posts authored by a specific profile.
  Future<Result<List<Post>, Failure>> getUserPosts({
    required String profileId,
    int limit = 20,
    int offset = 0,
  });

  /// Single post by ID.
  Future<Result<Post, Failure>> getPost(String postId);

  // ── Write ──────────────────────────────────────────────────────────

  /// Create a new post. Returns the inserted row.
  Future<Result<Post, Failure>> createPost({
    required String kind,
    required String visibility,
    String? postType,
    String? originType,
    String? body,
    String? sport,
    List<dynamic>? media,
    List<String>? tags,
    String? gameId,
    String? locationTagId,
    String? primaryVibeId,
    List<String>? vibeIds,
    List<String>? circleIds,
    List<String>? squadIds,
    List<String>? mentionProfileIds,
  });

  /// Insert a post directly with `vibe_id` and `sport_id` on the posts table.
  ///
  /// Defaults: kind=moment, post_type=moment, origin_type=manual,
  /// content_class=social, is_active=true.
  ///
  /// If [circleId] is provided and [visibility] is 'circle', the post is also
  /// linked to that circle via the `post_circles` junction table.
  Future<Result<Post, Failure>> insertPost({
    String? body,
    String? vibeId,
    String? sportId,
    String visibility = 'public',
    String postType = 'moment',
    String? personaType,
    String? circleId,
    String? locationTagId,
    String? locationName,
    double? geoLat,
    double? geoLng,
  });

  /// List all available vibes for the picker.
  Future<Result<List<Map<String, dynamic>>, Failure>> listVibes();

  /// Soft-delete a post (sets `is_deleted = true`).
  Future<Result<Unit, Failure>> deletePost(String postId);

  // ── Likes ──────────────────────────────────────────────────────────

  Future<Result<Unit, Failure>> likePost(String postId);
  Future<Result<Unit, Failure>> unlikePost(String postId);

  /// Check if the current user has liked a post.
  Future<Result<bool, Failure>> hasLiked(String postId);

  // ── Comments ───────────────────────────────────────────────────────

  Future<Result<List<PostComment>, Failure>> getComments({
    required String postId,
    int limit = 50,
    int offset = 0,
  });

  Future<Result<PostComment, Failure>> addComment({
    required String postId,
    required String body,
    String? parentCommentId,
  });

  Future<Result<Unit, Failure>> deleteComment(String commentId);

  // ── Reposts ─────────────────────────────────────────────────────────

  Future<Result<Unit, Failure>> repostPost(String postId, {String? commentary});
  Future<Result<Unit, Failure>> undoRepost(String repostId);
  Future<Result<bool, Failure>> hasReposted(String postId);

  // ── Reactions ─────────────────────────────────────────────────────────

  /// Add a reaction (vibe) to a post. Upsert — idempotent per vibe.
  Future<Result<Unit, Failure>> reactToPost(String postId, String vibeId);

  /// Remove a specific reaction (vibe) from a post.
  Future<Result<Unit, Failure>> removeReaction(String postId, String vibeId);

  /// Get all vibe IDs the current user has reacted with on a post.
  Future<Result<Set<String>, Failure>> getMyReactions(String postId);

  // ── Views ───────────────────────────────────────────────────────────

  /// Record that the current user viewed a post. Upsert — idempotent.
  Future<Result<Unit, Failure>> recordView(String postId);
}
