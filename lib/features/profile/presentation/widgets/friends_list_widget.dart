import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';

import 'package:dabbler/widgets/app_card.dart';

class FriendsListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> friends;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const FriendsListWidget({
    super.key,
    required this.friends,
    this.isLoading = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      final colorScheme = context.colorScheme;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LoadingPlaceholder(
                  height: 18,
                  width: 120,
                  borderRadius: BorderRadius.circular(6),
                ),
                LoadingPlaceholder(
                  height: 14,
                  width: 52,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Container(
                              color: colorScheme.surfaceContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LoadingPlaceholder(
                          height: 12,
                          width: 56,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Friends (${friends.length})',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (friends.length > 6 && onViewAll != null)
                TextButton(onPressed: onViewAll, child: const Text('View All')),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FriendAvatarItem extends StatelessWidget {
  final Map<String, dynamic> friend;

  const _FriendAvatarItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    final userId = friend['user_id'] as String? ?? friend['id'] as String?;
    final displayName = friend['display_name'] as String? ?? 'User';
    final avatarUrl = resolveAvatarUrl(friend['avatar_url'] as String?);
    final verified = friend['verified'] as bool? ?? false;

    return GestureDetector(
      onTap: () {
        if (userId != null) {
          context.push('/user-profile/$userId');
        }
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colorScheme.outline.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                ),
                if (verified)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified,
                        size: 16,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayName.length > 10
                  ? '${displayName.substring(0, 10)}...'
                  : displayName,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
