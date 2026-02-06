import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/widgets/loading_widget.dart';
import '../../providers/social_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/post/post_content_widget.dart';
import 'package:dabbler/features/social/presentation/widgets/post/post_author_widget.dart';
import 'package:dabbler/features/social/presentation/widgets/post/share_post_bottom_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/comments/comments_thread.dart';
import 'package:dabbler/features/social/presentation/widgets/comments/comment_input.dart';
import '../../../services/social_service.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:intl/intl.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  String? _replyingToCommentId;

  @override
  void initState() {
    super.initState();

    // Load post details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(socialFeedControllerProvider.notifier)
          .loadPostDetails(widget.postId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final postAsync = ref.watch(postDetailsProvider(widget.postId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: postAsync.when(
          data: (post) => FutureBuilder<bool>(
            future: _checkPostTakedown(post.id),
            builder: (context, takedownSnapshot) {
              if (takedownSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingWidget());
              }

              final isTakedown = takedownSnapshot.data ?? false;
              if (isTakedown) {
                return _buildTakedownPlaceholder(context, theme);
              }

              return Column(
                children: [
                  Expanded(child: _buildPostContent(context, theme, post)),
                  _buildCommentInput(context, theme),
                ],
              );
            },
          ),
          loading: () => const Center(child: LoadingWidget()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load post',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.refresh(postDetailsProvider(widget.postId)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostContent(
    BuildContext context,
    ThemeData theme,
    dynamic post,
  ) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwnPost = post.authorId == currentUserId;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header with back button and actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    foregroundColor: colorScheme.onSurface,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => _sharePost(post),
                  icon: const Icon(Icons.share_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    foregroundColor: colorScheme.onSurface,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: colorScheme.onSurface,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'copy_link',
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Copy Link'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Report'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) => _handleMenuAction(value.toString()),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Post content card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _getVibeColor(post, colorScheme).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author info
                    PostAuthorWidget(
                      author: _AuthorData(
                        name: post.authorName,
                        avatar: post.authorAvatar,
                        isVerified:
                            false, // PostModel doesn't have authorVerified
                      ),
                      createdAt: post.createdAt,
                      city: post.cityName, // Use 'locationName' not 'location'
                      isEdited: false, // PostModel doesn't have isEdited
                      onProfileTap: () => _navigateToProfile(post.authorId),
                      actions: isOwnPost
                          ? [
                              PostAction(
                                icon: Icons.edit_rounded,
                                label: 'Edit',
                                onTap: () => _editPost(post),
                              ),
                              PostAction(
                                icon: Icons.delete_rounded,
                                label: 'Delete',
                                onTap: () => _deletePost(post.id),
                                isDestructive: true,
                              ),
                            ]
                          : [
                              PostAction(
                                icon: Icons.person_off_rounded,
                                label: 'Block User',
                                onTap: () => _blockUser(post.authorId),
                                isDestructive: true,
                              ),
                            ],
                    ),

                    const SizedBox(height: 16),

                    // Post content
                    PostContentWidget(
                      content: post.content,
                      media: post.mediaUrls,
                      sports: const [], // PostModel doesn't have tags
                      mentions:
                          const [], // PostModel doesn't have mentionedUsers
                      hashtags: const [], // PostModel doesn't have tags
                      onMediaTap: (mediaIndex) =>
                          _viewMedia(post.mediaUrls, mediaIndex),
                      onMentionTap: (userId) => _navigateToProfile(userId),
                      onHashtagTap: (hashtag) => _searchHashtag(hashtag),
                    ),

                    const SizedBox(height: 20),

                    // Engagement stats - minimal one line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          theme,
                          icon: Icons.favorite_rounded,
                          count: post.likesCount,
                          onTap: () => _showLikesList(post.id),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                        _buildStatItem(
                          theme,
                          icon: Icons.comment_rounded,
                          count: post.commentsCount,
                          onTap: () => _focusCommentInput(),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                        _buildStatItem(
                          theme,
                          icon: Icons.share_rounded,
                          count: post.sharesCount,
                          onTap: () => _sharePost(post),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _handleLike(post.id),
                            icon: Icon(
                              post.isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                            ),
                            label: Text(post.isLiked ? 'Liked' : 'Like'),
                            style: FilledButton.styleFrom(
                              backgroundColor: post.isLiked
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              foregroundColor: post.isLiked
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _focusCommentInput(),
                            icon: const Icon(Icons.comment_rounded, size: 20),
                            label: const Text('Comment'),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              foregroundColor: colorScheme.onSurface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Comments section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final commentsCount = ref.watch(
                      postCommentsCountProvider(widget.postId),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$commentsCount',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Comments list
        Consumer(
          builder: (context, ref, child) {
            final commentsAsync = ref.watch(
              postCommentsProvider(widget.postId),
            );

            return commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.comment_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No comments yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to share your thoughts!',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CommentsThread(
                          comment: comments[index],
                          onReply: (commentId) => _replyToComment(commentId),
                          onLike: (commentId) => _likeComment(commentId),
                          onReport: (commentId) => _reportComment(commentId),
                          onDelete: (commentId) => _deleteComment(commentId),
                          postAuthorId: post.authorId,
                        ),
                      ),
                      childCount: comments.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: LoadingWidget()),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load comments',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Bottom padding for comment input
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildStatColumn(
    ThemeData theme, {
    required IconData icon,
    required int count,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Alias for backward compatibility
  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    return _buildStatColumn(
      theme,
      icon: icon,
      count: count,
      label: '',
      onTap: onTap,
    );
  }

  Widget _buildCommentInput(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Prevent DOM errors by checking if widget is still mounted
    if (!mounted) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply indicator
            if (_replyingToCommentId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Replying to comment',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() => _replyingToCommentId = null),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Comment input
            CommentInput(
              controller: _commentController,
              focusNode: _commentFocus,
              hintText: _replyingToCommentId != null
                  ? 'Write a reply...'
                  : 'Add a comment...',
              onSubmit: (content) => _submitComment(content),
              onChanged: (text) {
                // Handle mention suggestions
                _handleCommentTextChanged(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        _sharePost(null);
        break;
      case 'copy_link':
        _copyPostLink();
        break;
      case 'report':
        _reportPost();
        break;
    }
  }

  void _handleLike(String postId) async {
    try {
      final socialService = SocialService();
      await socialService.toggleLike(postId);

      // Refresh post details to get updated like count
      ref.invalidate(postDetailsProvider(postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to toggle like: $e')));
      }
    }
  }

  void _focusCommentInput() {
    _commentFocus.requestFocus();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _replyToComment(String commentId) {
    setState(() => _replyingToCommentId = commentId);
    _focusCommentInput();
  }

  void _submitComment(String content) async {
    if (content.trim().isEmpty) return;

    try {
      // Check cooldown before allowing comment creation
      final moderationService = ref.read(moderationServiceProvider);
      final cooldownResult = await moderationService.checkAndBumpCooldown(
        'comment',
        windowSeconds: 300, // 5 minute window
        limitCount: 20, // 20 comments per 5 minutes
      );

      if (!cooldownResult.allowed) {
        if (mounted) {
          final resetTime = DateFormat('HH:mm').format(cooldownResult.resetAt);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You\'ve reached the comment limit. Try again at $resetTime. '
                'Remaining: ${cooldownResult.remaining} comments.',
              ),
            ),
          );
        }
        return;
      }

      final success = await ref
          .read(socialFeedControllerProvider.notifier)
          .addComment(
            postId: widget.postId,
            content: content,
            parentCommentId: _replyingToCommentId,
          );

      if (success) {
        _commentController.clear();
        setState(() => _replyingToCommentId = null);

        // Refresh comments to show the new comment
        ref.invalidate(postCommentsProvider(widget.postId));

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Comment added')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add comment')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
        );
      }
    }
  }

  void _handleCommentTextChanged(String text) {
    // Handle @mentions in comments
    final selection = _commentController.selection;
    if (selection.baseOffset > 0) {
      final beforeCursor = text.substring(0, selection.baseOffset);
      final words = beforeCursor.split(' ');
      final lastWord = words.isNotEmpty ? words.last : '';

      if (lastWord.startsWith('@') && lastWord.length > 1) {
        // Trigger mention suggestions for query: ${lastWord.substring(1)}
      }
    }
  }

  void _likeComment(String commentId) async {
    try {
      final socialService = SocialService();
      await socialService.toggleCommentLike(commentId);

      // Refresh comments to get updated like count and status
      ref.invalidate(postCommentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle comment like: $e')),
        );
      }
    }
  }

  void _deleteComment(String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final socialService = SocialService();
                await socialService.deleteComment(commentId);

                // Refresh comments
                ref.invalidate(postCommentsProvider(widget.postId));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete comment: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _reportComment(String commentId) {
    // Show report dialog
    showDialog(
      context: context,
      builder: (context) =>
          ReportDialog(type: ReportType.comment, commentId: commentId),
    );
  }

  void _editPost(dynamic post) {
    Navigator.pushNamed(
      context,
      '/social/edit-post',
      arguments: {'post': post},
    );
  }

  void _deletePost(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(socialFeedControllerProvider.notifier)
                  .deletePost(postId);

              if (success && mounted) {
                Navigator.pop(context); // Go back to feed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _blockUser(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'Are you sure you want to block this user? You won\'t see their posts anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement block user
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _sharePost(dynamic post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SharePostBottomSheet(post: post),
    );
  }

  void _copyPostLink() {
    final link = 'https://dabbler.app/post/${widget.postId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
  }

  void _reportPost() {
    showDialog(
      context: context,
      builder: (context) =>
          ReportDialog(type: ReportType.post, postId: widget.postId),
    );
  }

  void _showLikesList(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LikesListSheet(postId: postId),
    );
  }

  void _viewMedia(List<dynamic> media, int initialIndex) {
    Navigator.pushNamed(
      context,
      '/media-viewer',
      arguments: {'media': media, 'initialIndex': initialIndex},
    );
  }

  void _navigateToProfile(String userId) {
    context.go('${RoutePaths.userProfile}/$userId');
  }

  void _searchHashtag(String hashtag) {
    Navigator.pushNamed(
      context,
      '/social/hashtag',
      arguments: {'hashtag': hashtag},
    );
  }

  Future<bool> _checkPostTakedown(String postId) async {
    try {
      final moderationService = ref.read(moderationServiceProvider);
      return await moderationService.isContentTakedown(ModTarget.post, postId);
    } catch (e) {
      // If check fails, assume not takedown to avoid blocking content
      return false;
    }
  }

  Widget _buildTakedownPlaceholder(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Content Removed',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This content has been removed due to a violation of our community guidelines.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Likes list bottom sheet
class LikesListSheet extends ConsumerWidget {
  final String postId;

  const LikesListSheet({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final likesAsync = ref.watch(postLikesProvider(postId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Likes',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: likesAsync.when(
              data: (likes) => ListView.builder(
                itemCount: likes.length,
                itemBuilder: (context, index) {
                  final like = likes[index];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          like.avatarUrl != null && like.avatarUrl!.isNotEmpty
                          ? NetworkImage(like.avatarUrl!)
                          : null,
                      child: like.avatarUrl == null || like.avatarUrl!.isEmpty
                          ? Text(like.displayName[0].toUpperCase())
                          : null,
                    ),
                    title: Text(like.displayName),
                    subtitle: Text('@${like.email}'),
                    trailing: const Icon(
                      Icons.favorite,
                    ), // Default to like icon for now
                    onTap: () => _navigateToProfile(context, like.id),
                  );
                },
              ),
              loading: () => const Center(child: LoadingWidget()),
              error: (error, stack) =>
                  Center(child: Text('Error loading likes: $error')),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userId) {
    context.go('${RoutePaths.userProfile}/$userId');
  }
}

/// Report dialog
class ReportDialog extends ConsumerStatefulWidget {
  final ReportType type;
  final String? postId;
  final String? commentId;

  const ReportDialog({
    super.key,
    required this.type,
    this.postId,
    this.commentId,
  });

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reportReasons = [
    'Spam',
    'Harassment',
    'Inappropriate content',
    'False information',
    'Hate speech',
    'Violence',
    'Other',
  ];

  /// Map UI reason string to ReportReason enum
  ReportReason _mapReasonToEnum(String reason) {
    switch (reason.toLowerCase()) {
      case 'spam':
        return ReportReason.spam;
      case 'harassment':
        return ReportReason.harassment;
      case 'inappropriate content':
      case 'nudity':
        return ReportReason.nudity;
      case 'false information':
      case 'scam':
        return ReportReason.scam;
      case 'hate speech':
      case 'hate':
        return ReportReason.hate;
      case 'violence':
      case 'danger':
        return ReportReason.danger;
      case 'abuse':
        return ReportReason.abuse;
      case 'illegal':
        return ReportReason.illegal;
      case 'impersonation':
        return ReportReason.impersonation;
      default:
        return ReportReason.other;
    }
  }

  /// Map ReportType to ModTarget
  ModTarget _getModTarget() {
    switch (widget.type) {
      case ReportType.post:
        return ModTarget.post;
      case ReportType.comment:
        return ModTarget.comment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report ${widget.type.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why are you reporting this ${widget.type.name}?'),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reportReasons.map((reason) {
              final isSelected = _selectedReason == reason;

              return ChoiceChip(
                label: Text(reason),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedReason = selected ? reason : null);
                },
              );
            }).toList(),
          ),

          if (_selectedReason != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (_selectedReason != null && !_isSubmitting)
              ? _submitReport
              : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Report'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    final reason = _selectedReason;
    if (reason == null) return;

    // Determine target ID based on type
    final targetId = widget.type == ReportType.post
        ? widget.postId
        : widget.commentId;

    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit report: missing target ID'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final moderationService = ref.read(moderationServiceProvider);
      final details = _detailsController.text.trim().isEmpty
          ? null
          : _detailsController.text.trim();

      await moderationService.submitReport(
        target: _getModTarget(),
        targetId: targetId,
        reason: _mapReasonToEnum(reason),
        details: details,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

enum ReportType { post, comment }

/// Simple author data class for passing to PostAuthorWidget
class _AuthorData {
  final String name;
  final String? avatar;
  final bool isVerified;

  _AuthorData({required this.name, this.avatar, this.isVerified = false});
}

/// Helper function to get vibe color from post data
Color _getVibeColor(dynamic post, ColorScheme colorScheme) {
  // Try to get color from primaryVibe data
  if (post.primaryVibe != null && post.primaryVibe is Map) {
    final primaryVibe = post.primaryVibe as Map<String, dynamic>;
    final colorHex = primaryVibe['color_hex'];
    if (colorHex != null && colorHex is String && colorHex.isNotEmpty) {
      try {
        // Parse hex color (format: #RRGGBB or RRGGBB)
        final hexColor = colorHex.replaceAll('#', '');
        final colorValue = int.parse(hexColor, radix: 16);
        return Color(0xFF000000 | colorValue);
      } catch (e) {
        // If parsing fails, fall through to default
      }
    }
  }
  // Fallback to secondaryContainer
  return colorScheme.secondaryContainer;
}
