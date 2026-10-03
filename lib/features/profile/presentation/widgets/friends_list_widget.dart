import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space5,
          DabblerSpacing.space5,
          DabblerSpacing.space5,
          DabblerSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DabblerSkeleton.rect(width: 120, height: 18),
                DabblerSkeleton.rect(width: 52, height: 14),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space4),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: DabblerSpacing.space2),
                itemBuilder: (context, index) {
                  return const SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        DabblerSkeleton.circle(width: 60),
                        SizedBox(height: DabblerSpacing.space2),
                        DabblerSkeleton.rect(width: 56, height: 12),
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

    final colors = DabblerColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Friends (${friends.length})',
                style: DabblerType.headline
                    .resolveForDirection(Directionality.of(context))
                    .copyWith(color: colors.textPrimary),
              ),
              if (friends.length > 6 && onViewAll != null)
                DabblerButton(
                  label: 'View All',
                  tone: DabblerButtonTone.text,
                  size: DabblerButtonSize.small,
                  onPressed: onViewAll,
                ),
            ],
          ),
        ),
        const SizedBox(height: DabblerSpacing.space5),
      ],
    );
  }
}

// ignore: unused_element
class _FriendAvatarItem extends StatelessWidget {
  final Map<String, dynamic> friend;

  const _FriendAvatarItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final userId = friend['user_id'] as String? ?? friend['id'] as String?;
    final displayName = friend['display_name'] as String? ?? 'User';
    final avatarUrl = friend['avatar_url'] as String?;
    final verified = friend['verified'] as bool? ?? false;

    return GestureDetector(
      onTap: () {
        if (userId != null) {
          context.push('/user-profile/$userId');
        }
      },
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Stack(
              children: [
                DabblerAvatar(
                  seed: displayName,
                  imageUrl: avatarUrl,
                  size: DabblerAvatarSize.lg,
                ),
                if (verified)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: DabblerIcon(
                      'verify',
                      weight: DabblerIconWeight.bold,
                      size: 16,
                      color: colors.brandPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space2),
            Text(
              displayName.length > 10
                  ? '${displayName.substring(0, 10)}...'
                  : displayName,
              style: DabblerType.caption1
                  .resolveForDirection(Directionality.of(context))
                  .copyWith(color: colors.textPrimary),
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
