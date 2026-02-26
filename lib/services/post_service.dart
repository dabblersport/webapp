import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service layer that sits between the UI and [PostRepository].
///
/// Responsibilities:
/// - Client-side validation (empty post, rate limit, duplicate check)
/// - System-decided field resolution (kind → post_type mapping)
/// - Delegates all DB work (RLS, trigger validation, vibe compatibility)
///   to the repository / Supabase RPC.
class PostService {
  PostService(this._repo, this._client);

  final PostRepository _repo;
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  // ── Public API ─────────────────────────────────────────────────────

  /// Create a post after applying all validation rules.
  ///
  /// **System-decided**: [kind], [postType] (defaults to [kind]'s DB
  /// mapping), [originType] (defaults to `manual`).
  ///
  /// **User-chosen**: [visibility], [body], [tags], [primaryVibeId],
  /// [vibeIds], [circleIds], [squadIds], [mentionProfileIds].
  Future<Result<Post, Failure>> createPost({
    required PostKind kind,
    required PostVisibility visibility,
    PostType? postType,
    OriginType originType = OriginType.manual,
    String? body,
    List<dynamic>? media,
    List<String>? tags,
    String? sport,
    String? gameId,
    String? locationTagId,
    String? primaryVibeId,
    List<String>? vibeIds,
    List<String>? circleIds,
    List<String>? squadIds,
    List<String>? mentionProfileIds,
  }) async {
    // ── Validation ───────────────────────────────────────────────────

    // 1. Prevent empty post (must have body OR media)
    final hasBody = body != null && body.trim().isNotEmpty;
    final hasMedia = media != null && media.isNotEmpty;
    if (!hasBody && !hasMedia) {
      return const Err(
        Failure(
          category: FailureCode.validation,
          message: 'Post must have body text or media.',
        ),
      );
    }

    // 2. Rate limit: max 3 posts per minute
    final rateLimitErr = await _checkRateLimit();
    if (rateLimitErr != null) return Err(rateLimitErr);

    // 3. Duplicate prevention: same body within last 5 minutes
    if (hasBody) {
      final dupErr = await _checkDuplicate(body.trim());
      if (dupErr != null) return Err(dupErr);
    }

    // ── Resolve system-decided fields ────────────────────────────────

    final resolvedPostType = postType ?? kind.defaultPostType;

    // ── Delegate to repository (RPC handles RLS, triggers, junctions) ─

    return _repo.createPost(
      kind: kind.name,
      visibility: visibility.name,
      postType: resolvedPostType.dbValue,
      originType: originType.name,
      body: hasBody ? body.trim() : null,
      sport: sport,
      media: media,
      tags: tags,
      gameId: gameId,
      locationTagId: locationTagId,
      primaryVibeId: primaryVibeId,
      vibeIds: vibeIds,
      circleIds: circleIds,
      squadIds: squadIds,
      mentionProfileIds: mentionProfileIds,
    );
  }

  // ── Private validation helpers ─────────────────────────────────────

  /// Returns a [Failure] if the user has posted ≥ 3 times in the last minute.
  Future<Failure?> _checkRateLimit() async {
    try {
      final oneMinuteAgo = DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toUtc()
          .toIso8601String();

      final rows = await _client
          .from('posts')
          .select('id')
          .eq('author_user_id', _uid)
          .gte('created_at', oneMinuteAgo)
          .limit(3);

      if (rows.length >= 3) {
        return const Failure(
          category: FailureCode.rateLimited,
          message: 'You\'re posting too fast. Please wait a moment.',
        );
      }
      return null;
    } catch (_) {
      // Don't block post creation if the check itself fails.
      return null;
    }
  }

  /// Returns a [Failure] if an identical body was posted within the last
  /// 5 minutes.
  Future<Failure?> _checkDuplicate(String body) async {
    try {
      final fiveMinutesAgo = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String();

      final rows = await _client
          .from('posts')
          .select('id')
          .eq('author_user_id', _uid)
          .eq('body', body)
          .gte('created_at', fiveMinutesAgo)
          .limit(1);

      if (rows.isNotEmpty) {
        return const Failure(
          category: FailureCode.validation,
          message: 'You already posted this. Try something new!',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
