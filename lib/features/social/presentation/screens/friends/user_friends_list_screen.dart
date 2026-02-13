import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/features/social/providers/friends_list_provider.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Read-only screen that displays a specific user's friends list.
class UserFriendsListScreen extends ConsumerWidget {
  final String userId;

  const UserFriendsListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(userFriendsListProvider(userId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Could not load friends',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No friends yet',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: friends.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _FriendTile(friend: friend);
            },
          );
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;

  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final userId = friend['user_id'] as String? ?? friend['id'] as String?;
    final displayName = friend['display_name'] as String? ?? 'User';
    final username = friend['username'] as String?;
    final avatarUrl = AvatarService.resolveUrl(friend['avatar_url'] as String?);
    final verified = friend['verified'] as bool? ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: DSAvatar.medium(
        imageUrl: avatarUrl,
        displayName: displayName,
        context: AvatarContext.social,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified, size: 16, color: colorScheme.primary),
          ],
        ],
      ),
      subtitle: username != null
          ? Text(
              '@$username',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: () {
        if (userId != null) {
          context.push('${RoutePaths.userProfile}/$userId');
        }
      },
    );
  }
}
