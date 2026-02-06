import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';
import '../../providers/social_providers.dart';

class CommentsThread extends ConsumerWidget {
  final dynamic comment;
  final Function(String)? onReply;
  final Function(String)? onLike;
  final Function(String)? onReport;
  final Function(String)? onDelete;
  final String postAuthorId;
  final int nestingLevel;

  const CommentsThread({
    super.key,
    required this.comment,
    this.onReply,
    this.onLike,
    this.onReport,
    this.onDelete,
    required this.postAuthorId,
    this.nestingLevel = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwnComment = comment.authorId == currentUserId;
    final isPostAuthor = comment.authorId == postAuthorId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.only(
            left: nestingLevel > 0 ? 48 : 0,
            right: 16,
            top: 12,
            bottom: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Comment author avatar
              AppAvatar(
                imageUrl: comment.author.avatar,
                fallbackText: comment.author.name,
                size: nestingLevel > 0 ? 28 : 32,
              ),

              const SizedBox(width: 12),

              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comment header
                    Row(
                      children: [
                        Text(
                          comment.author.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: nestingLevel > 0 ? 13 : 14,
                          ),
                        ),

                        if (isPostAuthor)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Author',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontSize: 10,
                              ),
                            ),
                          ),

                        const Spacer(),

                        Text(
                          _formatTime(comment.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: nestingLevel > 0 ? 11 : 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Comment text
                    Text(
                      comment.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.3,
                        fontSize: nestingLevel > 0 ? 13 : 14,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Comment actions - Like and Reply only
                    // Hide Reply button for replies (nestingLevel > 0) since DB only supports 2 levels
                    Row(
                      children: [
                        _buildActionButton(
                          theme,
                          icon: comment.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: comment.likesCount > 0
                              ? '${comment.likesCount}'
                              : 'Like',
                          isActive: comment.isLiked,
                          onTap: () => onLike?.call(comment.id),
                          color: comment.isLiked ? Colors.red : null,
                          size: nestingLevel > 0 ? 14 : 16,
                        ),

                        // Only show Reply button for top-level comments (nestingLevel == 0)
                        if (nestingLevel == 0) ...[
                          const SizedBox(width: 16),
                          _buildActionButton(
                            theme,
                            icon: Icons.reply_rounded,
                            label: 'Reply',
                            onTap: () => onReply?.call(comment.id),
                            size: 16,
                          ),
                        ],

                        const Spacer(),

                        // More options menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz,
                            size: nestingLevel > 0 ? 14 : 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          itemBuilder: (context) => [
                            if (isOwnComment)
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: theme.colorScheme.error,
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () {
                                    Navigator.pop(context);
                                    onDelete?.call(comment.id);
                                  },
                                ),
                              )
                            else
                              PopupMenuItem<String>(
                                value: 'report',
                                child: ListTile(
                                  leading: Icon(Icons.flag_outlined),
                                  title: const Text('Report'),
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () {
                                    Navigator.pop(context);
                                    onReport?.call(comment.id);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Nested replies - recursive rendering
        if (comment.replies != null && comment.replies!.isNotEmpty)
          ...comment.replies!.map<Widget>((reply) {
            return CommentsThread(
              comment: reply,
              onReply: onReply,
              onLike: onLike,
              onReport: onReport,
              onDelete: onDelete,
              postAuthorId: postAuthorId,
              nestingLevel: nestingLevel + 1,
            );
          }).toList(),
      ],
    );
  }

  Widget _buildActionButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
    Color? color,
    double size = 16,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: size,
              color:
                  color ??
                  (isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                fontSize: size - 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${time.day}/${time.month}/${time.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
