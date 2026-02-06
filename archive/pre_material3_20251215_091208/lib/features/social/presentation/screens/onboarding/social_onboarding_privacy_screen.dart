import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Privacy settings introduction screen for social onboarding
class SocialOnboardingPrivacyScreen extends StatefulWidget {
  const SocialOnboardingPrivacyScreen({super.key});

  @override
  State<SocialOnboardingPrivacyScreen> createState() =>
      _SocialOnboardingPrivacyScreenState();
}

class _SocialOnboardingPrivacyScreenState
    extends State<SocialOnboardingPrivacyScreen> {
  bool _profileVisibleToFriends = true;
  bool _postsVisibleToPublic = false;
  bool _allowFriendRequests = true;
  bool _allowMessageRequests = true;
  bool _showOnlineStatus = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Indicator
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: 0.75, // 3 out of 4 steps
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '3 of 4',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Header
            Icon(Icons.shield, size: 64, color: Theme.of(context).primaryColor),
            const SizedBox(height: 24),

            Text(
              'Privacy & Safety',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Text(
              'Control who can see your profile and interact with you. You can always change these settings later.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Privacy Settings
            Expanded(
              child: ListView(
                children: [
                  _buildPrivacyOption(
                    title: 'Profile Visible to Friends',
                    subtitle: 'Your profile is visible to your friends',
                    value: _profileVisibleToFriends,
                    onChanged: (value) {
                      setState(() {
                        _profileVisibleToFriends = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Posts Visible to Public',
                    subtitle: 'Anyone can see your posts',
                    value: _postsVisibleToPublic,
                    onChanged: (value) {
                      setState(() {
                        _postsVisibleToPublic = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Allow Friend Requests',
                    subtitle: 'People can send you friend requests',
                    value: _allowFriendRequests,
                    onChanged: (value) {
                      setState(() {
                        _allowFriendRequests = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Allow Message Requests',
                    subtitle: 'Non-friends can send you messages',
                    value: _allowMessageRequests,
                    onChanged: (value) {
                      setState(() {
                        _allowMessageRequests = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Show Online Status',
                    subtitle: 'Friends can see when you\'re online',
                    value: _showOnlineStatus,
                    onChanged: (value) {
                      setState(() {
                        _showOnlineStatus = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/social/onboarding/notifications');
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          value ? Icons.visibility : Icons.visibility_off,
          color: value ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
