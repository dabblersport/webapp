import 'package:flutter/material.dart';
import '../../../../../utils/enums/social_enums.dart';

class PostActionsWidget extends StatelessWidget {
  final dynamic post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final Function(ReactionType)? onReaction;

  const PostActionsWidget({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Action buttons
        Row(
          children: [
            _buildActionButton(
              theme,
              icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
              label: '${post.likesCount}',
              isActive: post.isLiked,
              onTap: onLike,
              color: post.isLiked ? Colors.red : null,
            ),

            const SizedBox(width: 16),

            _buildActionButton(
              theme,
              icon: Icons.comment_outlined,
              label: '${post.commentsCount}',
              onTap: onComment,
            ),

            const SizedBox(width: 16),

            _buildActionButton(
              theme,
              icon: Icons.share_outlined,
              label: '${post.sharesCount}',
              onTap: onShare,
            ),

            const Spacer(),

            // Reaction picker
            _buildReactionPicker(theme),
          ],
        ),

        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(
            color: theme.colorScheme.outline.withOpacity(0.2),
            height: 1,
          ),
        ),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  color ??
                  (isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionPicker(ThemeData theme) {
    return PopupMenuButton<ReactionType>(
      onSelected: onReaction,
      itemBuilder: (context) => [
        _buildReactionMenuItem(theme, ReactionType.like, '👍', 'Like'),
        _buildReactionMenuItem(theme, ReactionType.love, '❤️', 'Love'),
        _buildReactionMenuItem(theme, ReactionType.laugh, '😂', 'Laugh'),
        _buildReactionMenuItem(theme, ReactionType.wow, '😮', 'Wow'),
        _buildReactionMenuItem(theme, ReactionType.sad, '😢', 'Sad'),
        _buildReactionMenuItem(theme, ReactionType.angry, '😠', 'Angry'),
        _buildReactionMenuItem(
          theme,
          ReactionType.celebrate,
          '🎉',
          'Celebrate',
        ),
        _buildReactionMenuItem(theme, ReactionType.support, '🤝', 'Support'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_reaction_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'React',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<ReactionType> _buildReactionMenuItem(
    ThemeData theme,
    ReactionType reactionType,
    String emoji,
    String label,
  ) {
    return PopupMenuItem<ReactionType>(
      value: reactionType,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
