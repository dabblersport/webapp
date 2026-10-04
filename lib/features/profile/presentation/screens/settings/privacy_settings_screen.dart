import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/profile/presentation/widgets/blocked_accounts_group.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/data/models/profile/privacy_settings.dart';

enum PrivacyPreset { public, friendsOnly, private }

/// One switch row: label, DS icon name, controller key, explainer, reader.
typedef _Toggle = (
  String title,
  String subtitle,
  String icon,
  String key,
  String tooltip,
  bool Function(PrivacySettings) read,
);

/// One preference row: label, DS icon name, controller key, reader.
typedef _Pref = (
  String title,
  String subtitle,
  String icon,
  String key,
  CommunicationPreference Function(PrivacySettings) read,
);

const List<_Toggle> _profileToggles = [
  (
    'Profile Photo',
    'Show your profile picture',
    'profile-circle',
    'showProfilePhoto',
    'Your profile photo helps others recognize you',
    _showProfilePhoto,
  ),
  (
    'Real Name',
    'Show your full name',
    'user',
    'showRealName',
    'Others will see your real name instead of username',
    _showRealName,
  ),
  (
    'Bio',
    'Show your bio on your profile',
    'document-text',
    'showBio',
    'Your bio text will be visible on your profile',
    _showBio,
  ),
  (
    'Age',
    'Show your age on your profile',
    'cake',
    'showAge',
    'Your age will be calculated from your date of birth',
    _showAge,
  ),
  (
    'Email Address',
    'Show your email to others',
    'sms',
    'showEmail',
    'Not recommended for privacy reasons',
    _showEmail,
  ),
  (
    'Phone Number',
    'Show your phone number',
    'call',
    'showPhone',
    'Only visible to teammates for coordination',
    _showPhone,
  ),
  (
    'Location',
    'Show your general location',
    'location',
    'showLocation',
    'Helps with local game matching',
    _showLocation,
  ),
  (
    'Friends List',
    'Show your friends publicly',
    'people',
    'showFriendsList',
    'Others can see who you\'re connected with',
    _showFriendsList,
  ),
];

const List<_Pref> _communicationPrefs = [
  (
    'Direct Messages',
    'Who can send you messages',
    'message',
    'messagePreference',
    _messagePref,
  ),
  (
    'Game Invites',
    'Who can invite you to games',
    'game',
    'gameInvitePreference',
    _gameInvitePref,
  ),
  (
    'Friend Requests',
    'Who can send you friend requests',
    'user-add',
    'friendRequestPreference',
    _friendRequestPref,
  ),
];

const List<_Toggle> _activityToggles = [
  (
    'Online Status',
    'Show when you\'re online',
    'status',
    'showOnlineStatus',
    'Let others know when you\'re available',
    _showOnlineStatus,
  ),
  (
    'Activity Status',
    'Show your recent activity',
    'activity',
    'showActivityStatus',
    'Others can see what you\'ve been up to',
    _showActivityStatus,
  ),
  (
    'Check-ins',
    'Show your venue check-ins',
    'location-tick',
    'showCheckIns',
    'Others can see where you\'ve checked in',
    _showCheckIns,
  ),
  (
    'Posts to Public',
    'Make your posts visible to everyone',
    'global',
    'showPostsToPublic',
    'When off, posts are only visible to friends',
    _showPostsToPublic,
  ),
  (
    'Sports Profiles',
    'Show your sports and skill levels',
    'medal',
    'showSportsProfiles',
    'Essential for finding suitable games',
    _showSportsProfiles,
  ),
  (
    'Game History',
    'Show your past games',
    'clock',
    'showGameHistory',
    'Demonstrates your experience level',
    _showGameHistory,
  ),
  (
    'Statistics',
    'Show your performance stats',
    'chart',
    'showStats',
    'Your game statistics and win/loss record',
    _showStats,
  ),
  (
    'Achievements',
    'Show your earned achievements',
    'cup',
    'showAchievements',
    'Badges and trophies you\'ve earned',
    _showAchievements,
  ),
];

const List<_Toggle> _discoverToggles = [
  (
    'Search Engine Indexing',
    'Allow external services to find your profile',
    'search-normal',
    'allowProfileIndexing',
    'Your profile may appear in search engine results',
    _allowProfileIndexing,
  ),
  (
    'Hide from Nearby',
    'Don\'t appear in nearby player searches',
    'location-slash',
    'hideFromNearby',
    'You won\'t show up when people search for nearby players',
    _hideFromNearby,
  ),
];

const List<_Toggle> _dataToggles = [
  (
    'Location Tracking',
    'Allow location-based features',
    'gps',
    'allowLocationTracking',
    'Used for finding nearby games and venues',
    _allowLocationTracking,
  ),
  (
    'Game Recommendations',
    'Personalized game suggestions',
    'star',
    'allowGameRecommendations',
    'Uses your preferences and skill level to suggest games',
    _allowGameRecommendations,
  ),
  (
    'Anonymous Analytics',
    'Help improve the app',
    'chart-2',
    'allowDataAnalytics',
    'Anonymous usage data for app improvements',
    _allowDataAnalytics,
  ),
];

const List<_Toggle> _notificationToggles = [
  (
    'Push Notifications',
    'Receive push notifications on your device',
    'notification',
    'allowPushNotifications',
    'Game reminders, messages, and activity alerts',
    _allowPush,
  ),
  (
    'Email Notifications',
    'Receive notifications via email',
    'sms-notification',
    'allowEmailNotifications',
    'Weekly digests, game invites, and important updates',
    _allowEmail,
  ),
];

const List<_Toggle> _securityToggles = [
  (
    'Two-Factor Authentication',
    'Add an extra layer of security',
    'security-user',
    'twoFactorEnabled',
    'Requires a verification code when signing in',
    _twoFactor,
  ),
  (
    'Login Alerts',
    'Get notified of new sign-ins',
    'key',
    'loginAlerts',
    'Receive alerts when your account is accessed from a new device',
    _loginAlerts,
  ),
];

bool _showProfilePhoto(PrivacySettings s) => s.showProfilePhoto;
bool _showRealName(PrivacySettings s) => s.showRealName;
bool _showBio(PrivacySettings s) => s.showBio;
bool _showAge(PrivacySettings s) => s.showAge;
bool _showEmail(PrivacySettings s) => s.showEmail;
bool _showPhone(PrivacySettings s) => s.showPhone;
bool _showLocation(PrivacySettings s) => s.showLocation;
bool _showFriendsList(PrivacySettings s) => s.showFriendsList;
bool _showOnlineStatus(PrivacySettings s) => s.showOnlineStatus;
bool _showActivityStatus(PrivacySettings s) => s.showActivityStatus;
bool _showCheckIns(PrivacySettings s) => s.showCheckIns;
bool _showPostsToPublic(PrivacySettings s) => s.showPostsToPublic;
bool _showSportsProfiles(PrivacySettings s) => s.showSportsProfiles;
bool _showGameHistory(PrivacySettings s) => s.showGameHistory;
bool _showStats(PrivacySettings s) => s.showStats;
bool _showAchievements(PrivacySettings s) => s.showAchievements;
bool _allowProfileIndexing(PrivacySettings s) => s.allowProfileIndexing;
bool _hideFromNearby(PrivacySettings s) => s.hideFromNearby;
bool _allowLocationTracking(PrivacySettings s) => s.allowLocationTracking;
bool _allowGameRecommendations(PrivacySettings s) => s.allowGameRecommendations;
bool _allowDataAnalytics(PrivacySettings s) => s.allowDataAnalytics;
bool _allowPush(PrivacySettings s) => s.allowPushNotifications;
bool _allowEmail(PrivacySettings s) => s.allowEmailNotifications;
bool _twoFactor(PrivacySettings s) => s.twoFactorEnabled;
bool _loginAlerts(PrivacySettings s) => s.loginAlerts;
CommunicationPreference _messagePref(PrivacySettings s) => s.messagePreference;
CommunicationPreference _gameInvitePref(PrivacySettings s) =>
    s.gameInvitePreference;
CommunicationPreference _friendRequestPref(PrivacySettings s) =>
    s.friendRequestPreference;

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
      duration: DabblerMotion.screenEntrance,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: DabblerMotion.standardInOut,
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: DabblerMotion.emphasizedDecelerate,
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

    final topBar = DabblerNavigationTopBar.titled(
      border: true,
      title: 'Privacy Settings',
      onBack: () => context.pop(),
      actions: [
        DabblerNavigationAction.text(label: 'Save', onPressed: _saveSettings),
      ],
    );

    if (privacyState.isLoading) {
      return DabblerPage(
        topBar: topBar,
        body: const Center(child: DabblerSpinner()),
      );
    }

    final ctrl = ref.read(privacyControllerProvider.notifier);
    return DabblerPage(
      topBar: topBar,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DabblerSpacing.space6,
              DabblerSpacing.space4,
              DabblerSpacing.space6,
              DabblerSpacing.space11,
            ),
            children: [
              _buildPresetsSection(),
              if (settings != null) ...[
                _gap,
                _toggleSection(
                  'Profile & Identity',
                  'Control what personal information others can see',
                  _profileToggles,
                  settings,
                  ctrl.updateSetting,
                ),
                _gap,
                DabblerRowGroup(
                  header: 'Communication',
                  note: 'Control who can contact you and how',
                  children: [
                    for (final p in _communicationPrefs)
                      _prefRow(p, settings, ctrl.updateSetting),
                  ],
                ),
                _gap,
                _toggleSection(
                  'Activity & Stats',
                  'Control visibility of your activity and performance data',
                  _activityToggles,
                  settings,
                  ctrl.updateSetting,
                ),
                _gap,
                _toggleSection(
                  'Discoverability',
                  'Control how others can find your profile',
                  _discoverToggles,
                  settings,
                  ctrl.updateSetting,
                ),
                _gap,
                _toggleSection(
                  'Data & Analytics',
                  'Control how your data is used to improve your experience',
                  _dataToggles,
                  settings,
                  ctrl.updateSetting,
                ),
                _gap,
                _toggleSection(
                  'Notifications',
                  'Control how you receive notifications',
                  _notificationToggles,
                  settings,
                  ctrl.updateSetting,
                ),
                _gap,
                _toggleSection(
                  'Security',
                  'Protect your account with additional security measures',
                  _securityToggles,
                  settings,
                  ctrl.updateSetting,
                ),
              ],
              _gap,
              _buildBlockedUsersSection(),
            ],
          ),
        ),
      ),
    );
  }

  static const Widget _gap = SizedBox(height: DabblerSpacing.space7);

  Widget _icon(String name) => DabblerIcon(
    name,
    size: DabblerSizing.iconMd,
    color: DabblerColors.of(context).textSecondary,
  );

  Widget _buildPresetsSection() {
    return DabblerRowGroup(
      header: 'Privacy Presets',
      note: 'Choose a preset to quickly configure your privacy settings',
      children: [
        for (final preset in PrivacyPreset.values)
          DabblerInputRow(
            flat: true,
            showDivider: false,
            title: _presetTitle(preset),
            subtitle: _presetDescription(preset),
            leading: _icon(_presetIcon(preset)),
            trailing: DabblerRadio(
              selected: _selectedPreset == preset,
              semanticLabel: _presetTitle(preset),
            ),
            onTap: () {
              setState(() {
                _selectedPreset = preset;
                _applyPreset(preset);
              });
            },
          ),
        const DabblerBanner(
          tone: DabblerBannerTone.info,
          message: 'You can always customize individual settings below',
        ),
      ],
    );
  }

  Widget _toggleSection(
    String title,
    String description,
    List<_Toggle> toggles,
    PrivacySettings settings,
    void Function(String, dynamic) update,
  ) {
    return DabblerRowGroup(
      header: title,
      note: description,
      children: [
        for (final t in toggles)
          DabblerInputRow.toggle(
            flat: true,
            showDivider: false,
            title: t.$1,
            subtitle: t.$2,
            leading: _icon(t.$3),
            checked: t.$6(settings),
            onChanged: (value) => update(t.$4, value),
            toggleSemanticLabel: t.$1,
            onInfo: () => _showTooltip(t.$1, t.$5),
            infoSemanticLabel: '${t.$1} info',
          ),
      ],
    );
  }

  Widget _prefRow(
    _Pref p,
    PrivacySettings settings,
    void Function(String, dynamic) update,
  ) {
    final value = p.$5(settings);
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      title: p.$1,
      subtitle: p.$2,
      leading: _icon(p.$3),
      value: _communicationPrefLabel(value),
      onTap: () => showDabblerSheet<void>(
        context: context,
        title: p.$1,
        detent: DabblerSheetDetent.content,
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pref in CommunicationPreference.values)
              DabblerInputRow(
                title: _communicationPrefLabel(pref),
                selected: pref == value,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  update(p.$4, pref);
                },
              ),
          ],
        ),
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

  Widget _buildBlockedUsersSection() {
    final l10n = AppLocalizations.of(context);
    return BlockedAccountsGroup(
      header: l10n.settings_tile_blocked,
      note: l10n.blocked_accounts_note,
    );
  }

  String _presetTitle(PrivacyPreset preset) => switch (preset) {
    PrivacyPreset.public => 'Public',
    PrivacyPreset.friendsOnly => 'Friends Only',
    PrivacyPreset.private => 'Private',
  };

  String _presetDescription(PrivacyPreset preset) => switch (preset) {
    PrivacyPreset.public =>
      'Your profile is visible to everyone for easy discovery',
    PrivacyPreset.friendsOnly => 'Only your friends can see your full profile',
    PrivacyPreset.private => 'Minimal information is shared publicly',
  };

  String _presetIcon(PrivacyPreset preset) => switch (preset) {
    PrivacyPreset.public => 'global',
    PrivacyPreset.friendsOnly => 'people',
    PrivacyPreset.private => 'lock',
  };

  void _applyPreset(PrivacyPreset preset) {
    final ctrl = ref.read(privacyControllerProvider.notifier);
    final PrivacySettings presetSettings;

    switch (preset) {
      case PrivacyPreset.public:
        presetSettings = const PrivacySettings(
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
          showStats: true,
          showSportsProfiles: true,
          showGameHistory: true,
          showAchievements: true,
          showOnlineStatus: true,
          showActivityStatus: true,
          showCheckIns: true,
          showPostsToPublic: true,
          messagePreference: CommunicationPreference.anyone,
          gameInvitePreference: CommunicationPreference.anyone,
          friendRequestPreference: CommunicationPreference.anyone,
          allowPushNotifications: true,
          allowEmailNotifications: true,
          allowLocationTracking: true,
          allowDataAnalytics: true,
          dataSharingLevel: DataSharingLevel.full,
          allowGameRecommendations: true,
          hideFromNearby: false,
          twoFactorEnabled: false,
          loginAlerts: true,
        );
      case PrivacyPreset.friendsOnly:
        presetSettings = const PrivacySettings(
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
          showStats: false,
          showSportsProfiles: true,
          showGameHistory: false,
          showAchievements: true,
          showOnlineStatus: true,
          showActivityStatus: true,
          showCheckIns: false,
          showPostsToPublic: false,
          messagePreference: CommunicationPreference.friendsOnly,
          gameInvitePreference: CommunicationPreference.friendsOnly,
          friendRequestPreference: CommunicationPreference.anyone,
          allowPushNotifications: true,
          allowEmailNotifications: true,
          allowLocationTracking: true,
          allowDataAnalytics: true,
          dataSharingLevel: DataSharingLevel.limited,
          allowGameRecommendations: true,
          hideFromNearby: false,
          twoFactorEnabled: false,
          loginAlerts: true,
        );
      case PrivacyPreset.private:
        presetSettings = const PrivacySettings(
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
          showStats: false,
          showSportsProfiles: true,
          showGameHistory: false,
          showAchievements: false,
          showOnlineStatus: false,
          showActivityStatus: false,
          showCheckIns: false,
          showPostsToPublic: false,
          messagePreference: CommunicationPreference.friendsOnly,
          gameInvitePreference: CommunicationPreference.friendsOnly,
          friendRequestPreference: CommunicationPreference.friendsOnly,
          allowPushNotifications: true,
          allowEmailNotifications: false,
          allowLocationTracking: false,
          allowDataAnalytics: false,
          dataSharingLevel: DataSharingLevel.minimal,
          allowGameRecommendations: false,
          hideFromNearby: true,
          twoFactorEnabled: false,
          loginAlerts: true,
        );
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

  void _showTooltip(String title, String description) {
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        title: title,
        description: description,
        onClose: () => Navigator.of(dialogContext).pop(),
        primaryAction: DabblerDialogAction(
          label: 'Got it',
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  void _toast(String message, DabblerToastTone tone) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: tone));
  }

  Future<void> _saveSettings() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final success = await ref
        .read(privacyControllerProvider.notifier)
        .saveAllChanges(userId);

    if (!mounted) return;

    _toast(
      success
          ? 'Privacy settings saved!'
          : 'Failed to save settings. Please try again.',
      success ? DabblerToastTone.success : DabblerToastTone.error,
    );
  }
}

/// How many of the profile-visibility toggles are on, as `n/total`.
String privacyProfileShownCount(PrivacySettings s) =>
    _count(_profileToggles, s);

/// How many of the activity-visibility toggles are on, as `n/total`.
String privacyActivityShownCount(PrivacySettings s) =>
    _count(_activityToggles, s);

String _count(List<_Toggle> toggles, PrivacySettings s) =>
    '${toggles.where((t) => t.$6(s)).length}/${toggles.length}';
