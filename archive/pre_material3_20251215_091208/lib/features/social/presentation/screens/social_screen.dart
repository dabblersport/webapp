import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import '../widgets/feed/post_card.dart';
import 'package:dabbler/widgets/thoughts_input.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import '../../services/social_service.dart';
import '../../services/social_rewards_handler.dart';
import 'package:dabbler/core/services/auth_service.dart';

/// Instagram-like social feed screen with posts and interactions
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  // Removed search functionality – simplified feed

  late SocialRewardsHandler _rewardsHandler;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _rewardsHandler = SocialRewardsHandler();
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final socialService = SocialService();
      final posts = await socialService.getFeedPosts();

      setState(() {
        _posts.clear();
        _posts.addAll(posts);
        _isLoading = false;
      });
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

  // ignore: unused_element
  Future<void> _refreshPosts() async {
    await _loadPosts();
  }

  void _likePost(String postId) async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return;

    try {
      final socialService = SocialService();
      await socialService.toggleLike(postId);

      // Track social interaction for rewards
      final post = _posts.firstWhere((p) => p.id == postId);
      await _rewardsHandler.trackSocialInteraction(
        userId: currentUser.id,
        interactionType: 'like',
        targetUserId: post.authorId,
        metadata: {'postId': postId},
      );

      // Update UI optimistically
      setState(() {
        final postIndex = _posts.indexWhere((post) => post.id == postId);
        if (postIndex != -1) {
          final post = _posts[postIndex];
          _posts[postIndex] = post.copyWith(
            isLiked: !post.isLiked,
            likesCount: post.isLiked
                ? post.likesCount - 1
                : post.likesCount + 1,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
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
    // Navigate to create post screen
    context.push('/social-create-post');
  }

  // Search-related methods & computed getters removed

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeaderSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildComposerCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            if (_isLoading && _posts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (!_isLoading && _posts.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState()),
            if (_posts.isNotEmpty) _buildPostsSliver(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final heroColor = isDarkMode
        ? const Color(0xFF4A148C)
        : const Color(0xFFE0C7FF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode
        ? Colors.white.withOpacity(0.8)
        : Colors.black.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.go(RoutePaths.home),
                icon: const Icon(Icons.dashboard_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  foregroundColor: colorScheme.onSurface,
                  minimumSize: const Size(48, 48),
                ),
              ),
              const SizedBox(width: 16),
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
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: () => context.push(RoutePaths.socialSearch),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find friends'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: heroColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community spotlight',
                  style: textTheme.labelLarge?.copyWith(
                    color: subtextColor,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Celebrate your highlights',
                  style: textTheme.headlineSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Share match recaps, training wins, and invite others to join upcoming sessions.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.85)
                        : Colors.black.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ThoughtsInput(onTap: _navigateToCreatePost),
    );
  }

  SliverPadding _buildPostsSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final post = _posts[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _posts.length - 1 ? 0 : 20,
            ),
            child: PostCard(
              post: post,
              onLike: () => _likePost(post.id),
              onComment: () => _openComments(post.id),
              onShare: () => _sharePost(post.id),
              onProfileTap: () => _openProfile(post.authorId),
              onPostTap: () => _openComments(post.id),
            ),
          );
        }, childCount: _posts.length),
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
