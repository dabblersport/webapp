import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/comment.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:dabbler/data/repositories/sports_repository.dart';
import 'package:dabbler/data/repositories/vibes_repository.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/services/post_service.dart';

// =============================================================================
// REPOSITORY PROVIDER
// =============================================================================

final postRepositoryProvider = Provider<PostRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return PostRepositoryImpl(svc);
});

/// Service layer with validation (rate limit, duplicate check, enum mapping).
final postServiceProvider = Provider<PostService>((ref) {
  final repo = ref.watch(postRepositoryProvider);
  final svc = ref.watch(supabaseServiceProvider);
  return PostService(repo, svc.client);
});

// =============================================================================
// FEED PROVIDERS
// =============================================================================

/// Home feed — public + followed users, RLS filtered.
final homeFeedProvider = FutureProvider.autoDispose.family<List<Post>, int>((
  ref,
  page,
) async {
  const pageSize = 20;
  final repo = ref.watch(postRepositoryProvider);
  final result = await repo.getHomeFeed(
    limit: pageSize,
    offset: page * pageSize,
  );
  return result.fold((err) => throw Exception(err.message), (posts) => posts);
});

/// Circle feed — posts shared to a specific circle.
final circlePostsFeedProvider = FutureProvider.autoDispose
    .family<List<Post>, ({String circleId, int page})>((ref, params) async {
      const pageSize = 20;
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.getCircleFeed(
        circleId: params.circleId,
        limit: pageSize,
        offset: params.page * pageSize,
      );
      return result.fold(
        (err) => throw Exception(err.message),
        (posts) => posts,
      );
    });

/// Squad feed — posts scoped to a squad.
final squadFeedProvider = FutureProvider.autoDispose
    .family<List<Post>, ({String squadId, int page})>((ref, params) async {
      const pageSize = 20;
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.getSquadFeed(
        squadId: params.squadId,
        limit: pageSize,
        offset: params.page * pageSize,
      );
      return result.fold(
        (err) => throw Exception(err.message),
        (posts) => posts,
      );
    });

/// Posts by a specific user profile.
final userPostsProvider = FutureProvider.autoDispose
    .family<List<Post>, ({String profileId, int page})>((ref, params) async {
      const pageSize = 20;
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.getUserPosts(
        profileId: params.profileId,
        limit: pageSize,
        offset: params.page * pageSize,
      );
      return result.fold(
        (err) => throw Exception(err.message),
        (posts) => posts,
      );
    });

/// Single post by ID.
final postDetailProvider = FutureProvider.autoDispose.family<Post, String>((
  ref,
  postId,
) async {
  final repo = ref.watch(postRepositoryProvider);
  final result = await repo.getPost(postId);
  return result.fold((err) => throw Exception(err.message), (post) => post);
});

// =============================================================================
// INTERACTION PROVIDERS
// =============================================================================

/// Whether the current user has liked a post.
final hasLikedProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  postId,
) async {
  final repo = ref.watch(postRepositoryProvider);
  final result = await repo.hasLiked(postId);
  return result.fold((err) => false, (liked) => liked);
});

/// Comments for a post.
final postCommentsProvider = FutureProvider.autoDispose
    .family<List<PostComment>, String>((ref, postId) async {
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.getComments(postId: postId);
      return result.fold(
        (err) => throw Exception(err.message),
        (comments) => comments,
      );
    });

/// Whether the current user has reposted a post.
final hasRepostedProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  postId,
) async {
  final repo = ref.watch(postRepositoryProvider);
  final result = await repo.hasReposted(postId);
  return result.fold((err) => false, (v) => v);
});

/// Set of vibe IDs the current user has reacted with on a post.
final myReactionsProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, postId) async {
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.getMyReactions(postId);
      return result.fold((err) => <String>{}, (vibes) => vibes);
    });

// =============================================================================
// VIBES — typed provider backed by VibesRepository
// =============================================================================

final vibesRepositoryProvider = Provider<VibesRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return VibesRepository(svc);
});

/// All active vibes from DB, typed as [List<Vibe>].
final vibesProvider = FutureProvider.autoDispose<List<Vibe>>((ref) async {
  final repo = ref.watch(vibesRepositoryProvider);
  final result = await repo.getActiveVibes();
  return result.fold((err) => throw Exception(err.message), (vibes) => vibes);
});

/// Legacy: raw map list for backward compatibility with old pickers.
final vibesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.listVibes();
      return result.fold(
        (err) => throw Exception(err.message),
        (vibes) => vibes,
      );
    });

// =============================================================================
// SPORTS — typed provider backed by SportsRepository
// =============================================================================

final sportsRepositoryProvider = Provider<SportsRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return SportsRepository(svc);
});

/// All active sports from DB, typed as [List<Sport>].
final sportsProvider = FutureProvider.autoDispose<List<Sport>>((ref) async {
  final repo = ref.watch(sportsRepositoryProvider);
  final result = await repo.getActiveSports();
  return result.fold((err) => throw Exception(err.message), (sports) => sports);
});

/// Legacy: raw map list for backward compatibility with old pickers.
final sportsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final svc = ref.watch(supabaseServiceProvider);
      final rows = await svc.client
          .from('sports')
          .select('id, name_en, sport_key, emoji, category')
          .eq('is_active', true)
          .order('name_en');
      return rows.cast<Map<String, dynamic>>();
    });

// =============================================================================
// POST CREATION — selection state + controller
// =============================================================================

/// Currently selected vibe ID for post creation.
final selectedVibeProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Currently selected sport ID for post creation.
final selectedSportProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Controller for post creation.
///
/// Validates that at least one of body, vibe, or sport is provided,
/// then calls [PostRepository.insertPost] with `vibe_id` and `sport_id`.
final postControllerProvider =
    StateNotifierProvider.autoDispose<PostController, AsyncValue<void>>((ref) {
      return PostController(ref);
    });

class PostController extends StateNotifier<AsyncValue<void>> {
  PostController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  /// Create a post.
  ///
  /// At least one of [body], [vibeId], or [sportId] must be non-null.
  /// Defaults: kind=moment, post_type=moment, origin_type=manual.
  Future<Result<Post, Failure>> createPost({
    String? body,
    String? vibeId,
    String? sportId,
    String visibility = 'public',
    PostType postType = PostType.moment,
    String? circleId,
  }) async {
    final hasBody = body != null && body.trim().isNotEmpty;

    if (!hasBody && vibeId == null && sportId == null) {
      return const Err(
        Failure(
          category: FailureCode.validation,
          message: 'Add some text, a vibe, or a sport to post.',
        ),
      );
    }

    state = const AsyncLoading();

    final repo = _ref.read(postRepositoryProvider);
    final activePersonaType = _ref.read(activeProfileTypeProvider);
    final result = await repo.insertPost(
      body: hasBody ? body.trim() : null,
      vibeId: vibeId,
      sportId: sportId,
      visibility: visibility,
      postType: postType.dbValue,
      personaType: activePersonaType,
      circleId: circleId,
    );

    state = const AsyncData(null);

    if (result.isSuccess) {
      _ref.invalidate(homeFeedProvider);
    }

    return result;
  }
}

// =============================================================================
// ACTION NOTIFIER — imperative mutations (like, comment, create, delete)
// =============================================================================

/// Controller for post mutations. Callers can use
/// `ref.read(postActionsProvider.notifier).likePost(id)` etc.
final postActionsProvider =
    StateNotifierProvider<PostActionsNotifier, AsyncValue<void>>((ref) {
      return PostActionsNotifier(ref);
    });

class PostActionsNotifier extends StateNotifier<AsyncValue<void>> {
  PostActionsNotifier(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  PostRepository get _repo => _ref.read(postRepositoryProvider);
  PostService get _service => _ref.read(postServiceProvider);

  /// Create a post through the service layer (validation + RPC).
  ///
  /// System decides [kind], [postType], [originType].
  /// User chooses [visibility], [body], vibes, scope, tags, mentions.
  Future<Result<Post, dynamic>> createPost({
    required PostKind kind,
    required PostVisibility visibility,
    PostType? postType,
    OriginType originType = OriginType.manual,
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
  }) async {
    state = const AsyncLoading();
    final result = await _service.createPost(
      kind: kind,
      visibility: visibility,
      postType: postType,
      originType: originType,
      body: body,
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
    state = const AsyncData(null);
    // Invalidate feeds so they refetch.
    _ref.invalidate(homeFeedProvider);
    return result;
  }

  /// Returns true if the DB write succeeded, false on any error.
  Future<bool> likePost(String postId) async {
    final result = await _repo.likePost(postId);
    result.fold(
      (err) => debugPrint('[PostActions] likePost FAILED: ${err.message}'),
      (_) => null,
    );
    _ref.invalidate(hasLikedProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    if (result.isSuccess) {
      await _ref
          .read(feedNotifierProvider.notifier)
          .broadcastPostUpdate(postId);
    }
    return result.isSuccess;
  }

  /// Returns true if the DB write succeeded, false on any error.
  Future<bool> unlikePost(String postId) async {
    final result = await _repo.unlikePost(postId);
    result.fold(
      (err) => debugPrint('[PostActions] unlikePost FAILED: ${err.message}'),
      (_) => null,
    );
    _ref.invalidate(hasLikedProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    if (result.isSuccess) {
      await _ref
          .read(feedNotifierProvider.notifier)
          .broadcastPostUpdate(postId);
    }
    return result.isSuccess;
  }

  Future<void> deletePost(String postId) async {
    await _repo.deletePost(postId);
    _ref.invalidate(homeFeedProvider);
  }

  Future<Result<PostComment, dynamic>> addComment({
    required String postId,
    required String body,
    String? parentCommentId,
  }) async {
    final result = await _repo.addComment(
      postId: postId,
      body: body,
      parentCommentId: parentCommentId,
    );
    _ref.invalidate(postCommentsProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    await _ref.read(feedNotifierProvider.notifier).broadcastPostUpdate(postId);
    return result;
  }

  Future<void> deleteComment({
    required String commentId,
    required String postId,
  }) async {
    await _repo.deleteComment(commentId);
    _ref.invalidate(postCommentsProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    await _ref.read(feedNotifierProvider.notifier).broadcastPostUpdate(postId);
  }

  Future<void> repostPost(String postId, {String? commentary}) async {
    await _repo.repostPost(postId, commentary: commentary);
    _ref.invalidate(hasRepostedProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    _ref.invalidate(homeFeedProvider);
  }

  Future<void> undoRepost(String repostId, String postId) async {
    await _repo.undoRepost(repostId);
    _ref.invalidate(hasRepostedProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
  }

  /// Record that the current user viewed a post. Fire-and-forget.
  Future<void> recordView(String postId) async {
    await _repo.recordView(postId);
  }

  /// Add a reaction (vibe) to a post.
  Future<void> reactToPost(String postId, String vibeId) async {
    await _repo.reactToPost(postId, vibeId);
    _ref.invalidate(myReactionsProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    _ref.invalidate(homeFeedProvider);
    await _ref.read(feedNotifierProvider.notifier).broadcastPostUpdate(postId);
  }

  /// Remove a specific reaction (vibe) from a post.
  Future<void> removeReaction(String postId, String vibeId) async {
    await _repo.removeReaction(postId, vibeId);
    _ref.invalidate(myReactionsProvider(postId));
    _ref.invalidate(postDetailProvider(postId));
    _ref.invalidate(homeFeedProvider);
    await _ref.read(feedNotifierProvider.notifier).broadcastPostUpdate(postId);
  }
}
