import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';

/// Main social feed screen
class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return TwoSectionLayout(
      topBackgroundColor: AppColors.categoryBgSocial(context),
      topSection: _buildTopSection(),
      bottomSection: _buildBottomSection(),
    );
  }

  Widget _buildTopSection() {
    return Column(
      children: [
        SizedBox(height: AppSpacing.md),
        // Header with home and arena buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SocialHeaderButton(
              emoji: '🏠',
              onTap: () {
                // Navigate to home
              },
            ),
            SocialHeaderButton(
              emoji: '🌏',
              label: 'Arenas',
              onTap: () {
                // Navigate to arenas
              },
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        // What's on your mind input
        SocialInputBox(
          placeholder: "What's on your mind?",
          emoji: '📝',
          onTap: () {
            // Open create post screen
          },
        ),
        SizedBox(height: AppSpacing.sectionSpacing),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Feed posts
        SocialFeedPost(
          name: 'Sarah',
          time: '2h',
          content:
              "Had an amazing time at the community cooking class today! 🍳 Learning new recipes and meeting wonderful people. Next week we're doing Italian cuisine!",
          likeIcon: '🩶',
          likes: '24',
          comments: '8',
          onLikeTap: () {
            // Handle like
          },
          onCommentTap: () {
            // Handle comment
          },
          onMenuTap: () {
            // Handle menu
          },
        ),
        SizedBox(height: AppSpacing.lg),
        SocialFeedPost(
          name: 'Sarah',
          time: '2h',
          content:
              "Had an amazing time at the community cooking class today! 🍳 Learning new recipes and meeting wonderful people. Next week we're doing Italian cuisine!",
          likeIcon: '❤️',
          likes: '24',
          comments: '8',
          onLikeTap: () {
            // Handle like
          },
          onCommentTap: () {
            // Handle comment
          },
        ),
        SizedBox(height: AppSpacing.lg),
        SocialFeedPost(
          name: 'Sarah',
          time: '2h',
          content:
              "Had an amazing time at the community cooking class today! 🍳 Learning new recipes and meeting wonderful people. Next week we're doing Italian cuisine!",
          likeIcon: '🩶',
          likes: '24',
          comments: '8',
        ),
        SizedBox(height: AppSpacing.lg),
        SocialFeedPost(
          name: 'Sarah',
          time: '2h',
          content:
              "Had an amazing time at the community cooking class today! 🍳 Learning new recipes and meeting wonderful people. Next week we're doing Italian cuisine!",
          likeIcon: '🩶',
          likes: '24',
          comments: '8',
        ),
        SizedBox(height: AppSpacing.lg),
        SocialFeedPost(
          name: 'Sarah',
          time: '2h',
          content:
              "Had an amazing time at the community cooking class today! 🍳 Learning new recipes and meeting wonderful people. Next week we're doing Italian cuisine!",
          likeIcon: '🩶',
          likes: '24',
          comments: '8',
        ),
      ],
    );
  }
}
