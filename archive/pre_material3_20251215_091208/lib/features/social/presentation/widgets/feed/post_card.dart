import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/features/social/services/social_service.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';

/// A card widget for displaying social posts in the feed
class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onPostTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onDelete;
  final bool isOptimistic;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onPostTap,
    this.onProfileTap,
    this.onDelete,
    this.isOptimistic = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // Track the optimistic state separately
  bool? _optimisticLiked;
  int? _optimisticCount;

  // Track if we're waiting for server response
  bool _isProcessing = false;

  // Store the expected server state after our action
  bool? _expectedLiked;
  int? _expectedCount;

  // Computed values that prioritize optimistic state
  bool get _displayLiked => _optimisticLiked ?? widget.post.isLiked;
  int get _displayCount => _optimisticCount ?? widget.post.likesCount;

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Different post, reset everything
    if (oldWidget.post.id != widget.post.id) {
      _optimisticLiked = null;
      _optimisticCount = null;
      _expectedLiked = null;
      _expectedCount = null;
      _isProcessing = false;
      return;
    }

    // If we have expected values and server state matches, clear optimistic state
    if (_expectedLiked != null && _expectedCount != null) {
      if (widget.post.isLiked == _expectedLiked &&
          widget.post.likesCount == _expectedCount) {
        // Server confirmed our optimistic action
        if (mounted) {
          setState(() {
            _optimisticLiked = null;
            _optimisticCount = null;
            _expectedLiked = null;
            _expectedCount = null;
            _isProcessing = false;
          });
        }
      } else {}
    }
  }

  void _handleLikeTap() {
    if (_isProcessing) return;

    final currentLiked = widget.post.isLiked;
    final currentCount = widget.post.likesCount;
    final newLiked = !currentLiked;
    final newCount = newLiked
        ? currentCount + 1
        : (currentCount > 0 ? currentCount - 1 : 0);

    setState(() {
      _isProcessing = true;
      _optimisticLiked = newLiked;
      _optimisticCount = newCount;
      _expectedLiked = newLiked;
      _expectedCount = newCount;
    });

    // Call the parent callback
    widget.onLike?.call();

    // Safety timeout: if server doesn't respond in 3 seconds, reset
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isProcessing) {
        setState(() {
          _optimisticLiked = null;
          _optimisticCount = null;
          _expectedLiked = null;
          _expectedCount = null;
          _isProcessing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      decoration: BoxDecoration(
        color: _getVibeColor(colorScheme).withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        // border: Border.all(
        //   // color: _getVibeColor(colorScheme).withOpacity(0.3),
        //   width: 2,
        // ),
      ),
      padding: const EdgeInsets.all(12),
      child: GestureDetector(
        onTap: widget.onPostTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First Row: Avatar + Display Name and Time + Post type badge + Overflow menu
            _buildHeader(context),

            // Second Row: Content + Media display + Actions (all in card)
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        AppAvatar.small(
          imageUrl: widget.post.authorAvatar,
          fallbackText: widget.post.authorName,
          onTap: widget.onProfileTap,
        ),

        const SizedBox(width: 12),

        // Display Name, Time, and Post type badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and time row
              Row(
                children: [
                  Text(
                    widget.post.authorName,
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
                    _formatTimeAgo(widget.post.createdAt),
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Post type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getVibeColor(colorScheme).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getPostTypeLabel(),
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPostTypeLabel() {
    final kind = widget.post.kind.toLowerCase();
    switch (kind) {
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

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.content.isNotEmpty) ...[
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: _isRtl(widget.post.content)
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Text(
                  widget.post.content,
                  textDirection: _isRtl(widget.post.content)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 17,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Media display
          if (widget.post.mediaUrls.isNotEmpty) ...[
            _buildMediaContent(context),
            const SizedBox(height: 0),
          ],

          // Vibes and actions inline
          _buildActions(context),
        ],
      ),
    );
  }

  bool _isRtl(String text) {
    if (text.isEmpty) return false;
    final firstChar = text.trimLeft().codeUnitAt(0);
    // Arabic Unicode range: 0x0600 to 0x06FF
    // Arabic Supplement: 0x0750 to 0x077F
    // Arabic Extended-A: 0x08A0 to 0x08FF
    return (firstChar >= 0x0600 && firstChar <= 0x06FF) ||
        (firstChar >= 0x0750 && firstChar <= 0x077F) ||
        (firstChar >= 0x08A0 && firstChar <= 0x08FF);
  }

  Widget _buildMediaContent(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.post.mediaUrls.isEmpty) return const SizedBox.shrink();

    final mediaUrl = widget.post.mediaUrls.first;
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
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                    child: Icon(
                      Iconsax.play_copy,
                      color: theme.colorScheme.primary,
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
                    color: theme.colorScheme.surfaceContainerHighest,
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
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Iconsax.gallery_slash_copy,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          // Primary vibe pill
          if (widget.post.vibeEmoji != null && widget.post.vibeLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: _getVibeColor(colorScheme).withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.post.vibeEmoji ?? '😊',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.post.vibeLabel ?? 'Vibe',
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          // Like action - uses computed display values for optimistic updates
          _buildActionButton(
            context: context,
            icon: Iconsax.heart_copy,
            label: _displayCount.toString(),
            isActive: _displayLiked,
            onTap: _handleLikeTap,
          ),
          const SizedBox(width: 12),
          // Comment action
          _buildActionButton(
            context: context,
            icon: Iconsax.message_copy,
            label: widget.post.commentsCount.toString(),
            isActive: false,
            onTap: widget.onComment,
          ),
          const SizedBox(width: 12),
          // Actions menu
          GestureDetector(
            onTap: () => _showActionsDrawer(context),
            child: Icon(
              Iconsax.more_copy,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
          AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 50),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 50),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                displayIcon,
                key: ValueKey(isActive),
                size: 24,
                color: isLikeButton && isActive
                    ? Colors.red
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 50),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              label,
              key: ValueKey(label),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
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

  void _showActionsDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isOwnPost()) ...[
              ListTile(
                leading: Icon(Iconsax.trash_copy, color: colorScheme.error),
                title: Text(
                  'Delete',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost(context);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Iconsax.eye_slash_copy),
                title: const Text('Hide Post'),
                onTap: () {
                  Navigator.pop(context);
                  _hidePost(context);
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.flag_copy),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isOwnPost() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    // Check if the post author's user_id matches current user
    return widget.post.authorId == currentUser.id;
  }

  Future<void> _deletePost(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await SocialService().deletePost(widget.post.id);

      if (!mounted) return;

      // Call the onDelete callback if provided
      widget.onDelete?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
    }
  }

  Future<void> _hidePost(BuildContext context) async {
    try {
      await SocialService().hidePost(widget.post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post hidden')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to hide post: $e')));
    }
  }

  Future<void> _reportPost(BuildContext context) async {
    try {
      // Simple quick-report flow; use ThreadScreen dialog for detailed flow
      await SocialService().reportPost(
        postId: widget.post.id,
        reason: 'Inappropriate content',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to report: $e')));
    }
  }

  Color _getVibeColor(ColorScheme colorScheme) {
    // Try to get color from primaryVibe data
    if (widget.post.primaryVibe != null && widget.post.primaryVibe is Map) {
      final primaryVibe = widget.post.primaryVibe!;
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
}
