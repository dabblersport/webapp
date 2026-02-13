import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/features/home/presentation/widgets/inline_post_composer.dart';
import '../widgets/feed/post_card.dart';
import 'package:dabbler/widgets/thoughts_input.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import '../../services/social_service.dart';
import '../../services/social_rewards_handler.dart';
import '../../services/realtime_likes_service.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Instagram-like social feed screen with posts and interactions
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  // Removed search functionality – simplified feed

  late SocialRewardsHandler _rewardsHandler;
  final AuthService _authService = AuthService();
  final Map<String, StreamSubscription<PostLikeUpdate>> _likeSubscriptions = {};

  /// Fetch blocked user IDs directly from Supabase (StatefulWidget, no Riverpod).
  Future<Set<String>> _fetchBlockedUserIds() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return {};
      final db = Supabase.instance.client;
      final blockedByMe = await db
          .from('user_blocks')
          .select('blocked_user_id')
          .eq('blocker_user_id', uid);
      final blockedMe = await db
          .from('user_blocks')
          .select('blocker_user_id')
          .eq('blocked_user_id', uid);
      return {
        ...(blockedByMe as List).map((r) => r['blocked_user_id'] as String),
        ...(blockedMe as List).map((r) => r['blocker_user_id'] as String),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  void initState() {
    super.initState();
    _rewardsHandler = SocialRewardsHandler();
    _loadPosts();
  }

  @override
  void dispose() {
    // Cancel all realtime subscriptions
    for (final subscription in _likeSubscriptions.values) {
      subscription.cancel();
    }
    _likeSubscriptions.clear();
    super.dispose();
  }

  /// Subscribe to realtime like updates for a specific post
  void _subscribeToPostLikes(String postId) {
    // Don't subscribe twice
    if (_likeSubscriptions.containsKey(postId)) return;

    final subscription = RealtimeLikesService().postUpdates(postId).listen((
      update,
    ) {
      if (!mounted) return;

      // Find and update the post in the list
      final index = _posts.indexWhere((p) => p.id == update.postId);
      if (index != -1) {
        setState(() {
          _posts[index] = _posts[index].copyWith(
            likesCount: update.newLikeCount,
            isLiked: update.userId == _authService.getCurrentUser()?.id
                ? update.isLiked
                : _posts[index].isLiked,
          );
        });
      }
    });

    _likeSubscriptions[postId] = subscription;
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final socialService = SocialService();

      // Fetch blocked user IDs for feed filtering
      final blockedIds = await _fetchBlockedUserIds();
      final posts = await socialService.getFeedPosts(
        blockedUserIds: blockedIds,
      );

      setState(() {
        _posts.clear();
        _posts.addAll(posts);
        _isLoading = false;
      });

      // Subscribe to realtime updates for each loaded post
      for (final post in posts) {
        _subscribeToPostLikes(post.id);
      }
    } catch (e) {
      // Show error, don't fall back to sample data
      setState(() {
        _posts.clear();
        _isLoading = false;
      });

      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.onError, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to load posts: $e')),
            ],
          ),
          backgroundColor: colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _refreshPosts() async {
    await _loadPosts();
  }

  final Set<String> _likesInProgress = {};

  void _likePost(String postId) async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return;

    // Prevent multiple simultaneous like requests for this post
    if (_likesInProgress.contains(postId)) return;

    // Store original post state for rollback on error
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) return;
    final originalPost = _posts[postIndex];

    // Lock this post from further like requests
    _likesInProgress.add(postId);

    // Update UI optimistically first for instant feedback
    setState(() {
      _posts[postIndex] = originalPost.copyWith(
        isLiked: !originalPost.isLiked,
        likesCount: originalPost.isLiked
            ? originalPost.likesCount - 1
            : originalPost.likesCount + 1,
      );
    });

    try {
      final socialService = SocialService();
      final result = await socialService.toggleLike(postId);

      // Track social interaction for rewards only on like (not unlike)
      if (result['isLiked'] as bool) {
        await _rewardsHandler.trackSocialInteraction(
          userId: currentUser.id,
          interactionType: 'like',
          targetUserId: originalPost.authorId,
          metadata: {'postId': postId},
        );
      }

      // Update with actual values from server
      final actualIsLiked = result['isLiked'] as bool;
      final actualLikesCount = result['likesCount'] as int;

      if (mounted) {
        setState(() {
          final currentIndex = _posts.indexWhere((post) => post.id == postId);
          if (currentIndex != -1) {
            _posts[currentIndex] = _posts[currentIndex].copyWith(
              isLiked: actualIsLiked,
              likesCount: actualLikesCount,
            );
          }
        });
      }
    } catch (e) {
      // Rollback to original state on error
      if (mounted) {
        setState(() {
          final currentIndex = _posts.indexWhere((post) => post.id == postId);
          if (currentIndex != -1) {
            _posts[currentIndex] = originalPost;
          }
        });
      }

      if (!mounted) return;

      // Only show error if it's not a concurrent request error
      if (!e.toString().contains('already in progress')) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: colorScheme.onErrorContainer,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text('Failed to update like'),
              ],
            ),
            backgroundColor: colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Always release the lock
      _likesInProgress.remove(postId);
    }
  }

  void _openComments(String postId) {
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      // Track comment interaction for rewards
      _rewardsHandler.trackSocialInteraction(
        userId: currentUser.id,
        interactionType: 'comment',
        targetUserId: _posts.firstWhere((p) => p.id == postId).authorId,
        metadata: {'postId': postId},
      );
    }

    // Navigate to ThreadScreen to view and add comments
    context.push('/social-post-detail/$postId');
  }

  void _sharePost(String postId) {
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      // Track share interaction for rewards
      _rewardsHandler.trackSocialInteraction(
        userId: currentUser.id,
        interactionType: 'share',
        targetUserId: _posts.firstWhere((p) => p.id == postId).authorId,
        metadata: {'postId': postId},
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openProfile(String userId) {
    // Navigate to user's profile
    context.go('${RoutePaths.userProfile}/$userId');
  }

  void _navigateToCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const InlinePostComposer(),
      ),
    );
  }

  // Search-related methods & computed getters removed

  @override
  Widget build(BuildContext context) {
    return TwoSectionLayout(
      category: 'social',
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          // Friends overview section removed
        ],
      ),
      bottomSection: _buildFeedSection(),
      onRefresh: _refreshPosts,
    );
  }

  Widget _buildHeaderSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Iconsax.profile_2user_copy,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Connect with friends',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: () => context.push(RoutePaths.socialFriends),
          icon: const Icon(Iconsax.profile_2user_copy),
          tooltip: 'Circle',
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.categorySocial.withValues(alpha: 0.0),
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }

  Widget _buildComposerCard() {
    return ThoughtsInput(onTap: _navigateToCreatePost);
  }

  Widget _buildFeedSection() {
    if (_isLoading && _posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isLoading && _posts.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      child: Column(
        children: [
          for (var i = 0; i < _posts.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _posts.length - 1 ? 0 : 0),
              child: PostCard(
                post: _posts[i],
                onLike: () => _likePost(_posts[i].id),
                onComment: () => _openComments(_posts[i].id),
                onShare: () => _sharePost(_posts[i].id),
                onProfileTap: () => _openProfile(_posts[i].authorId),
                onPostTap: () => _openComments(_posts[i].id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.group, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Follow friends and join the conversation!',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: _navigateToCreatePost,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create your first post'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
