import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/data/models/profile/privacy_settings.dart';

enum PrivacyPreset { public, friendsOnly, private }

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Privacy preset
  PrivacyPreset _selectedPreset = PrivacyPreset.public;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Load privacy settings from Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        ref
            .read(privacyControllerProvider.notifier)
            .loadPrivacySettings(userId);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final privacyState = ref.watch(privacyControllerProvider);
    final settings = privacyState.settings;

    // Sync local preset selection when settings first load
    if (settings != null && !_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedPreset = _detectPreset(settings);
        });
      });
    }

    if (privacyState.isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Header
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  sliver: SliverToBoxAdapter(child: _buildHeader(context)),
                ),
                // Hero Card
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(child: _buildHeroCard(context)),
                ),
                // Content
                SliverToBoxAdapter(child: _buildPrivacyPresetsSection(context)),
                SliverToBoxAdapter(
                  child: _buildProfileVisibilitySection(context),
                ),
                SliverToBoxAdapter(child: _buildCommunicationSection(context)),
                SliverToBoxAdapter(
                  child: _buildActivityVisibilitySection(context),
                ),
                SliverToBoxAdapter(
                  child: _buildDiscoverabilitySection(context),
                ),
                SliverToBoxAdapter(child: _buildDataSharingSection(context)),
                SliverToBoxAdapter(child: _buildNotificationsSection(context)),
                SliverToBoxAdapter(child: _buildSecuritySection(context)),
                SliverToBoxAdapter(child: _buildBlockedUsersSection(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Settings',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.check, size: 20),
          label: const Text('Save'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF4A148C) : const Color(0xFFE0C7FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 48,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          const SizedBox(height: 16),
          Text(
            'Control your privacy',
            style: textTheme.headlineSmall?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Manage what information others can see about you and how your data is used.',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPresetsSection(BuildContext context) {
    return _buildSection(
      context,
      'Privacy Presets',
      'Choose a preset to quickly configure your privacy settings',
      [
        ...PrivacyPreset.values.map((preset) {
          return _buildPrivacyPresetCard(context, preset);
        }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade50,
                Colors.blue.shade100.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can always customize individual settings below',
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyPresetCard(BuildContext context, PrivacyPreset preset) {
    final isSelected = _selectedPreset == preset;
    final presetData = _getPresetData(preset);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPreset = preset;
              _applyPreset(preset);
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: presetData['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    presetData['icon'],
                    color: presetData['color'],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        presetData['title'],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        presetData['description'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileVisibilitySection(BuildContext context) {
    final settings = ref.watch(privacyControllerProvider).settings;
    final ctrl = ref.read(privacyControllerProvider.notifier);
    if (settings == null) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Profile & Identity',
      'Control what personal information others can see',
      [
        _buildPrivacyToggle(
          'Profile Photo',
          'Show your profile picture',
          Icons.account_circle_outlined,
          settings.showProfilePhoto,
          (value) => ctrl.updateSetting('showProfilePhoto', value),
          'Your profile photo helps others recognize you',
        ),
        _buildPrivacyToggle(
          'Real Name',
          'Show your full name',
          Icons.person_outline,
          settings.showRealName,
          (value) => ctrl.updateSetting('showRealName', value),
          'Others will see your real name instead of username',
        ),
        _buildPrivacyToggle(
          'Bio',
          'Show your bio on your profile',
          Icons.short_text_outlined,
          settings.showBio,
          (value) => ctrl.updateSetting('showBio', value),
          'Your bio text will be visible on your profile',
        ),
        _buildPrivacyToggle(
          'Age',
          'Show your age on your profile',
          Icons.cake_outlined,
          settings.showAge,
          (value) => ctrl.updateSetting('showAge', value),
          'Your age will be calculated from your date of birth',
        ),
        _buildPrivacyToggle(
          'Email Address',
          'Show your email to others',
          Icons.email_outlined,
          settings.showEmail,
          (value) => ctrl.updateSetting('showEmail', value),
          'Not recommended for privacy reasons',
        ),
        _buildPrivacyToggle(
          'Phone Number',
          'Show your phone number',
          Icons.phone_outlined,
          settings.showPhone,
          (value) => ctrl.updateSetting('showPhone', value),
          'Only visible to teammates for coordination',
        ),
        _buildPrivacyToggle(
          'Location',
          'Show your general location',
          Icons.location_city_outlined,
          settings.showLocation,
          (value) => ctrl.updateSetting('showLocation', value),
          'Helps with local game matching',
        ),
        _buildPrivacyToggle(
          'Friends List',
          'Show your friends publicly',
          Icons.people_outline,
          settings.showFriendsList,
          (value) => ctrl.updateSetting('showFriendsList', value),
          'Others can see who you\'re connected with',
        ),
      ],
    );
  }

  Widget _buildCommunicationSection(BuildContext context) {
    final settings = ref.watch(privacyControllerProvider).settings;
    final ctrl = ref.read(privacyControllerProvider.notifier);
    if (settings == null) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Communication',
      'Control who can contact you and how',
      [
        _buildCommunicationDropdown(
          context,
          'Direct Messages',
          'Who can send you messages',
          Icons.chat_outlined,
          settings.messagePreference,
          (value) => ctrl.updateSetting('messagePreference', value),
        ),
        _buildCommunicationDropdown(
          context,
          'Game Invites',
          'Who can invite you to games',
          Icons.sports_esports_outlined,
          settings.gameInvitePreference,
          (value) => ctrl.updateSetting('gameInvitePreference', value),
        ),
        _buildCommunicationDropdown(
          context,
          'Friend Requests',
          'Who can send you friend requests',
          Icons.person_add_outlined,
          settings.friendRequestPreference,
          (value) => ctrl.updateSetting('friendRequestPreference', value),
        ),
      ],
    );
  }

  Widget _buildCommunicationDropdown(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    CommunicationPreference value,
    ValueChanged<CommunicationPreference> onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<CommunicationPreference>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            items: CommunicationPreference.values.map((pref) {
              return DropdownMenuItem(
                value: pref,
                child: Text(
                  _communicationPrefLabel(pref),
                  style: textTheme.bodySmall,
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ],
      ),
    );
  }

  String _communicationPrefLabel(CommunicationPreference pref) {
    switch (pref) {
      case CommunicationPreference.anyone:
        return 'Anyone';
      case CommunicationPreference.friendsOnly:
        return 'Friends Only';
      case CommunicationPreference.organizersOnly:
        return 'Organizers';
      case CommunicationPreference.none:
        return 'Nobody';
    }
  }

  Widget _buildActivityVisibilitySection(BuildContext context) {
    final settings = ref.watch(privacyControllerProvider).settings;
    final ctrl = ref.read(privacyControllerProvider.notifier);
    if (settings == null) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Activity & Stats',
      'Control visibility of your activity and performance data',
      [
        _buildPrivacyToggle(
          'Online Status',
          'Show when you\'re online',
          Icons.circle,
          settings.showOnlineStatus,
          (value) => ctrl.updateSetting('showOnlineStatus', value),
          'Let others know when you\'re available',
        ),
        _buildPrivacyToggle(
          'Activity Status',
          'Show your recent activity',
          Icons.local_activity_outlined,
          settings.showActivityStatus,
          (value) => ctrl.updateSetting('showActivityStatus', value),
          'Others can see what you\'ve been up to',
        ),
        _buildPrivacyToggle(
          'Check-ins',
          'Show your venue check-ins',
          Icons.place_outlined,
          settings.showCheckIns,
          (value) => ctrl.updateSetting('showCheckIns', value),
          'Others can see where you\'ve checked in',
        ),
        _buildPrivacyToggle(
          'Posts to Public',
          'Make your posts visible to everyone',
          Icons.public_outlined,
          settings.showPostsToPublic,
          (value) => ctrl.updateSetting('showPostsToPublic', value),
          'When off, posts are only visible to friends',
        ),
        _buildPrivacyToggle(
          'Sports Profiles',
          'Show your sports and skill levels',
          Icons.sports_outlined,
          settings.showSportsProfiles,
          (value) => ctrl.updateSetting('showSportsProfiles', value),
          'Essential for finding suitable games',
        ),
        _buildPrivacyToggle(
          'Game History',
          'Show your past games',
          Icons.history_outlined,
          settings.showGameHistory,
          (value) => ctrl.updateSetting('showGameHistory', value),
          'Demonstrates your experience level',
        ),
        _buildPrivacyToggle(
          'Statistics',
          'Show your performance stats',
          Icons.bar_chart_outlined,
          settings.showStats,
          (value) => ctrl.updateSetting('showStats', value),
          'Your game statistics and win/loss record',
        ),
        _buildPrivacyToggle(
          'Achievements',
          'Show your earned achievements',
          Icons.emoji_events_outlined,
          settings.showAchievements,
          (value) => ctrl.updateSetting('showAchievements', value),
          'Badges and trophies you\'ve earned',
        ),
      ],
    );
  }

  Widget _buildDiscoverabilitySection(BuildContext context) {
    final settings = ref.watch(privacyControllerProvider).settings;
    final ctrl = ref.read(privacyControllerProvider.notifier);
    if (settings == null) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Discoverability',
      'Control how others can find your profile',
      [
        _buildPrivacyToggle(
          'Search Engine Indexing',
          'Allow external services to find your profile',
          Icons.search_outlined,
          settings.allowProfileIndexing,
          (value) => ctrl.updateSetting('allowProfileIndexing', value),
          'Your profile may appear in search engine results',
        ),
        _buildPrivacyToggle(
          'Hide from Nearby',
          'Don\'t appear in nearby player searches',
          Icons.location_off_outlined,
          settings.hideFromNearby,
          (value) => ctrl.updateSetting('hideFromNearby', value),
          'You won\'t show up when people search for nearby players',
        ),
      ],
    );
  }

  Widget _buildDataSharingSection(BuildContext context) {
    final settings = ref.watch(privacyControllerProvider).settings;
    final ctrl = ref.read(privacyControllerProvider.notifier);
    if (settings == null) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Data & Analytics',
      'Control how your data is used to improve your experience',
      [
        _buildPrivacyToggle(
          'Location Tracking',
          'Allow location-based features',
          Icons.my_location_outlined,
          settings.allowLocationTracking,
          (value) => ctrl.updateSetting('allowLocationTracking', value),
          'Used for finding nearby games and venues',
        ),
        _buildPrivacyToggle(
          'Game Recommendations',
          'Personalized game suggestions',
          Icons.recommend_outlined,
          settings.allowGameRecommendations,
          (value) => ctrl.updateSetting('allowGameRecommendations', value),
          'Uses your preferences and skill level to suggest games',
        ),
        _buildPrivacyToggle(
          'Anonymous Analytics',
          'Help improve the app',
          Icons.analytics_outlined,
          settings.allowDataAnalytics,
          (value) => ctrl.updateSetting('allowDataAnalytics', value),
          'Anonymous usage data for app improvements',
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    final settings = ref.watch(privacyControllerProvider).settings;
    final ctrl = ref.read(privacyControllerProvider.notifier);
    if (settings == null) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Notifications',
      'Control how you receive notifications',
      [
        _buildPrivacyToggle(
          'Push Notifications',
          'Receive push notifications on your device',
          Icons.notifications_outlined,
          settings.allowPushNotifications,
          (value) => ctrl.updateSetting('allowPushNotifications', value),
          'Game reminders, messages, and activity alerts',
        ),
        _buildPrivacyToggle(
          'Email Notifications',
          'Receive notifications via email',
          Icons.mark_email_unread_outlined,
          settings.allowEmailNotifications,
          (value) => ctrl.updateSetting('allowEmailNotifications', value),
          'Weekly digests, game invites, and important updates',
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    final settings = ref.watch(privacyControllerProvider).settings;
    final ctrl = ref.read(privacyControllerProvider.notifier);
    if (settings == null) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Security',
      'Protect your account with additional security measures',
      [
        _buildPrivacyToggle(
          'Two-Factor Authentication',
          'Add an extra layer of security',
          Icons.security_outlined,
          settings.twoFactorEnabled,
          (value) => ctrl.updateSetting('twoFactorEnabled', value),
          'Requires a verification code when signing in',
        ),
        _buildPrivacyToggle(
          'Login Alerts',
          'Get notified of new sign-ins',
          Icons.login_outlined,
          settings.loginAlerts,
          (value) => ctrl.updateSetting('loginAlerts', value),
          'Receive alerts when your account is accessed from a new device',
        ),
      ],
    );
  }

  Widget _buildBlockedUsersSection(BuildContext context) {
    final blockedUsersAsync = ref.watch(blockedUsersWithProfilesProvider);

    return blockedUsersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildSection(
        context,
        'Blocked Users',
        'Failed to load blocked users',
        [Text('Error: $e')],
      ),
      data: (blockedUsers) => _buildSection(
        context,
        'Blocked Users',
        'Manage users you\'ve blocked from contacting you',
        [
          if (blockedUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You haven\'t blocked any users',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            )
          else
            ...blockedUsers.map((user) {
              final displayName = user['display_name'] as String? ?? 'Unknown';
              final username = user['username'] as String? ?? '';
              final userId = user['user_id'] as String;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.block,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (username.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@$username',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _unblockUser(userId, displayName),
                      child: const Text('Unblock'),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String description,
    List<Widget> children,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    String tooltip,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showTooltip(context, title, tooltip),
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Map<String, dynamic> _getPresetData(PrivacyPreset preset) {
    switch (preset) {
      case PrivacyPreset.public:
        return {
          'title': 'Public',
          'description':
              'Your profile is visible to everyone for easy discovery',
          'icon': Icons.public,
          'color': Colors.green,
        };
      case PrivacyPreset.friendsOnly:
        return {
          'title': 'Friends Only',
          'description': 'Only your friends can see your full profile',
          'icon': Icons.group,
          'color': Colors.blue,
        };
      case PrivacyPreset.private:
        return {
          'title': 'Private',
          'description': 'Minimal information is shared publicly',
          'icon': Icons.lock,
          'color': Colors.orange,
        };
    }
  }

  void _applyPreset(PrivacyPreset preset) {
    final ctrl = ref.read(privacyControllerProvider.notifier);
    PrivacySettings presetSettings;

    switch (preset) {
      case PrivacyPreset.public:
        presetSettings = const PrivacySettings(
          // Profile & Identity
          profileVisibility: ProfileVisibility.public,
          showRealName: true,
          showAge: false,
          showLocation: true,
          showPhone: false,
          showEmail: false,
          showBio: true,
          showProfilePhoto: true,
          showFriendsList: true,
          allowProfileIndexing: true,
          // Activity & Stats
          showStats: true,
          showSportsProfiles: true,
          showGameHistory: true,
          showAchievements: true,
          showOnlineStatus: true,
          showActivityStatus: true,
          showCheckIns: true,
          showPostsToPublic: true,
          // Communication
          messagePreference: CommunicationPreference.anyone,
          gameInvitePreference: CommunicationPreference.anyone,
          friendRequestPreference: CommunicationPreference.anyone,
          // Notifications
          allowPushNotifications: true,
          allowEmailNotifications: true,
          // Data & Analytics
          allowLocationTracking: true,
          allowDataAnalytics: true,
          dataSharingLevel: DataSharingLevel.full,
          allowGameRecommendations: true,
          hideFromNearby: false,
          // Security
          twoFactorEnabled: false,
          loginAlerts: true,
        );
        break;
      case PrivacyPreset.friendsOnly:
        presetSettings = const PrivacySettings(
          // Profile & Identity
          profileVisibility: ProfileVisibility.friends,
          showRealName: true,
          showAge: false,
          showLocation: true,
          showPhone: false,
          showEmail: false,
          showBio: true,
          showProfilePhoto: true,
          showFriendsList: false,
          allowProfileIndexing: false,
          // Activity & Stats
          showStats: false,
          showSportsProfiles: true,
          showGameHistory: false,
          showAchievements: true,
          showOnlineStatus: true,
          showActivityStatus: true,
          showCheckIns: false,
          showPostsToPublic: false,
          // Communication
          messagePreference: CommunicationPreference.friendsOnly,
          gameInvitePreference: CommunicationPreference.friendsOnly,
          friendRequestPreference: CommunicationPreference.anyone,
          // Notifications
          allowPushNotifications: true,
          allowEmailNotifications: true,
          // Data & Analytics
          allowLocationTracking: true,
          allowDataAnalytics: true,
          dataSharingLevel: DataSharingLevel.limited,
          allowGameRecommendations: true,
          hideFromNearby: false,
          // Security
          twoFactorEnabled: false,
          loginAlerts: true,
        );
        break;
      case PrivacyPreset.private:
        presetSettings = const PrivacySettings(
          // Profile & Identity
          profileVisibility: ProfileVisibility.private,
          showRealName: false,
          showAge: false,
          showLocation: false,
          showPhone: false,
          showEmail: false,
          showBio: false,
          showProfilePhoto: false,
          showFriendsList: false,
          allowProfileIndexing: false,
          // Activity & Stats
          showStats: false,
          showSportsProfiles: true,
          showGameHistory: false,
          showAchievements: false,
          showOnlineStatus: false,
          showActivityStatus: false,
          showCheckIns: false,
          showPostsToPublic: false,
          // Communication
          messagePreference: CommunicationPreference.friendsOnly,
          gameInvitePreference: CommunicationPreference.friendsOnly,
          friendRequestPreference: CommunicationPreference.friendsOnly,
          // Notifications
          allowPushNotifications: true,
          allowEmailNotifications: false,
          // Data & Analytics
          allowLocationTracking: false,
          allowDataAnalytics: false,
          dataSharingLevel: DataSharingLevel.minimal,
          allowGameRecommendations: false,
          hideFromNearby: true,
          // Security
          twoFactorEnabled: false,
          loginAlerts: true,
        );
        break;
    }

    ctrl.applyPreset(presetSettings);
  }

  PrivacyPreset _detectPreset(PrivacySettings s) {
    if (s.profileVisibility == ProfileVisibility.private) {
      return PrivacyPreset.private;
    }
    if (s.profileVisibility == ProfileVisibility.friends) {
      return PrivacyPreset.friendsOnly;
    }
    return PrivacyPreset.public;
  }

  void _showTooltip(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser(String userId, String displayName) async {
    final repo = ref.read(blockRepositoryProvider);
    final result = await repo.unblockUser(userId);

    result.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: ${err.message}')),
        );
      },
      (_) {
        ref.invalidate(blockedUserIdsProvider);
        ref.invalidate(blockedUsersWithProfilesProvider);
        ref.invalidate(isUserBlockedProvider(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName has been unblocked')),
        );
      },
    );
  }

  Future<void> _saveSettings() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final success = await ref
        .read(privacyControllerProvider.notifier)
        .saveAllChanges(userId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              success
                  ? 'Privacy settings saved!'
                  : 'Failed to save settings. Please try again.',
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
