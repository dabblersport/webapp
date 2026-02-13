import 'package:dabbler/data/models/profile/privacy_settings.dart';

class PrivacySettingsModel extends PrivacySettings {
  const PrivacySettingsModel({
    super.profileVisibility,
    super.showRealName,
    super.showAge,
    super.showLocation,
    super.showPhone,
    super.showEmail,
    super.showBio,
    super.showProfilePhoto,
    super.showFriendsList,
    super.allowProfileIndexing,
    super.showStats,
    super.showSportsProfiles,
    super.showGameHistory,
    super.showAchievements,
    super.showOnlineStatus,
    super.showActivityStatus,
    super.showCheckIns,
    super.showPostsToPublic,
    super.messagePreference,
    super.gameInvitePreference,
    super.friendRequestPreference,
    super.allowPushNotifications,
    super.allowEmailNotifications,
    super.allowLocationTracking,
    super.allowDataAnalytics,
    super.dataSharingLevel,
    super.allowGameRecommendations,
    super.hideFromNearby,
    super.twoFactorEnabled,
    super.loginAlerts,
    super.blockedUsers,
  });

  /// Creates PrivacySettingsModel from domain entity
  factory PrivacySettingsModel.fromEntity(PrivacySettings entity) {
    return PrivacySettingsModel(
      profileVisibility: entity.profileVisibility,
      showRealName: entity.showRealName,
      showAge: entity.showAge,
      showLocation: entity.showLocation,
      showPhone: entity.showPhone,
      showEmail: entity.showEmail,
      showBio: entity.showBio,
      showProfilePhoto: entity.showProfilePhoto,
      showFriendsList: entity.showFriendsList,
      allowProfileIndexing: entity.allowProfileIndexing,
      showStats: entity.showStats,
      showSportsProfiles: entity.showSportsProfiles,
      showGameHistory: entity.showGameHistory,
      showAchievements: entity.showAchievements,
      showOnlineStatus: entity.showOnlineStatus,
      showActivityStatus: entity.showActivityStatus,
      showCheckIns: entity.showCheckIns,
      showPostsToPublic: entity.showPostsToPublic,
      messagePreference: entity.messagePreference,
      gameInvitePreference: entity.gameInvitePreference,
      friendRequestPreference: entity.friendRequestPreference,
      allowPushNotifications: entity.allowPushNotifications,
      allowEmailNotifications: entity.allowEmailNotifications,
      allowLocationTracking: entity.allowLocationTracking,
      allowDataAnalytics: entity.allowDataAnalytics,
      dataSharingLevel: entity.dataSharingLevel,
      allowGameRecommendations: entity.allowGameRecommendations,
      hideFromNearby: entity.hideFromNearby,
      twoFactorEnabled: entity.twoFactorEnabled,
      loginAlerts: entity.loginAlerts,
      blockedUsers: entity.blockedUsers,
    );
  }

  /// Creates PrivacySettingsModel from JSON (Supabase response)
  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      profileVisibility: _parseProfileVisibility(json['profile_visibility']),
      showRealName: _parseBoolWithDefault(json['show_real_name'], true),
      showAge: _parseBoolWithDefault(json['show_age'], false),
      showLocation: _parseBoolWithDefault(json['show_location'], true),
      showPhone: _parseBoolWithDefault(json['show_phone'], false),
      showEmail: _parseBoolWithDefault(json['show_email'], false),
      showBio: _parseBoolWithDefault(json['show_bio'], true),
      showProfilePhoto: _parseBoolWithDefault(json['show_profile_photo'], true),
      showFriendsList: _parseBoolWithDefault(json['show_friends_list'], false),
      allowProfileIndexing: _parseBoolWithDefault(
        json['allow_profile_indexing'],
        true,
      ),
      showStats: _parseBoolWithDefault(json['show_stats'], true),
      showSportsProfiles: _parseBoolWithDefault(
        json['show_sports_profiles'],
        true,
      ),
      showGameHistory: _parseBoolWithDefault(json['show_game_history'], true),
      showAchievements: _parseBoolWithDefault(json['show_achievements'], true),
      showOnlineStatus: _parseBoolWithDefault(json['show_online_status'], true),
      showActivityStatus: _parseBoolWithDefault(
        json['show_activity_status'],
        true,
      ),
      showCheckIns: _parseBoolWithDefault(json['show_check_ins'], true),
      showPostsToPublic: _parseBoolWithDefault(
        json['show_posts_to_public'],
        true,
      ),
      messagePreference: _parseCommunicationPreference(
        json['message_preference'],
      ),
      gameInvitePreference: _parseCommunicationPreference(
        json['game_invite_preference'],
      ),
      friendRequestPreference: _parseCommunicationPreference(
        json['friend_request_preference'],
      ),
      allowPushNotifications: _parseBoolWithDefault(
        json['allow_push_notifications'],
        true,
      ),
      allowEmailNotifications: _parseBoolWithDefault(
        json['allow_email_notifications'],
        true,
      ),
      allowLocationTracking: _parseBoolWithDefault(
        json['allow_location_tracking'],
        true,
      ),
      allowDataAnalytics: _parseBoolWithDefault(
        json['allow_data_analytics'],
        true,
      ),
      dataSharingLevel: _parseDataSharingLevel(json['data_sharing_level']),
      allowGameRecommendations: _parseBoolWithDefault(
        json['allow_game_recommendations'],
        true,
      ),
      hideFromNearby: _parseBoolWithDefault(json['hide_from_nearby'], false),
      twoFactorEnabled: _parseBoolWithDefault(
        json['two_factor_enabled'],
        false,
      ),
      loginAlerts: _parseBoolWithDefault(json['login_alerts'], true),
      blockedUsers: _parseStringList(json['blocked_users']),
    );
  }

  /// Creates PrivacySettingsModel from legacy database format
  factory PrivacySettingsModel.fromLegacyJson(Map<String, dynamic> json) {
    return PrivacySettingsModel.fromJson(json);
  }

  /// Converts PrivacySettingsModel to JSON for API requests
  @override
  Map<String, dynamic> toJson() {
    return {
      'profile_visibility': profileVisibility.index,
      'show_real_name': showRealName,
      'show_age': showAge,
      'show_location': showLocation,
      'show_phone': showPhone,
      'show_email': showEmail,
      'show_bio': showBio,
      'show_profile_photo': showProfilePhoto,
      'show_friends_list': showFriendsList,
      'allow_profile_indexing': allowProfileIndexing,
      'show_stats': showStats,
      'show_sports_profiles': showSportsProfiles,
      'show_game_history': showGameHistory,
      'show_achievements': showAchievements,
      'show_online_status': showOnlineStatus,
      'show_activity_status': showActivityStatus,
      'show_check_ins': showCheckIns,
      'show_posts_to_public': showPostsToPublic,
      'message_preference': messagePreference.index,
      'game_invite_preference': gameInvitePreference.index,
      'friend_request_preference': friendRequestPreference.index,
      'allow_push_notifications': allowPushNotifications,
      'allow_email_notifications': allowEmailNotifications,
      'allow_location_tracking': allowLocationTracking,
      'allow_data_analytics': allowDataAnalytics,
      'data_sharing_level': dataSharingLevel.index,
      'allow_game_recommendations': allowGameRecommendations,
      'hide_from_nearby': hideFromNearby,
      'two_factor_enabled': twoFactorEnabled,
      'login_alerts': loginAlerts,
      'blocked_users': blockedUsers,
    };
  }

  /// Converts to JSON with string enum values (for external APIs)
  Map<String, dynamic> toExternalJson() {
    return {
      'profile_visibility': profileVisibility.name,
      'show_real_name': showRealName,
      'show_age': showAge,
      'show_location': showLocation,
      'show_phone': showPhone,
      'show_email': showEmail,
      'show_bio': showBio,
      'show_profile_photo': showProfilePhoto,
      'show_friends_list': showFriendsList,
      'allow_profile_indexing': allowProfileIndexing,
      'show_stats': showStats,
      'show_sports_profiles': showSportsProfiles,
      'show_game_history': showGameHistory,
      'show_achievements': showAchievements,
      'show_online_status': showOnlineStatus,
      'show_activity_status': showActivityStatus,
      'show_check_ins': showCheckIns,
      'show_posts_to_public': showPostsToPublic,
      'message_preference': messagePreference.name,
      'game_invite_preference': gameInvitePreference.name,
      'friend_request_preference': friendRequestPreference.name,
      'allow_push_notifications': allowPushNotifications,
      'allow_email_notifications': allowEmailNotifications,
      'allow_location_tracking': allowLocationTracking,
      'allow_data_analytics': allowDataAnalytics,
      'data_sharing_level': dataSharingLevel.name,
      'allow_game_recommendations': allowGameRecommendations,
      'hide_from_nearby': hideFromNearby,
      'two_factor_enabled': twoFactorEnabled,
      'login_alerts': loginAlerts,
      'blocked_users': blockedUsers,
    };
  }

  /// Converts to JSON for database updates (only changed fields)
  Map<String, dynamic> toUpdateJson() {
    return {...toJson(), 'updated_at': DateTime.now().toIso8601String()};
  }

  // Helper parsing methods

  static ProfileVisibility _parseProfileVisibility(dynamic value) {
    if (value == null) return ProfileVisibility.public;

    if (value is int) {
      switch (value) {
        case 0:
          return ProfileVisibility.public;
        case 1:
          return ProfileVisibility.friends;
        case 2:
          return ProfileVisibility.private;
        default:
          return ProfileVisibility.public;
      }
    }

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'public':
          return ProfileVisibility.public;
        case 'friends':
          return ProfileVisibility.friends;
        case 'private':
          return ProfileVisibility.private;
        default:
          return ProfileVisibility.public;
      }
    }

    return ProfileVisibility.public;
  }

  static CommunicationPreference _parseCommunicationPreference(dynamic value) {
    if (value == null) return CommunicationPreference.anyone;

    if (value is int) {
      switch (value) {
        case 0:
          return CommunicationPreference.anyone;
        case 1:
          return CommunicationPreference.friendsOnly;
        case 2:
          return CommunicationPreference.organizersOnly;
        case 3:
          return CommunicationPreference.none;
        default:
          return CommunicationPreference.anyone;
      }
    }

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'anyone':
          return CommunicationPreference.anyone;
        case 'friends_only':
        case 'friendsonly':
        case 'friends':
          return CommunicationPreference.friendsOnly;
        case 'organizers_only':
        case 'organizersonly':
        case 'organizers':
          return CommunicationPreference.organizersOnly;
        case 'none':
          return CommunicationPreference.none;
        default:
          return CommunicationPreference.anyone;
      }
    }

    return CommunicationPreference.anyone;
  }

  static DataSharingLevel _parseDataSharingLevel(dynamic value) {
    if (value == null) return DataSharingLevel.limited;

    if (value is int) {
      switch (value) {
        case 0:
          return DataSharingLevel.minimal;
        case 1:
          return DataSharingLevel.limited;
        case 2:
          return DataSharingLevel.full;
        default:
          return DataSharingLevel.limited;
      }
    }

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'minimal':
          return DataSharingLevel.minimal;
        case 'limited':
          return DataSharingLevel.limited;
        case 'full':
          return DataSharingLevel.full;
        default:
          return DataSharingLevel.limited;
      }
    }

    return DataSharingLevel.limited;
  }

  static bool _parseBoolWithDefault(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return defaultValue;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    if (value is String) {
      if (value.isEmpty) return [];

      // Handle JSON array strings
      if (value.startsWith('[') && value.endsWith(']')) {
        try {
          final cleaned = value.substring(1, value.length - 1);
          if (cleaned.isEmpty) return [];

          return cleaned
              .split(',')
              .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (e) {
          return [];
        }
      }

      // Handle comma-separated values
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  /// Creates a copy with updated fields
  @override
  PrivacySettingsModel copyWith({
    ProfileVisibility? profileVisibility,
    bool? showRealName,
    bool? showAge,
    bool? showLocation,
    bool? showPhone,
    bool? showEmail,
    bool? showBio,
    bool? showProfilePhoto,
    bool? showFriendsList,
    bool? allowProfileIndexing,
    bool? showStats,
    bool? showSportsProfiles,
    bool? showGameHistory,
    bool? showAchievements,
    bool? showOnlineStatus,
    bool? showActivityStatus,
    bool? showCheckIns,
    bool? showPostsToPublic,
    CommunicationPreference? messagePreference,
    CommunicationPreference? gameInvitePreference,
    CommunicationPreference? friendRequestPreference,
    bool? allowPushNotifications,
    bool? allowEmailNotifications,
    bool? allowLocationTracking,
    bool? allowDataAnalytics,
    DataSharingLevel? dataSharingLevel,
    bool? allowGameRecommendations,
    bool? hideFromNearby,
    bool? twoFactorEnabled,
    bool? loginAlerts,
    List<String>? blockedUsers,
  }) {
    return PrivacySettingsModel(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      showRealName: showRealName ?? this.showRealName,
      showAge: showAge ?? this.showAge,
      showLocation: showLocation ?? this.showLocation,
      showPhone: showPhone ?? this.showPhone,
      showEmail: showEmail ?? this.showEmail,
      showBio: showBio ?? this.showBio,
      showProfilePhoto: showProfilePhoto ?? this.showProfilePhoto,
      showFriendsList: showFriendsList ?? this.showFriendsList,
      allowProfileIndexing: allowProfileIndexing ?? this.allowProfileIndexing,
      showStats: showStats ?? this.showStats,
      showSportsProfiles: showSportsProfiles ?? this.showSportsProfiles,
      showGameHistory: showGameHistory ?? this.showGameHistory,
      showAchievements: showAchievements ?? this.showAchievements,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      showCheckIns: showCheckIns ?? this.showCheckIns,
      showPostsToPublic: showPostsToPublic ?? this.showPostsToPublic,
      messagePreference: messagePreference ?? this.messagePreference,
      gameInvitePreference: gameInvitePreference ?? this.gameInvitePreference,
      friendRequestPreference:
          friendRequestPreference ?? this.friendRequestPreference,
      allowPushNotifications:
          allowPushNotifications ?? this.allowPushNotifications,
      allowEmailNotifications:
          allowEmailNotifications ?? this.allowEmailNotifications,
      allowLocationTracking:
          allowLocationTracking ?? this.allowLocationTracking,
      allowDataAnalytics: allowDataAnalytics ?? this.allowDataAnalytics,
      dataSharingLevel: dataSharingLevel ?? this.dataSharingLevel,
      allowGameRecommendations:
          allowGameRecommendations ?? this.allowGameRecommendations,
      hideFromNearby: hideFromNearby ?? this.hideFromNearby,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      loginAlerts: loginAlerts ?? this.loginAlerts,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }

  /// Converts back to domain entity
  PrivacySettings toEntity() {
    return PrivacySettings(
      profileVisibility: profileVisibility,
      showRealName: showRealName,
      showAge: showAge,
      showLocation: showLocation,
      showPhone: showPhone,
      showEmail: showEmail,
      showBio: showBio,
      showProfilePhoto: showProfilePhoto,
      showFriendsList: showFriendsList,
      allowProfileIndexing: allowProfileIndexing,
      showStats: showStats,
      showSportsProfiles: showSportsProfiles,
      showGameHistory: showGameHistory,
      showAchievements: showAchievements,
      showOnlineStatus: showOnlineStatus,
      showActivityStatus: showActivityStatus,
      showCheckIns: showCheckIns,
      showPostsToPublic: showPostsToPublic,
      messagePreference: messagePreference,
      gameInvitePreference: gameInvitePreference,
      friendRequestPreference: friendRequestPreference,
      allowPushNotifications: allowPushNotifications,
      allowEmailNotifications: allowEmailNotifications,
      allowLocationTracking: allowLocationTracking,
      allowDataAnalytics: allowDataAnalytics,
      dataSharingLevel: dataSharingLevel,
      allowGameRecommendations: allowGameRecommendations,
      hideFromNearby: hideFromNearby,
      twoFactorEnabled: twoFactorEnabled,
      loginAlerts: loginAlerts,
      blockedUsers: blockedUsers,
    );
  }
}
