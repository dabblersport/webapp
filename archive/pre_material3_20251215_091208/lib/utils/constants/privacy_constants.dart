/// Privacy system constants for data protection, GDPR compliance, and user safety
library;

/// Privacy levels and visibility settings
class PrivacyLevels {
  static const String publicPrivacy = 'public';
  static const String friendsPrivacy = 'friends';
  static const String privatePrivacy = 'private';
  static const String customPrivacy = 'custom';

  static const List<String> allPrivacyLevels = [
    publicPrivacy,
    friendsPrivacy,
    privatePrivacy,
    customPrivacy,
  ];

  static const Map<String, String> privacyLevelTitles = {
    publicPrivacy: 'Public',
    friendsPrivacy: 'Friends Only',
    privatePrivacy: 'Private',
    customPrivacy: 'Custom',
  };

  static const Map<String, String> privacyLevelDescriptions = {
    publicPrivacy: 'Visible to everyone on Dabbler',
    friendsPrivacy: 'Visible to your friends only',
    privatePrivacy: 'Only visible to you',
    customPrivacy: 'Custom privacy settings',
  };

  // Profile section privacy options
  static const Map<String, String> profileSectionPrivacy = {
    'basic_info': 'Basic Information',
    'contact_info': 'Contact Information',
    'sports_profile': 'Sports & Activities',
    'game_history': 'Game History',
    'statistics': 'Performance Statistics',
    'location': 'Location Information',
    'online_status': 'Online Status',
    'last_active': 'Last Active Time',
  };
}

/// Data retention periods for compliance
class DataRetention {
  // User activity and logs
  static const Duration activityLogRetention = Duration(days: 90);
  static const Duration searchHistoryRetention = Duration(days: 30);
  static const Duration locationHistoryRetention = Duration(days: 7);
  static const Duration chatHistoryRetention = Duration(days: 365);
  static const Duration notificationHistoryRetention = Duration(days: 30);

  // Account lifecycle
  static const Duration deletedAccountRetention = Duration(days: 30);
  static const Duration inactiveAccountWarning = Duration(days: 365);
  static const Duration inactiveAccountDeletion = Duration(
    days: 1095,
  ); // 3 years
  static const Duration suspendedAccountRetention = Duration(days: 180);

  // Temporary data
  static const Duration sessionDataRetention = Duration(hours: 24);
  static const Duration tempFileRetention = Duration(hours: 2);
  static const Duration cacheRetention = Duration(days: 7);
  static const Duration analyticsDataRetention = Duration(days: 730); // 2 years

  // Legal and compliance
  static const Duration auditLogRetention = Duration(days: 2555); // 7 years
  static const Duration paymentDataRetention = Duration(days: 2555); // 7 years
  static const Duration disputeDataRetention = Duration(days: 1095); // 3 years

  // Backup retention
  static const Duration dailyBackupRetention = Duration(days: 30);
  static const Duration weeklyBackupRetention = Duration(days: 90);
  static const Duration monthlyBackupRetention = Duration(days: 365);
}

/// Default privacy settings for new users
class DefaultPrivacySettings {
  static const Map<String, bool> defaultSettings = {
    // Profile visibility
    'profile_public': true,
    'show_real_name': false,
    'show_email': false,
    'show_phone': false,
    'show_location': false,
    'show_age': true,
    'show_gender': false,

    // Activity visibility
    'show_online_status': true,
    'show_last_active': false,
    'show_game_history': true,
    'show_statistics': true,
    'show_achievements': true,
    'show_friends_list': false,

    // Communication settings
    'allow_messages_from_strangers': false,
    'allow_friend_requests': true,
    'allow_game_invites': true,
    'allow_group_invites': true,

    // Data processing
    'analytics_enabled': true,
    'personalization_enabled': true,
    'marketing_emails': false,
    'data_sharing_partners': false,
    'crash_reporting': true,

    // Location and tracking
    'location_services': false,
    'precise_location': false,
    'location_history': false,
    'nearby_users': false,

    // Search and discovery
    'appear_in_search': true,
    'search_by_email': false,
    'search_by_phone': false,
    'show_in_suggestions': true,
  };

  static const String defaultProfileVisibility = PrivacyLevels.friendsPrivacy;
  static const bool defaultAllowMessagesFromStrangers = false;
  static const bool defaultShowOnlineStatus = true;
  static const bool defaultLocationServicesEnabled = false;
  static const bool defaultAnalyticsEnabled = true;
}

/// GDPR and data protection compliance
class GDPRCompliance {
  // Exportable data types for user data requests
  static const List<String> exportableDataTypes = [
    'profile',
    'games',
    'messages',
    'settings',
    'friends',
    'statistics',
    'achievements',
    'location_history',
    'search_history',
    'notifications',
    'support_tickets',
    'payment_history',
  ];

  // Data processing lawful bases
  static const Map<String, String> lawfulBases = {
    'consent': 'User consent',
    'contract': 'Performance of contract',
    'legal_obligation': 'Legal obligation',
    'vital_interests': 'Vital interests',
    'public_task': 'Public task',
    'legitimate_interests': 'Legitimate interests',
  };

  // Data categories for processing records
  static const Map<String, String> dataCategories = {
    'identity': 'Identity data (name, username, date of birth)',
    'contact': 'Contact data (email, phone, address)',
    'profile': 'Profile data (bio, preferences, interests)',
    'usage': 'Usage data (app interactions, features used)',
    'technical': 'Technical data (IP address, device info)',
    'marketing': 'Marketing data (preferences, communications)',
    'financial': 'Financial data (payment info, transactions)',
    'special': 'Special category data (health, biometric)',
  };

  // User rights under GDPR
  static const List<String> userRights = [
    'right_to_information',
    'right_of_access',
    'right_to_rectification',
    'right_to_erasure',
    'right_to_restrict_processing',
    'right_to_data_portability',
    'right_to_object',
    'rights_related_to_automated_decision_making',
  ];

  // Data export formats
  static const List<String> exportFormats = ['json', 'csv', 'pdf', 'xml'];
  static const String defaultExportFormat = 'json';
  static const int maxExportSizeMB = 500;
  static const Duration exportRequestValidity = Duration(days: 30);
}

/// Account deletion and data erasure
class AccountDeletion {
  // Grace periods
  static const Duration standardGracePeriod = Duration(days: 30);
  static const Duration premiumGracePeriod = Duration(days: 45);
  static const Duration adminGracePeriod = Duration(days: 7);

  // Data categories for deletion
  static const Map<String, bool> deletionCategories = {
    'profile_data': true,
    'game_history': true,
    'messages': true,
    'images': true,
    'settings': true,
    'analytics': false, // Anonymized and retained
    'legal_records': false, // Retained for legal compliance
    'payment_history': false, // Retained for financial compliance
  };

  // Pre-deletion checklist items
  static const List<String> preDeletionChecklist = [
    'outstanding_games',
    'unread_messages',
    'active_subscriptions',
    'pending_payments',
    'group_admin_roles',
    'data_export_recommended',
  ];

  static const Map<String, String> checklistDescriptions = {
    'outstanding_games': 'Games you have committed to play',
    'unread_messages': 'Unread messages in your inbox',
    'active_subscriptions': 'Active premium subscriptions',
    'pending_payments': 'Pending or incomplete payments',
    'group_admin_roles': 'Groups where you are an admin',
    'data_export_recommended': 'Consider exporting your data first',
  };

  // Deletion reasons (for analytics and improvement)
  static const List<String> deletionReasons = [
    'not_using_app',
    'privacy_concerns',
    'found_alternative',
    'too_many_notifications',
    'bad_user_experience',
    'safety_concerns',
    'technical_issues',
    'cost_concerns',
    'other',
  ];
}

/// Rate limiting for privacy-related actions
class PrivacyRateLimits {
  static const int maxProfileViewsPerHour = 100;
  static const int maxSettingChangesPerDay = 50;
  static const int maxDataExportRequestsPerMonth = 5;
  static const int maxPasswordChangesPerDay = 3;
  static const int maxEmailChangesPerWeek = 2;
  static const int maxPrivacySettingChangesPerHour = 20;

  // Search and discovery limits
  static const int maxSearchQueriesPerMinute = 30;
  static const int maxProfileSearchesPerHour = 200;
  static const int maxLocationUpdatesPerHour = 60;

  // Communication limits
  static const int maxMessagesToStrangersPerDay = 10;
  static const int maxFriendRequestsPerDay = 50;
  static const int maxGroupInvitesPerDay = 20;

  // Reporting and safety limits
  static const int maxReportsPerDay = 10;
  static const int maxBlocksPerDay = 50;
}

/// Content moderation and safety
class SafetyConstants {
  // Content flags
  static const List<String> contentFlags = [
    'inappropriate_language',
    'harassment',
    'spam',
    'fake_profile',
    'inappropriate_image',
    'scam',
    'discrimination',
    'violence',
    'adult_content',
    'copyright_violation',
  ];

  // Report categories
  static const Map<String, String> reportCategories = {
    'harassment': 'Harassment or bullying',
    'spam': 'Spam or unwanted content',
    'fake_profile': 'Fake or impersonation account',
    'inappropriate_content': 'Inappropriate content',
    'safety_concern': 'Safety concern',
    'scam': 'Scam or fraud',
    'discrimination': 'Discrimination or hate speech',
    'violence': 'Violence or threats',
    'other': 'Other reason',
  };

  // Automated safety measures
  static const int maxReportsForAutoReview = 3;
  static const int maxReportsForAutoSuspension = 10;
  static const Duration autoSuspensionDuration = Duration(days: 7);

  // Trust and safety scoring
  static const double minTrustScore = 0.0;
  static const double maxTrustScore = 100.0;
  static const double defaultTrustScore = 80.0;
  static const double suspensionTrustThreshold = 20.0;
  static const double banTrustThreshold = 10.0;
}

/// Data processing consent types
class ConsentTypes {
  static const String essential =
      'essential'; // Required for basic functionality
  static const String functional = 'functional'; // Enhances user experience
  static const String analytics = 'analytics'; // Usage analytics
  static const String marketing = 'marketing'; // Marketing communications
  static const String personalization =
      'personalization'; // Content personalization
  static const String sharing = 'sharing'; // Data sharing with partners

  static const List<String> allConsentTypes = [
    essential,
    functional,
    analytics,
    marketing,
    personalization,
    sharing,
  ];

  static const Map<String, String> consentDescriptions = {
    essential: 'Required for the app to function properly',
    functional: 'Helps us provide better features and user experience',
    analytics: 'Helps us understand how the app is used to improve it',
    marketing: 'Allows us to send you promotional content and offers',
    personalization: 'Enables personalized content and recommendations',
    sharing: 'Allows sharing anonymized data with trusted partners',
  };

  static const Map<String, bool> consentDefaults = {
    essential: true, // Cannot be disabled
    functional: true,
    analytics: true,
    marketing: false,
    personalization: true,
    sharing: false,
  };

  static const Map<String, bool> consentRequired = {
    essential: true,
    functional: false,
    analytics: false,
    marketing: false,
    personalization: false,
    sharing: false,
  };
}

/// Privacy error messages and notifications
class PrivacyMessages {
  // Error messages
  static const String privacySettingUpdateFailed =
      'Failed to update privacy setting';
  static const String invalidPrivacyLevel = 'Invalid privacy level selected';
  static const String dataExportFailed = 'Failed to generate data export';
  static const String accountDeletionFailed =
      'Failed to process account deletion';
  static const String rateLimitExceeded =
      'Too many requests. Please wait before trying again';
  static const String insufficientPermissions =
      'Insufficient permissions for this action';

  // Success messages
  static const String privacySettingsUpdated =
      'Privacy settings updated successfully';
  static const String dataExportRequested =
      'Data export request submitted. You will receive an email when ready';
  static const String accountDeletionRequested =
      'Account deletion requested. You have 30 days to cancel';
  static const String consentUpdated = 'Consent preferences updated';

  // Warning messages
  static const String publicProfileWarning =
      'Making your profile public will allow anyone to see your information';
  static const String locationSharingWarning =
      'Location sharing will show your approximate location to other users';
  static const String dataExportSizeWarning =
      'Your data export may be large and take time to prepare';
  static const String accountDeletionWarning =
      'Account deletion is permanent and cannot be undone after the grace period';

  // Information messages
  static const String gdprRightsInfo =
      'You have rights under GDPR including access, rectification, and erasure of your data';
  static const String dataRetentionInfo =
      'We retain different types of data for varying periods as outlined in our privacy policy';
  static const String consentWithdrawalInfo =
      'You can withdraw consent at any time, though this may limit app functionality';
}

/// Cookie and tracking preferences
class TrackingConstants {
  // Cookie categories
  static const String essentialCookies = 'essential';
  static const String functionalCookies = 'functional';
  static const String analyticsCookies = 'analytics';
  static const String marketingCookies = 'marketing';

  static const List<String> cookieCategories = [
    essentialCookies,
    functionalCookies,
    analyticsCookies,
    marketingCookies,
  ];

  // Tracking purposes
  static const Map<String, String> trackingPurposes = {
    'performance': 'Website and app performance monitoring',
    'functionality': 'Remember user preferences and settings',
    'analytics': 'Understand user behavior and improve services',
    'marketing': 'Show relevant advertisements and content',
    'security': 'Detect fraud and ensure security',
    'personalization': 'Provide personalized content and recommendations',
  };

  // Cookie lifespans
  static const Duration sessionCookieLifespan = Duration(hours: 24);
  static const Duration functionalCookieLifespan = Duration(days: 365);
  static const Duration analyticsCookieLifespan = Duration(days: 730);
  static const Duration marketingCookieLifespan = Duration(days: 90);
}
