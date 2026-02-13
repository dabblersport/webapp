enum ProfileVisibility { public, friends, private }

enum CommunicationPreference { anyone, friendsOnly, organizersOnly, none }

enum DataSharingLevel { full, limited, minimal }

class PrivacySettings {
  // ── Profile & Identity ──
  final ProfileVisibility profileVisibility;
  final bool showRealName;
  final bool showAge;
  final bool showLocation;
  final bool showPhone;
  final bool showEmail;
  final bool showBio;
  final bool showProfilePhoto;
  final bool showFriendsList;
  final bool allowProfileIndexing;

  // ── Activity & Stats ──
  final bool showStats;
  final bool showSportsProfiles;
  final bool showGameHistory;
  final bool showAchievements;
  final bool showOnlineStatus;
  final bool showActivityStatus;
  final bool showCheckIns;
  final bool showPostsToPublic;

  // ── Communication ──
  final CommunicationPreference messagePreference;
  final CommunicationPreference gameInvitePreference;
  final CommunicationPreference friendRequestPreference;

  // ── Notifications ──
  final bool allowPushNotifications;
  final bool allowEmailNotifications;

  // ── Data & Analytics ──
  final bool allowLocationTracking;
  final bool allowDataAnalytics;
  final DataSharingLevel dataSharingLevel;
  final bool allowGameRecommendations;
  final bool hideFromNearby;

  // ── Security ──
  final bool twoFactorEnabled;
  final bool loginAlerts;

  // ── Blocked users (runtime-only, not a DB column) ──
  final List<String> blockedUsers;

  const PrivacySettings({
    // Profile & Identity
    this.profileVisibility = ProfileVisibility.public,
    this.showRealName = true,
    this.showAge = false,
    this.showLocation = true,
    this.showPhone = false,
    this.showEmail = false,
    this.showBio = true,
    this.showProfilePhoto = true,
    this.showFriendsList = false,
    this.allowProfileIndexing = true,
    // Activity & Stats
    this.showStats = true,
    this.showSportsProfiles = true,
    this.showGameHistory = true,
    this.showAchievements = true,
    this.showOnlineStatus = true,
    this.showActivityStatus = true,
    this.showCheckIns = true,
    this.showPostsToPublic = true,
    // Communication
    this.messagePreference = CommunicationPreference.anyone,
    this.gameInvitePreference = CommunicationPreference.anyone,
    this.friendRequestPreference = CommunicationPreference.anyone,
    // Notifications
    this.allowPushNotifications = true,
    this.allowEmailNotifications = true,
    // Data & Analytics
    this.allowLocationTracking = true,
    this.allowDataAnalytics = true,
    this.dataSharingLevel = DataSharingLevel.limited,
    this.allowGameRecommendations = true,
    this.hideFromNearby = false,
    // Security
    this.twoFactorEnabled = false,
    this.loginAlerts = true,
    // Blocked users
    this.blockedUsers = const [],
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
      case 'bio':
        return showBio;
      case 'profilePhoto':
        return showProfilePhoto;
      case 'friendsList':
        return showFriendsList;
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
      case 'activityStatus':
        return showActivityStatus;
      case 'checkIns':
        return showCheckIns;
      default:
        return true;
    }
  }

  /// Returns privacy score (0-100, higher = more private)
  int getPrivacyScore() {
    int score = 0;

    // Profile visibility (30 points)
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

    // Personal info visibility (25 points)
    if (!showRealName) score += 5;
    if (!showAge) score += 3;
    if (!showLocation) score += 5;
    if (!showPhone) score += 5;
    if (!showEmail) score += 5;
    if (!showBio) score += 1;
    if (!showProfilePhoto) score += 1;

    // Discoverability (5 points)
    if (!allowProfileIndexing) score += 3;
    if (hideFromNearby) score += 2;

    // Communication restrictions (10 points)
    switch (messagePreference) {
      case CommunicationPreference.none:
        score += 5;
        break;
      case CommunicationPreference.organizersOnly:
        score += 3;
        break;
      case CommunicationPreference.friendsOnly:
        score += 2;
        break;
      case CommunicationPreference.anyone:
        score += 0;
        break;
    }
    switch (friendRequestPreference) {
      case CommunicationPreference.none:
        score += 5;
        break;
      case CommunicationPreference.friendsOnly:
        score += 3;
        break;
      default:
        break;
    }

    // Activity visibility (10 points)
    if (!showOnlineStatus) score += 3;
    if (!showActivityStatus) score += 2;
    if (!showCheckIns) score += 2;
    if (!showPostsToPublic) score += 3;

    // Data sharing (10 points)
    if (!allowLocationTracking) score += 3;
    if (!allowDataAnalytics) score += 3;
    if (!allowGameRecommendations) score += 2;
    switch (dataSharingLevel) {
      case DataSharingLevel.minimal:
        score += 2;
        break;
      case DataSharingLevel.limited:
        score += 1;
        break;
      case DataSharingLevel.full:
        break;
    }

    // Security (10 points)
    if (twoFactorEnabled) score += 5;
    if (loginAlerts) score += 5;

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
    return PrivacySettings(
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
      showBio: json['showBio'] as bool? ?? true,
      showProfilePhoto: json['showProfilePhoto'] as bool? ?? true,
      showFriendsList: json['showFriendsList'] as bool? ?? false,
      allowProfileIndexing: json['allowProfileIndexing'] as bool? ?? true,
      showStats: json['showStats'] as bool? ?? true,
      showSportsProfiles: json['showSportsProfiles'] as bool? ?? true,
      showGameHistory: json['showGameHistory'] as bool? ?? true,
      showAchievements: json['showAchievements'] as bool? ?? true,
      showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
      showActivityStatus: json['showActivityStatus'] as bool? ?? true,
      showCheckIns: json['showCheckIns'] as bool? ?? true,
      showPostsToPublic: json['showPostsToPublic'] as bool? ?? true,
      messagePreference: CommunicationPreference.values.firstWhere(
        (e) => e.toString().split('.').last == json['messagePreference'],
        orElse: () => CommunicationPreference.anyone,
      ),
      gameInvitePreference: CommunicationPreference.values.firstWhere(
        (e) => e.toString().split('.').last == json['gameInvitePreference'],
        orElse: () => CommunicationPreference.anyone,
      ),
      friendRequestPreference: CommunicationPreference.values.firstWhere(
        (e) => e.toString().split('.').last == json['friendRequestPreference'],
        orElse: () => CommunicationPreference.anyone,
      ),
      allowPushNotifications: json['allowPushNotifications'] as bool? ?? true,
      allowEmailNotifications: json['allowEmailNotifications'] as bool? ?? true,
      allowLocationTracking: json['allowLocationTracking'] as bool? ?? true,
      allowDataAnalytics: json['allowDataAnalytics'] as bool? ?? true,
      dataSharingLevel: DataSharingLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['dataSharingLevel'],
        orElse: () => DataSharingLevel.limited,
      ),
      allowGameRecommendations:
          json['allowGameRecommendations'] as bool? ?? true,
      hideFromNearby: json['hideFromNearby'] as bool? ?? false,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      loginAlerts: json['loginAlerts'] as bool? ?? true,
      blockedUsers: List<String>.from(json['blockedUsers'] as List? ?? []),
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
      'showBio': showBio,
      'showProfilePhoto': showProfilePhoto,
      'showFriendsList': showFriendsList,
      'allowProfileIndexing': allowProfileIndexing,
      'showStats': showStats,
      'showSportsProfiles': showSportsProfiles,
      'showGameHistory': showGameHistory,
      'showAchievements': showAchievements,
      'showOnlineStatus': showOnlineStatus,
      'showActivityStatus': showActivityStatus,
      'showCheckIns': showCheckIns,
      'showPostsToPublic': showPostsToPublic,
      'messagePreference': messagePreference.toString().split('.').last,
      'gameInvitePreference': gameInvitePreference.toString().split('.').last,
      'friendRequestPreference': friendRequestPreference
          .toString()
          .split('.')
          .last,
      'allowPushNotifications': allowPushNotifications,
      'allowEmailNotifications': allowEmailNotifications,
      'allowLocationTracking': allowLocationTracking,
      'allowDataAnalytics': allowDataAnalytics,
      'dataSharingLevel': dataSharingLevel.toString().split('.').last,
      'allowGameRecommendations': allowGameRecommendations,
      'hideFromNearby': hideFromNearby,
      'twoFactorEnabled': twoFactorEnabled,
      'loginAlerts': loginAlerts,
      'blockedUsers': blockedUsers,
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
        other.showBio == showBio &&
        other.showProfilePhoto == showProfilePhoto &&
        other.showFriendsList == showFriendsList &&
        other.allowProfileIndexing == allowProfileIndexing &&
        other.showStats == showStats &&
        other.showSportsProfiles == showSportsProfiles &&
        other.showGameHistory == showGameHistory &&
        other.showAchievements == showAchievements &&
        other.showOnlineStatus == showOnlineStatus &&
        other.showActivityStatus == showActivityStatus &&
        other.showCheckIns == showCheckIns &&
        other.showPostsToPublic == showPostsToPublic &&
        other.messagePreference == messagePreference &&
        other.gameInvitePreference == gameInvitePreference &&
        other.friendRequestPreference == friendRequestPreference &&
        other.allowPushNotifications == allowPushNotifications &&
        other.allowEmailNotifications == allowEmailNotifications &&
        other.allowLocationTracking == allowLocationTracking &&
        other.allowDataAnalytics == allowDataAnalytics &&
        other.dataSharingLevel == dataSharingLevel &&
        other.allowGameRecommendations == allowGameRecommendations &&
        other.hideFromNearby == hideFromNearby &&
        other.twoFactorEnabled == twoFactorEnabled &&
        other.loginAlerts == loginAlerts &&
        _listEquals(other.blockedUsers, blockedUsers);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      profileVisibility,
      showRealName,
      showAge,
      showLocation,
      showPhone,
      showEmail,
      showBio,
      showProfilePhoto,
      showFriendsList,
      allowProfileIndexing,
      showStats,
      showSportsProfiles,
      showGameHistory,
      showAchievements,
      showOnlineStatus,
      showActivityStatus,
      showCheckIns,
      showPostsToPublic,
      messagePreference,
      gameInvitePreference,
      friendRequestPreference,
      allowPushNotifications,
      allowEmailNotifications,
      allowLocationTracking,
      allowDataAnalytics,
      dataSharingLevel,
      allowGameRecommendations,
      hideFromNearby,
      twoFactorEnabled,
      loginAlerts,
      Object.hashAll(blockedUsers),
    ]);
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
