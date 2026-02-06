import 'package:flutter/material.dart';

class FriendProfileHeader extends StatelessWidget {
  final dynamic friend;
  final String friendshipStatus;
  final bool isBlocked;

  const FriendProfileHeader({
    super.key,
    required this.friend,
    required this.friendshipStatus,
    required this.isBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              backgroundImage: friend.avatarUrl != null
                  ? NetworkImage(friend.avatarUrl)
                  : null,
              child: friend.avatarUrl == null
                  ? Icon(
                      Icons.person,
                      size: 50,
                      color: theme.colorScheme.primary,
                    )
                  : null,
            ),

            const SizedBox(height: 16),

            // Name and Username
            Text(
              friend.name ?? 'Unknown User',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            if (friend.username != null) ...[
              const SizedBox(height: 4),
              Text(
                '@${friend.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Friendship Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(theme).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(theme), width: 1),
              ),
              child: Text(
                friendshipStatus,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(theme),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  theme,
                  'Friends',
                  friend.friendsCount?.toString() ?? '0',
                ),
                _buildStatItem(
                  theme,
                  'Activities',
                  friend.activitiesCount?.toString() ?? '0',
                ),
                _buildStatItem(theme, 'Level', friend.level?.toString() ?? '1'),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ThemeData theme) {
    if (isBlocked) return theme.colorScheme.error;

    switch (friendshipStatus.toLowerCase()) {
      case 'friends':
        return theme.colorScheme.primary;
      case 'request sent':
        return theme.colorScheme.secondary;
      case 'request received':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.outline;
    }
  }
}
