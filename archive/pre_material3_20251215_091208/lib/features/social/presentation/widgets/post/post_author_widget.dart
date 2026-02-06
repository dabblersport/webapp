import 'package:flutter/material.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';

class PostAuthorWidget extends StatelessWidget {
  final dynamic author;
  final DateTime createdAt;
  final String? city;
  final bool isEdited;
  final VoidCallback? onProfileTap;
  final List<PostAction>? actions;

  const PostAuthorWidget({
    super.key,
    required this.author,
    required this.createdAt,
    this.city,
    this.isEdited = false,
    this.onProfileTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Author avatar
        AppAvatar.small(
          imageUrl: author.avatar,
          fallbackText: author.name,
          onTap: onProfileTap,
        ),

        const SizedBox(width: 12),

        // Author info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    author.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (author.isVerified)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.verified,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),

              Row(
                children: [
                  Text(
                    _formatTime(createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  if (city != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.location_city_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      city!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  if (isEdited) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(edited)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Actions menu
        if (actions != null && actions!.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            itemBuilder: (context) => actions!.map((action) {
              return PopupMenuItem<String>(
                value: action.label,
                child: ListTile(
                  leading: Icon(
                    action.icon,
                    color: action.isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    action.label,
                    style: TextStyle(
                      color: action.isDestructive
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    action.onTap();
                  },
                ),
              );
            }).toList(),
          ),
      ],
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

class PostAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}
