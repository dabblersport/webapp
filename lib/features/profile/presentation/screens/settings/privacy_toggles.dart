import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// One privacy switch of `Settings.dc.html` (`PROFILE_ROWS`, `ACTIVITY_ROWS`,
/// `DISCOVERY_ROWS`, `DATA_ROWS`, `NOTIFY_ROWS`): the controller key it writes,
/// its glyph, how to read it and its two lines of copy.
class PrivacyToggle {
  const PrivacyToggle(
    this.key,
    this.icon,
    this.read,
    this.title,
    this.subtitle,
  );

  final String key;
  final String icon;
  final bool Function(PrivacySettings) read;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) subtitle;
}

/// How many of [toggles] are on in [s].
int privacyOnCount(List<PrivacyToggle> toggles, PrivacySettings s) =>
    toggles.where((t) => t.read(s)).length;

final List<PrivacyToggle> privacyProfileToggles = [
  PrivacyToggle(
    'showProfilePhoto',
    'user',
    (s) => s.showProfilePhoto,
    (l) => l.priv_t_photo,
    (l) => l.priv_t_photo_sub,
  ),
  PrivacyToggle(
    'showRealName',
    'profile-circle',
    (s) => s.showRealName,
    (l) => l.priv_t_name,
    (l) => l.priv_t_name_sub,
  ),
  PrivacyToggle(
    'showBio',
    'document-text',
    (s) => s.showBio,
    (l) => l.priv_t_bio,
    (l) => l.priv_t_bio_sub,
  ),
  PrivacyToggle(
    'showAge',
    'cake',
    (s) => s.showAge,
    (l) => l.priv_t_age,
    (l) => l.priv_t_age_sub,
  ),
  PrivacyToggle(
    'showEmail',
    'sms',
    (s) => s.showEmail,
    (l) => l.priv_t_email,
    (l) => l.priv_t_email_sub,
  ),
  PrivacyToggle(
    'showPhone',
    'call',
    (s) => s.showPhone,
    (l) => l.priv_t_phone,
    (l) => l.priv_t_phone_sub,
  ),
  PrivacyToggle(
    'showLocation',
    'buildings-2',
    (s) => s.showLocation,
    (l) => l.priv_t_location,
    (l) => l.priv_t_location_sub,
  ),
  PrivacyToggle(
    'showFriendsList',
    'people',
    (s) => s.showFriendsList,
    (l) => l.priv_t_friends,
    (l) => l.priv_t_friends_sub,
  ),
];

final List<PrivacyToggle> privacyActivityToggles = [
  PrivacyToggle(
    'showOnlineStatus',
    'status-up',
    (s) => s.showOnlineStatus,
    (l) => l.priv_t_online,
    (l) => l.priv_t_online_sub,
  ),
  PrivacyToggle(
    'showActivityStatus',
    'ticket-star',
    (s) => s.showActivityStatus,
    (l) => l.priv_t_activity,
    (l) => l.priv_t_activity_sub,
  ),
  PrivacyToggle(
    'showCheckIns',
    'location',
    (s) => s.showCheckIns,
    (l) => l.priv_t_checkins,
    (l) => l.priv_t_checkins_sub,
  ),
  PrivacyToggle(
    'showPostsToPublic',
    'global',
    (s) => s.showPostsToPublic,
    (l) => l.priv_t_posts,
    (l) => l.priv_t_posts_sub,
  ),
  PrivacyToggle(
    'showSportsProfiles',
    'medal-star',
    (s) => s.showSportsProfiles,
    (l) => l.priv_t_sports,
    (l) => l.priv_t_sports_sub,
  ),
  PrivacyToggle(
    'showGameHistory',
    'clock',
    (s) => s.showGameHistory,
    (l) => l.priv_t_history,
    (l) => l.priv_t_history_sub,
  ),
  PrivacyToggle(
    'showStats',
    'chart-2',
    (s) => s.showStats,
    (l) => l.priv_t_stats,
    (l) => l.priv_t_stats_sub,
  ),
  PrivacyToggle(
    'showAchievements',
    'cup',
    (s) => s.showAchievements,
    (l) => l.priv_t_achievements,
    (l) => l.priv_t_achievements_sub,
  ),
];

final List<PrivacyToggle> privacyDiscoveryToggles = [
  PrivacyToggle(
    'allowProfileIndexing',
    'search-normal',
    (s) => s.allowProfileIndexing,
    (l) => l.priv_t_indexing,
    (l) => l.priv_t_indexing_sub,
  ),
  PrivacyToggle(
    'hideFromNearby',
    'gps-slash',
    (s) => s.hideFromNearby,
    (l) => l.priv_t_nearby,
    (l) => l.priv_t_nearby_sub,
  ),
];

final List<PrivacyToggle> privacyDataToggles = [
  PrivacyToggle(
    'allowLocationTracking',
    'gps',
    (s) => s.allowLocationTracking,
    (l) => l.priv_t_tracking,
    (l) => l.priv_t_tracking_sub,
  ),
  PrivacyToggle(
    'allowGameRecommendations',
    'like-1',
    (s) => s.allowGameRecommendations,
    (l) => l.priv_t_recs,
    (l) => l.priv_t_recs_sub,
  ),
  PrivacyToggle(
    'allowDataAnalytics',
    'chart',
    (s) => s.allowDataAnalytics,
    (l) => l.priv_t_analytics,
    (l) => l.priv_t_analytics_sub,
  ),
];

final List<PrivacyToggle> privacyNotificationToggles = [
  PrivacyToggle(
    'allowPushNotifications',
    'notification',
    (s) => s.allowPushNotifications,
    (l) => l.priv_t_push,
    (l) => l.priv_t_push_sub,
  ),
  PrivacyToggle(
    'allowEmailNotifications',
    'sms-notification',
    (s) => s.allowEmailNotifications,
    (l) => l.priv_t_mail,
    (l) => l.priv_t_mail_sub,
  ),
];
