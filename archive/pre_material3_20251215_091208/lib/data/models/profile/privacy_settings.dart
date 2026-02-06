enum ProfileVisibility { public, friends, private }

enum CommunicationPreference { anyone, friendsOnly, organizersOnly, none }

enum DataSharingLevel { full, limited, minimal }

class PrivacySettings {
  final ProfileVisibility profileVisibility;
  final bool showRealName;
  final bool showAge;
  final bool showLocation;
  final bool showPhone;
  final bool showEmail;
  final bool showStats;
  final bool showSportsProfiles;
  final bool showGameHistory;
  final bool showAchievements;
  final CommunicationPreference messagePreference;
  final CommunicationPreference gameInvitePreference;
  final bool allowLocationTracking;
  final bool allowDataAnalytics;
  final DataSharingLevel dataSharingLevel;
  final List<String> blockedUsers;
  final bool showOnlineStatus;
  final bool allowGameRecommendations;

  const PrivacySettings({
    this.profileVisibility = ProfileVisibility.public,
    this.showRealName = true,
    this.showAge = false,
    this.showLocation = true,
    this.showPhone = false,
    this.showEmail = false,
    this.showStats = true,
    this.showSportsProfiles = true,
    this.showGameHistory = true,
    this.showAchievements = true,
    this.messagePreference = CommunicationPreference.anyone,
    this.gameInvitePreference = CommunicationPreference.anyone,
    this.allowLocationTracking = true,
    this.allowDataAnalytics = true,
    this.dataSharingLevel = DataSharingLevel.limited,
    this.blockedUsers = const [],
    this.showOnlineStatus = true,
    this.allowGameRecommendations = true,
  });

  /// Checks if a viewer can see this profile
  bool canViewProfile(String? viewerId) {
    // Own profile is always viewable
    if (viewerId != null && blockedUsers.contains(viewerId)) {
      return false;
    }

    switch (profileVisibility) {
      case ProfileVisibility.public:
        return true;
      case ProfileVisibility.friends:
        // Would need to check friendship status - simplified for now
        return viewerId != null;
      case ProfileVisibility.private:
        return false;
    }
  }

  /// Checks if a user can send messages
  bool canMessage(String? senderId, {bool isOrganizer = false}) {
    if (senderId == null || blockedUsers.contains(senderId)) {
      return false;
    }

    switch (messagePreference) {
      case CommunicationPreference.anyone:
        return true;
      case CommunicationPreference.friendsOnly:
        // Would need to check friendship status
        return true; // Simplified
      case CommunicationPreference.organizersOnly:
        return isOrganizer;
      case CommunicationPreference.none:
        return false;
    }
  }

  /// Checks if a user can send game invites
  bool canSendGameInvite(String? senderId, {bool isOrganizer = false}) {
    if (senderId == null || blockedUsers.contains(senderId)) {
      return false;
    }

    switch (gameInvitePreference) {
      case CommunicationPreference.anyone:
        return true;
      case CommunicationPreference.friendsOnly:
        return true; // Simplified
      case CommunicationPreference.organizersOnly:
        return isOrganizer;
      case CommunicationPreference.none:
        return false;
    }
  }

  /// Checks if specific profile data should be shown to a viewer
  bool canViewField(String fieldName, String? viewerId) {
    if (!canViewProfile(viewerId)) return false;

    switch (fieldName) {
      case 'realName':
        return showRealName;
      case 'age':
        return showAge;
      case 'location':
        return showLocation;
      case 'phone':
        return showPhone;
      case 'email':
        return showEmail;
      case 'stats':
        return showStats;
      case 'sportsProfiles':
        return showSportsProfiles;
      case 'gameHistory':
        return showGameHistory;
      case 'achievements':
        return showAchievements;
      case 'onlineStatus':
        return showOnlineStatus;
      default:
        return true;
    }
  }

  /// Returns privacy score (0-100, higher = more private)
  int getPrivacyScore() {
    int score = 0;

    // Profile visibility
    switch (profileVisibility) {
      case ProfileVisibility.private:
        score += 30;
        break;
      case ProfileVisibility.friends:
        score += 15;
        break;
      case ProfileVisibility.public:
        score += 0;
        break;
    }

    // Personal info visibility
    if (!showRealName) score += 10;
    if (!showAge) score += 5;
    if (!showLocation) score += 10;
    if (!showPhone) score += 10;
    if (!showEmail) score += 10;

    // Communication restrictions
    switch (messagePreference) {
      case CommunicationPreference.none:
        score += 10;
        break;
      case CommunicationPreference.organizersOnly:
        score += 7;
        break;
      case CommunicationPreference.friendsOnly:
        score += 3;
        break;
      case CommunicationPreference.anyone:
        score += 0;
        break;
    }

    // Data sharing
    if (!allowLocationTracking) score += 5;
    if (!allowDataAnalytics) score += 5;
    if (!showOnlineStatus) score += 3;
    if (!allowGameRecommendations) score += 2;

    return score.clamp(0, 100);
  }

  /// Creates a copy with updated fields
  PrivacySettings copyWith({
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
    return PrivacySettings(
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

  /// Creates PrivacySettings from JSON
  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      profileVisibility: ProfileVisibility.values.firstWhere(
        (e) => e.toString().split('.').last == json['profileVisibility'],
        orElse: () => ProfileVisibility.public,
      ),
      showRealName: json['showRealName'] as bool? ?? true,
      showAge: json['showAge'] as bool? ?? false,
      showLocation: json['showLocation'] as bool? ?? true,
      showPhone: json['showPhone'] as bool? ?? false,
      showEmail: json['showEmail'] as bool? ?? false,
      showStats: json['showStats'] as bool? ?? true,
      showSportsProfiles: json['showSportsProfiles'] as bool? ?? true,
      showGameHistory: json['showGameHistory'] as bool? ?? true,
      showAchievements: json['showAchievements'] as bool? ?? true,
      messagePreference: CommunicationPreference.values.firstWhere(
        (e) => e.toString().split('.').last == json['messagePreference'],
        orElse: () => CommunicationPreference.anyone,
      ),
      gameInvitePreference: CommunicationPreference.values.firstWhere(
        (e) => e.toString().split('.').last == json['gameInvitePreference'],
        orElse: () => CommunicationPreference.anyone,
      ),
      allowLocationTracking: json['allowLocationTracking'] as bool? ?? true,
      allowDataAnalytics: json['allowDataAnalytics'] as bool? ?? true,
      dataSharingLevel: DataSharingLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['dataSharingLevel'],
        orElse: () => DataSharingLevel.limited,
      ),
      blockedUsers: List<String>.from(json['blockedUsers'] as List? ?? []),
      showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
      allowGameRecommendations:
          json['allowGameRecommendations'] as bool? ?? true,
    );
  }

  /// Converts PrivacySettings to JSON
  Map<String, dynamic> toJson() {
    return {
      'profileVisibility': profileVisibility.toString().split('.').last,
      'showRealName': showRealName,
      'showAge': showAge,
      'showLocation': showLocation,
      'showPhone': showPhone,
      'showEmail': showEmail,
      'showStats': showStats,
      'showSportsProfiles': showSportsProfiles,
      'showGameHistory': showGameHistory,
      'showAchievements': showAchievements,
      'messagePreference': messagePreference.toString().split('.').last,
      'gameInvitePreference': gameInvitePreference.toString().split('.').last,
      'allowLocationTracking': allowLocationTracking,
      'allowDataAnalytics': allowDataAnalytics,
      'dataSharingLevel': dataSharingLevel.toString().split('.').last,
      'blockedUsers': blockedUsers,
      'showOnlineStatus': showOnlineStatus,
      'allowGameRecommendations': allowGameRecommendations,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrivacySettings &&
        other.profileVisibility == profileVisibility &&
        other.showRealName == showRealName &&
        other.showAge == showAge &&
        other.showLocation == showLocation &&
        other.showPhone == showPhone &&
        other.showEmail == showEmail &&
        other.showStats == showStats &&
        other.showSportsProfiles == showSportsProfiles &&
        other.showGameHistory == showGameHistory &&
        other.showAchievements == showAchievements &&
        other.messagePreference == messagePreference &&
        other.gameInvitePreference == gameInvitePreference &&
        other.allowLocationTracking == allowLocationTracking &&
        other.allowDataAnalytics == allowDataAnalytics &&
        other.dataSharingLevel == dataSharingLevel &&
        _listEquals(other.blockedUsers, blockedUsers) &&
        other.showOnlineStatus == showOnlineStatus &&
        other.allowGameRecommendations == allowGameRecommendations;
  }

  @override
  int get hashCode {
    return Object.hash(
      profileVisibility,
      showRealName,
      showAge,
      showLocation,
      showPhone,
      showEmail,
      showStats,
      showSportsProfiles,
      showGameHistory,
      showAchievements,
      messagePreference,
      gameInvitePreference,
      allowLocationTracking,
      allowDataAnalytics,
      dataSharingLevel,
      Object.hashAll(blockedUsers),
      showOnlineStatus,
      allowGameRecommendations,
    );
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
