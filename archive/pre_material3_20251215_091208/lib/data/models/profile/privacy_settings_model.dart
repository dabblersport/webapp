import 'package:dabbler/data/models/profile/privacy_settings.dart';

class PrivacySettingsModel extends PrivacySettings {
  const PrivacySettingsModel({
    super.profileVisibility,
    super.showRealName,
    super.showAge,
    super.showLocation,
    super.showPhone,
    super.showEmail,
    super.showStats,
    super.showSportsProfiles,
    super.showGameHistory,
    super.showAchievements,
    super.messagePreference,
    super.gameInvitePreference,
    super.allowLocationTracking,
    super.allowDataAnalytics,
    super.dataSharingLevel,
    super.blockedUsers,
    super.showOnlineStatus,
    super.allowGameRecommendations,
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
      showStats: entity.showStats,
      showSportsProfiles: entity.showSportsProfiles,
      showGameHistory: entity.showGameHistory,
      showAchievements: entity.showAchievements,
      messagePreference: entity.messagePreference,
      gameInvitePreference: entity.gameInvitePreference,
      allowLocationTracking: entity.allowLocationTracking,
      allowDataAnalytics: entity.allowDataAnalytics,
      dataSharingLevel: entity.dataSharingLevel,
      blockedUsers: entity.blockedUsers,
      showOnlineStatus: entity.showOnlineStatus,
      allowGameRecommendations: entity.allowGameRecommendations,
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
      showStats: _parseBoolWithDefault(json['show_stats'], true),
      showSportsProfiles: _parseBoolWithDefault(
        json['show_sports_profiles'],
        true,
      ),
      showGameHistory: _parseBoolWithDefault(json['show_game_history'], true),
      showAchievements: _parseBoolWithDefault(json['show_achievements'], true),
      messagePreference: _parseCommunicationPreference(
        json['message_preference'],
      ),
      gameInvitePreference: _parseCommunicationPreference(
        json['game_invite_preference'],
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
      blockedUsers: _parseStringList(json['blocked_users']),
      showOnlineStatus: _parseBoolWithDefault(json['show_online_status'], true),
      allowGameRecommendations: _parseBoolWithDefault(
        json['allow_game_recommendations'],
        true,
      ),
    );
  }

  /// Creates PrivacySettingsModel from legacy database format
  factory PrivacySettingsModel.fromLegacyJson(Map<String, dynamic> json) {
    // Handle backward compatibility with older database schema
    return PrivacySettingsModel(
      profileVisibility: _parseProfileVisibility(
        json['visibility'] ?? json['profile_visibility'],
      ),
      showRealName: _parseBoolWithDefault(
        json['real_name_visible'] ?? json['show_real_name'],
        true,
      ),
      showAge: _parseBoolWithDefault(
        json['age_visible'] ?? json['show_age'],
        false,
      ),
      showLocation: _parseBoolWithDefault(
        json['location_visible'] ?? json['show_location'],
        true,
      ),
      showPhone: _parseBoolWithDefault(
        json['phone_visible'] ?? json['show_phone'],
        false,
      ),
      showEmail: _parseBoolWithDefault(
        json['email_visible'] ?? json['show_email'],
        false,
      ),
      showStats: _parseBoolWithDefault(
        json['stats_visible'] ?? json['show_stats'],
        true,
      ),
      showSportsProfiles: _parseBoolWithDefault(
        json['sports_visible'] ?? json['show_sports_profiles'],
        true,
      ),
      showGameHistory: _parseBoolWithDefault(
        json['history_visible'] ?? json['show_game_history'],
        true,
      ),
      showAchievements: _parseBoolWithDefault(
        json['achievements_visible'] ?? json['show_achievements'],
        true,
      ),
      messagePreference: _parseCommunicationPreference(
        json['message_pref'] ?? json['message_preference'],
      ),
      gameInvitePreference: _parseCommunicationPreference(
        json['game_invite_pref'] ?? json['game_invite_preference'],
      ),
      allowLocationTracking: _parseBoolWithDefault(
        json['location_tracking'] ?? json['allow_location_tracking'],
        true,
      ),
      allowDataAnalytics: _parseBoolWithDefault(
        json['data_analytics'] ?? json['allow_data_analytics'],
        true,
      ),
      dataSharingLevel: _parseDataSharingLevel(
        json['data_sharing'] ?? json['data_sharing_level'],
      ),
      blockedUsers: _parseStringList(
        json['blocked_users'] ?? json['blocked_users'],
      ),
      showOnlineStatus: _parseBoolWithDefault(
        json['online_status'] ?? json['show_online_status'],
        true,
      ),
      allowGameRecommendations: _parseBoolWithDefault(
        json['game_recommendations'] ?? json['allow_game_recommendations'],
        true,
      ),
    );
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
      'show_stats': showStats,
      'show_sports_profiles': showSportsProfiles,
      'show_game_history': showGameHistory,
      'show_achievements': showAchievements,
      'message_preference': messagePreference.index,
      'game_invite_preference': gameInvitePreference.index,
      'allow_location_tracking': allowLocationTracking,
      'allow_data_analytics': allowDataAnalytics,
      'data_sharing_level': dataSharingLevel.index,
      'blocked_users': blockedUsers,
      'show_online_status': showOnlineStatus,
      'allow_game_recommendations': allowGameRecommendations,
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
      'show_stats': showStats,
      'show_sports_profiles': showSportsProfiles,
      'show_game_history': showGameHistory,
      'show_achievements': showAchievements,
      'message_preference': messagePreference.name,
      'game_invite_preference': gameInvitePreference.name,
      'allow_location_tracking': allowLocationTracking,
      'allow_data_analytics': allowDataAnalytics,
      'data_sharing_level': dataSharingLevel.name,
      'blocked_users': blockedUsers,
      'show_online_status': showOnlineStatus,
      'allow_game_recommendations': allowGameRecommendations,
    };
  }

  /// Converts to JSON for database updates (only changed fields)
  Map<String, dynamic> toUpdateJson() {
    return {
      'profile_visibility': profileVisibility.index,
      'show_real_name': showRealName,
      'show_age': showAge,
      'show_location': showLocation,
      'show_phone': showPhone,
      'show_email': showEmail,
      'show_stats': showStats,
      'show_sports_profiles': showSportsProfiles,
      'show_game_history': showGameHistory,
      'show_achievements': showAchievements,
      'message_preference': messagePreference.index,
      'game_invite_preference': gameInvitePreference.index,
      'allow_location_tracking': allowLocationTracking,
      'allow_data_analytics': allowDataAnalytics,
      'data_sharing_level': dataSharingLevel.index,
      'blocked_users': blockedUsers,
      'show_online_status': showOnlineStatus,
      'allow_game_recommendations': allowGameRecommendations,
      'updated_at': DateTime.now().toIso8601String(),
    };
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
    bool? showStats,
    bool? showSportsProfiles,
    bool? showGameHistory,
    bool? showAchievements,
    CommunicationPreference? messagePreference,
    CommunicationPreference? gameInvitePreference,
    bool? allowLocationTracking,
    bool? allowDataAnalytics,
    DataSharingLevel? dataSharingLevel,
    List<String>? blockedUsers,
    bool? showOnlineStatus,
    bool? allowGameRecommendations,
  }) {
    return PrivacySettingsModel(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      showRealName: showRealName ?? this.showRealName,
      showAge: showAge ?? this.showAge,
      showLocation: showLocation ?? this.showLocation,
      showPhone: showPhone ?? this.showPhone,
      showEmail: showEmail ?? this.showEmail,
      showStats: showStats ?? this.showStats,
      showSportsProfiles: showSportsProfiles ?? this.showSportsProfiles,
      showGameHistory: showGameHistory ?? this.showGameHistory,
      showAchievements: showAchievements ?? this.showAchievements,
      messagePreference: messagePreference ?? this.messagePreference,
      gameInvitePreference: gameInvitePreference ?? this.gameInvitePreference,
      allowLocationTracking:
          allowLocationTracking ?? this.allowLocationTracking,
      allowDataAnalytics: allowDataAnalytics ?? this.allowDataAnalytics,
      dataSharingLevel: dataSharingLevel ?? this.dataSharingLevel,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowGameRecommendations:
          allowGameRecommendations ?? this.allowGameRecommendations,
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
      showStats: showStats,
      showSportsProfiles: showSportsProfiles,
      showGameHistory: showGameHistory,
      showAchievements: showAchievements,
      messagePreference: messagePreference,
      gameInvitePreference: gameInvitePreference,
      allowLocationTracking: allowLocationTracking,
      allowDataAnalytics: allowDataAnalytics,
      dataSharingLevel: dataSharingLevel,
      blockedUsers: blockedUsers,
      showOnlineStatus: showOnlineStatus,
      allowGameRecommendations: allowGameRecommendations,
    );
  }
}
