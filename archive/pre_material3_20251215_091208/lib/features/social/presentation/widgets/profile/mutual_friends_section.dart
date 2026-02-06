import 'package:flutter/material.dart';

class MutualFriendsSection extends StatelessWidget {
  final List<dynamic> mutualFriends;
  final VoidCallback onViewAll;
  final Function(String) onFriendTap;

  const MutualFriendsSection({
    super.key,
    required this.mutualFriends,
    required this.onViewAll,
    required this.onFriendTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mutual Friends',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(onPressed: onViewAll, child: const Text('View All')),
              ],
            ),

            const SizedBox(height: 16),

            if (mutualFriends.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No mutual friends yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  ...mutualFriends
                      .take(6)
                      .map((friend) => _buildFriendTile(theme, friend)),
                  if (mutualFriends.length > 6)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          'And ${mutualFriends.length - 6} more...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(ThemeData theme, dynamic friend) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        backgroundImage: friend.avatarUrl != null
            ? NetworkImage(friend.avatarUrl)
            : null,
        child: friend.avatarUrl == null
            ? Icon(Icons.person, size: 20, color: theme.colorScheme.primary)
            : null,
      ),
      title: Text(
        friend.name ?? 'Unknown User',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        friend.username != null ? '@${friend.username}' : 'No username',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => onFriendTap(friend.id),
    );
  }
}
