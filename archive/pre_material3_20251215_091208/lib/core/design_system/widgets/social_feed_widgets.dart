import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';

/// Header button for social feed (Home/Arena style)
class SocialHeaderButton extends StatelessWidget {
  final String emoji;
  final String? label;
  final VoidCallback? onTap;

  const SocialHeaderButton({
    super.key,
    required this.emoji,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? AppSpacing.lg : AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            if (label != null) ...[
              SizedBox(width: AppSpacing.sm),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Input box for "What's on your mind?"
class SocialInputBox extends StatelessWidget {
  final String placeholder;
  final String emoji;
  final VoidCallback? onTap;

  const SocialInputBox({
    super.key,
    required this.placeholder,
    required this.emoji,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              placeholder,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(emoji, style: const TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

/// Social feed post card
class SocialFeedPost extends StatelessWidget {
  final String name;
  final String time;
  final String content;
  final String likeIcon;
  final String likes;
  final String comments;
  final String? avatarUrl;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onMenuTap;

  const SocialFeedPost({
    super.key,
    required this.name,
    required this.time,
    required this.content,
    required this.likeIcon,
    required this.likes,
    required this.comments,
    this.avatarUrl,
    this.onLikeTap,
    this.onCommentTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(color: AppColors.borderDark, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _buildAvatar(context),
          SizedBox(width: AppSpacing.md),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context),
                SizedBox(height: AppSpacing.md),
                // Post content
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                // Like and comment section
                _buildEngagementRow(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.borderDark,
        borderRadius: BorderRadius.circular(24),
        image: avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatarUrl == null
          ? Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // Three dots menu
        GestureDetector(onTap: onMenuTap, child: _ThreeDotsMenu()),
      ],
    );
  }

  Widget _buildEngagementRow(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onLikeTap,
          child: Row(
            children: [
              Text(likeIcon, style: const TextStyle(fontSize: 16)),
              SizedBox(width: AppSpacing.xs),
              Text(
                likes,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.lg),
        GestureDetector(
          onTap: onCommentTap,
          child: Row(
            children: [
              const Text('💬', style: TextStyle(fontSize: 16)),
              SizedBox(width: AppSpacing.xs),
              Text(
                comments,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Three dots menu icon
class _ThreeDotsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          3,
          (index) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
