import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/profile/user_profile.dart';
import 'profile_avatar.dart';

class ProfileHeader extends ConsumerWidget {
  final UserProfile profile;
  final bool isOwnProfile;
  final VoidCallback? onEditPressed;
  final VoidCallback? onMessagePressed;
  final bool showOnlineIndicator;

  const ProfileHeader({
    super.key,
    required this.profile,
    this.isOwnProfile = false,
    this.onEditPressed,
    this.onMessagePressed,
    this.showOnlineIndicator = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  ProfileAvatar(
                    imageUrl: profile.avatarUrl,
                    size: 80,
                    isOwnProfile: isOwnProfile,
                    showEditOverlay: false,
                    onTap: () => _showFullScreenAvatar(context),
                  ),
                  if (showOnlineIndicator)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _isOnline() ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.getDisplayName(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (profile.displayName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                    if (_getLocation().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getLocation(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                profile.bio!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildStatsRow(context),
          const SizedBox(height: 20),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            context,
            'Games',
            _getGamesPlayed().toString(),
            Icons.sports_esports,
          ),
        ),
        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
        Expanded(
          child: _buildStatItem(
            context,
            'Rating',
            _getRating().toStringAsFixed(1),
            Icons.star,
          ),
        ),
        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
        Expanded(
          child: _buildStatItem(
            context,
            'Sports',
            _getSportsCount().toString(),
            Icons.sports,
          ),
        ),
        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
        Expanded(
          child: _buildStatItem(
            context,
            'Level',
            _getOverallLevel(),
            Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (isOwnProfile) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onEditPressed,
          icon: const Icon(Icons.edit),
          label: const Text('Edit Profile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onMessagePressed,
              icon: const Icon(Icons.message_outlined),
              label: const Text('Message'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _sendFriendRequest(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Friend'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }
  }

  void _showFullScreenAvatar(BuildContext context) {
    if (profile.avatarUrl?.isNotEmpty == true) {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          pageBuilder: (context, animation, _) {
            return FadeTransition(
              opacity: animation,
              child: Scaffold(
                backgroundColor: Colors.black.withOpacity(0.9),
                body: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Hero(
                      tag: 'profile-avatar-${profile.id}',
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.9,
                          maxHeight: MediaQuery.of(context).size.height * 0.7,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            profile.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }

  void _sendFriendRequest(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Friend request sent to ${profile.getDisplayName()}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  bool _isOnline() {
    // Mock online status - would be connected to real-time presence
    return DateTime.now().millisecondsSinceEpoch % 2 == 0;
  }

  String _getLocation() {
    // Mock location - would come from profile data
    return profile.city ?? '';
  }

  int _getGamesPlayed() {
    // Mock games played - would come from user statistics
    return 42;
  }

  double _getRating() {
    // Mock rating - would come from user statistics
    return 4.2;
  }

  int _getSportsCount() {
    // Would come from sports profiles count
    return 3;
  }

  String _getOverallLevel() {
    // Mock level calculation based on experience
    final rating = _getRating();
    if (rating >= 4.5) return 'Expert';
    if (rating >= 3.5) return 'Advanced';
    if (rating >= 2.5) return 'Inter.';
    return 'Beginner';
  }
}
