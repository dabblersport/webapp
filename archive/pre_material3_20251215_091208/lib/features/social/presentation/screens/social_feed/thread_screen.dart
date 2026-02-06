import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/widgets/loading_widget.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';
import 'package:dabbler/features/social/providers/social_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/comments/comments_thread.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/features/social/presentation/widgets/reactions_bar.dart';
import 'package:dabbler/features/social/presentation/widgets/mentions_list.dart';
import 'package:dabbler/features/social/presentation/widgets/location_tag.dart';
import '../../../services/social_service.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

class ThreadScreen extends ConsumerStatefulWidget {
  final String postId;

  const ThreadScreen({super.key, required this.postId});

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final postAsync = ref.watch(postDetailsProvider(widget.postId));

    return postAsync.when(
      data: (post) => FutureBuilder<bool>(
        future: _checkPostTakedown(post.id),
        builder: (context, takedownSnapshot) {
          if (takedownSnapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: _getVibeColor(
                post,
                colorScheme,
              ).withOpacity(0.1),
              body: const Center(child: LoadingWidget()),
            );
          }

          final isTakedown = takedownSnapshot.data ?? false;
          if (isTakedown) {
            return Scaffold(
              backgroundColor: _getVibeColor(
                post,
                colorScheme,
              ).withOpacity(0.1),
              body: SafeArea(child: _buildTakedownPlaceholder(context, theme)),
            );
          }

          return SingleSectionLayout(
            withScaffold: true,
            scrollable: false,
            padding: EdgeInsets.zero,
            backgroundColor: _getVibeColor(post, colorScheme).withOpacity(0.2),
            child: Column(
              children: [
                Expanded(child: _buildThreadContent(context, theme, post)),
                _buildCommentInput(context, theme),
              ],
            ),
          );
        },
      ),
      loading: () => Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: LoadingWidget()),
      ),
      error: (error, stack) => SingleSectionLayout(
        withScaffold: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.danger, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load thread',
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
                  icon: const Icon(Iconsax.refresh),
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
    );
  }

  Widget _buildThreadContent(
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
        // Header with back button and post info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.arrow_left_copy),
                ),
                const SizedBox(width: 12),
                // Avatar
                GestureDetector(
                  onTap: () => _navigateToProfile(post.authorId),
                  child: AppAvatar(
                    imageUrl: post.authorAvatar,
                    fallbackText: post.authorName,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 12),
                // Name, time, and post type badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and time row
                      Row(
                        children: [
                          Text(
                            post.authorName,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•',
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeAgo(post.createdAt),
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Post type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getPostTypeColor(colorScheme, post.kind),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getPostTypeLabel(post.kind),
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: _getPostTypeTextColor(
                              colorScheme,
                              post.kind,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwnPost)
                  PopupMenuButton(
                    icon: Icon(Iconsax.more_copy, color: colorScheme.onSurface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Iconsax.edit_copy, size: 20),
                            const SizedBox(width: 12),
                            const Text('Edit'),
                          ],
                        ),
                        onTap: () => _editPost(post),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.trash_copy,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                        onTap: () => _deletePost(post.id),
                      ),
                    ],
                  )
                else
                  PopupMenuButton(
                    icon: Icon(Iconsax.more_copy, color: colorScheme.onSurface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'hide',
                        child: Row(
                          children: [
                            Icon(Iconsax.eye_slash_copy, size: 20),
                            const SizedBox(width: 12),
                            const Text('Hide Post'),
                          ],
                        ),
                        onTap: () => _hidePost(post.id),
                      ),
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.flag_copy,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Report',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                        onTap: () => _reportPostWithData(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 0)),

        // Post content card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _getVibeColor(post, colorScheme).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.content.isNotEmpty) ...[
                      Text(
                        post.content,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 17,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Mentions
                    if (post.mentions != null && post.mentions.isNotEmpty) ...[
                      MentionsList(
                        mentions: post.mentions,
                        onMentionTap: (mention) {
                          final profile = mention['profiles'] ?? mention;
                          final userId = profile['user_id'] ?? profile['id'];
                          if (userId != null) _navigateToProfile(userId);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Location tag
                    if (post.locationTag != null) ...[
                      PostLocationTag(
                        locationTag: post.locationTag,
                        onTap: () => _openLocationDetails(post.locationTag),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Media display
                    if (post.mediaUrls.isNotEmpty) ...[
                      _buildMediaContent(post, colorScheme),
                      const SizedBox(height: 12),
                    ],
                    // Vibes and actions row (matching post card style)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          // Primary vibe pill
                          if (post.vibeEmoji != null && post.vibeLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getVibeColor(
                                  post,
                                  colorScheme,
                                ).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    post.vibeEmoji ?? '😊',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    post.vibeLabel ?? 'Vibe',
                                    style: textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          // Like action
                          _buildActionButton(
                            context: context,
                            theme: theme,
                            icon: Iconsax.heart_copy,
                            label: post.likesCount.toString(),
                            isActive: post.isLiked,
                            onTap: () => _handleLike(post.id),
                          ),
                          const SizedBox(width: 16),
                          // Comment action
                          _buildActionButton(
                            context: context,
                            theme: theme,
                            icon: Iconsax.message_copy,
                            label: post.commentsCount.toString(),
                            isActive: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Reactions section (if exists)
        if (post.reactions != null && post.reactions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  ReactionsBar(
                    reactions: post.reactions,
                    currentUserId: currentUserId,
                    onReactionTap: (data) =>
                        _showReactionsModal(post.reactions),
                  ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Comments section header
        // SliverToBoxAdapter(
        //   child: Padding(
        //     padding: const EdgeInsets.symmetric(horizontal: 24),
        //     child: Row(
        //       children: [
        //         Text(
        //           'Replies',
        //           style: textTheme.titleLarge?.copyWith(
        //             fontWeight: FontWeight.w700,
        //             color: colorScheme.onSurface,
        //           ),
        //         ),
        //         const SizedBox(width: 8),
        //         Consumer(
        //           builder: (context, ref, child) {
        //             final commentsCount = ref.watch(
        //               postCommentsCountProvider(widget.postId),
        //             );
        //             return Container(
        //               padding: const EdgeInsets.symmetric(
        //                 horizontal: 10,
        //                 vertical: 4,
        //               ),
        //               decoration: BoxDecoration(
        //                 color: colorScheme.primaryContainer,
        //                 borderRadius: BorderRadius.circular(12),
        //               ),
        //               child: Text(
        //                 '$commentsCount',
        //                 style: textTheme.labelMedium?.copyWith(
        //                   color: colorScheme.onPrimaryContainer,
        //                   fontWeight: FontWeight.w600,
        //                 ),
        //               ),
        //             );
        //           },
        //         ),
        //       ],
        //     ),
        //   ),
        // ),

        // Comments list with nested replies
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
                              Iconsax.message_copy,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No replies yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to reply!',
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
                          onReply:
                              null, // Reply functionality is handled by the composer
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
                          'Failed to load replies',
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

  Widget _buildActionButton({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // Use filled heart icon when liked (active)
    final displayIcon = icon == Iconsax.heart_copy && isActive
        ? Iconsax.heart
        : icon;

    final isLikeButton = icon == Iconsax.heart_copy;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            displayIcon,
            size: 24,
            color: isLikeButton && isActive
                ? Colors.red
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(dynamic post, ColorScheme colorScheme) {
    if (post.mediaUrls.isEmpty) return const SizedBox.shrink();

    final mediaUrl = post.mediaUrls.first;
    final isVideo =
        mediaUrl.contains('.mp4') ||
        mediaUrl.contains('.mov') ||
        mediaUrl.contains('.avi');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: isVideo
            ? Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                    child: Icon(
                      Iconsax.play_copy,
                      color: colorScheme.primary,
                      size: 40,
                    ),
                  ),
                ),
              )
            : Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Iconsax.gallery_slash_copy,
                      color: colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _getPostTypeLabel(String kind) {
    final kindLower = kind.toLowerCase();
    switch (kindLower) {
      case 'moment':
        return 'Moments';
      case 'dab':
        return 'Dab';
      case 'kickin':
        return 'Kick-in';
      default:
        return 'Moments';
    }
  }

  Color _getPostTypeColor(ColorScheme colorScheme, String kind) {
    final kindLower = kind.toLowerCase();
    switch (kindLower) {
      case 'moment':
        return colorScheme.primaryContainer.withOpacity(0.3);
      case 'dab':
        return colorScheme.secondaryContainer.withOpacity(0.3);
      case 'kickin':
        return colorScheme.tertiaryContainer.withOpacity(0.3);
      default:
        return colorScheme.primaryContainer.withOpacity(0.3);
    }
  }

  Color _getPostTypeTextColor(ColorScheme colorScheme, String kind) {
    final kindLower = kind.toLowerCase();
    switch (kindLower) {
      case 'moment':
        return colorScheme.primary;
      case 'dab':
        return colorScheme.secondary;
      case 'kickin':
        return colorScheme.tertiary;
      default:
        return colorScheme.primary;
    }
  }

  Color _getVibeColor(dynamic post, ColorScheme colorScheme) {
    // Try to get color from primaryVibe data
    if (post.primaryVibe != null && post.primaryVibe is Map) {
      final colorHex = post.primaryVibe['color_hex'];
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

  Widget _buildCommentInput(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    // Prevent DOM errors by checking if widget is still mounted
    if (!mounted) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      decoration: BoxDecoration(
        // color: colorScheme.surface,
        // border: Border(
        //   top: BorderSide(
        //     color: colorScheme.outlineVariant.withOpacity(0.3),
        //     width: 1,
        //   ),
        // ),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a reply...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? colorScheme.surfaceContainerLow
                      : colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 15,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              icon: _isSubmittingComment
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(Iconsax.send_1, color: colorScheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final canProceed = await _checkUserStatus();
    if (!canProceed) return;

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final socialService = SocialService();
      await socialService.addComment(postId: widget.postId, body: content);

      _commentController.clear();

      // Refresh comments and post details
      ref.invalidate(postCommentsProvider(widget.postId));
      ref.invalidate(postDetailsProvider(widget.postId));

      // Scroll to bottom to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reply added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add reply: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  Future<bool> _checkUserStatus() async {
    try {
      final moderationService = ref.read(moderationServiceProvider);
      final currentUserId = ref.read(currentUserIdProvider);

      if (currentUserId.isEmpty) {
        return true; // Allow if not logged in (will fail auth anyway)
      }

      final isFrozen = await moderationService.isUserFrozen(currentUserId);
      final isShadowbanned = await moderationService.isUserShadowbanned(
        currentUserId,
      );

      if (isFrozen || isShadowbanned) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFrozen
                    ? 'Your account has been frozen. Please contact support.'
                    : 'Your account has been restricted. Some actions are disabled.',
              ),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      // If check fails, allow action (fail-safe)
      return true;
    }
  }

  void _handleLike(String postId) async {
    final canProceed = await _checkUserStatus();
    if (!canProceed) return;
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

  void _likeComment(String commentId) async {
    final canProceed = await _checkUserStatus();
    if (!canProceed) return;

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
        title: const Text('Delete Reply'),
        content: const Text('Are you sure you want to delete this reply?'),
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
                ref.invalidate(postDetailsProvider(widget.postId));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete reply: $e')),
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

  void _navigateToProfile(String userId) {
    context.go('${RoutePaths.userProfile}/$userId');
  }

  void _openLocationDetails(Map<String, dynamic>? locationTag) {
    if (locationTag == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final lat = locationTag['lat'] as double?;
        final lng = locationTag['lng'] as double?;
        final name = locationTag['name'] as String?;
        final address = locationTag['address'] as String?;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Iconsax.location_copy, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name ?? 'Location',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle_copy),
                  ),
                ],
              ),
              if (address != null) ...[
                const SizedBox(height: 16),
                Text(
                  address,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (lat != null && lng != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Coordinates: $lat, $lng',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    // Open in maps app
                    final url =
                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                    // Use url_launcher package to open
                  },
                  icon: const Icon(Iconsax.map_copy),
                  label: const Text('Open in Maps'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showReactionsModal(List<dynamic>? reactions) {
    if (reactions == null || reactions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Reactions',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle_copy),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final reaction = reactions[index];
                    final user = reaction['user'];
                    final emoji = reaction['emoji'] ?? '👍';
                    final userName = user?['display_name'] ?? 'Anonymous';
                    final userAvatar = user?['avatar_url'];

                    return ListTile(
                      leading: AppAvatar(
                        imageUrl: userAvatar,
                        fallbackText: userName,
                        size: 40,
                      ),
                      title: Text(
                        userName,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (user?['user_id'] != null) {
                          _navigateToProfile(user['user_id']);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _hidePost(String postId) async {
    try {
      final svc = SocialService();
      await svc.hidePost(postId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post hidden')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to hide post: $e')));
      }
    }
  }

  void _reportPostWithData() {
    showDialog(
      context: context,
      builder: (context) =>
          ReportDialog(type: ReportType.post, postId: widget.postId),
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
              Iconsax.close_circle_copy,
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
