import 'package:dabbler/data/models/profile/privacy_settings.dart';

/// The three privacy presets of `Settings.dc.html` (`PRESETS`).
enum PrivacyPreset {
  public,
  friendsOnly,
  private,

  /// A mix no preset describes — shown once a switch is changed by hand;
  /// never applied.
  custom,
}

/// The settings a [preset] applies as one change.
PrivacySettings privacyPresetSettings(PrivacyPreset preset) {
  switch (preset) {
    case PrivacyPreset.custom:
      throw ArgumentError.value(preset, 'preset', 'custom has no settings');
    case PrivacyPreset.public:
      return const PrivacySettings(
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
      return const PrivacySettings(
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
      return const PrivacySettings(
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
}

/// The preset that best describes [s] — the one the screen opens on.
PrivacyPreset detectPrivacyPreset(PrivacySettings s) {
  if (s.profileVisibility == ProfileVisibility.private) {
    return PrivacyPreset.private;
  }
  if (s.profileVisibility == ProfileVisibility.friends) {
    return PrivacyPreset.friendsOnly;
  }
  return PrivacyPreset.public;
}
