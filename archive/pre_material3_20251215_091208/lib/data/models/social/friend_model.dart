import 'package:dabbler/data/models/social/friend.dart';

/// Data model for friendships with comprehensive profile data
class FriendModel extends Friend {
  final String profilePicture;
  final String bio;
  final bool isVerified;
  final bool isOnline;
  final DateTime? lastSeen;
  final int mutualFriendsCount;
  final List<String> mutualFriendIds;
  final Map<String, dynamic>? gameStats;
  final List<String> favorSports;
  final String? city;
  final DateTime? joinedDate;
  final bool isBlocked;
  final bool hasBlockedMe;

  const FriendModel({
    required super.id,
    required super.userId,
    required super.friendId,
    required super.friendName,
    required super.friendUsername,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.friendRequestSentAt,
    super.friendRequestAcceptedAt,
    this.profilePicture = '',
    this.bio = '',
    this.isVerified = false,
    this.isOnline = false,
    this.lastSeen,
    this.mutualFriendsCount = 0,
    this.mutualFriendIds = const [],
    this.gameStats,
    this.favorSports = const [],
    this.city,
    this.joinedDate,
    this.isBlocked = false,
    this.hasBlockedMe = false,
  });

  /// Create FriendModel from Supabase JSON response
  /// Handles both directions of friendship and includes profile data
  factory FriendModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    // Determine if this is a friendship request or response
    // The JSON might contain friendship data with nested profile info
    Map<String, dynamic> profileData = {};

    String friendId = '';
    String friendName = '';
    String friendUsername = '';

    // Handle different JSON structures from different API endpoints
    if (json.containsKey('friend_profile') && json['friend_profile'] != null) {
      // Friend request format with nested profile
      profileData = json['friend_profile'] as Map<String, dynamic>;
      friendId = profileData['id'] ?? '';
    } else if (json.containsKey('user_profile') &&
        json['user_profile'] != null) {
      // Request received format with nested profile
      profileData = json['user_profile'] as Map<String, dynamic>;
      friendId = profileData['id'] ?? '';
    } else if (json.containsKey('profiles')) {
      // Join query format with profiles table
      profileData = json['profiles'] as Map<String, dynamic>;
      friendId = json['friend_id'] ?? json['user_id'] ?? '';
    } else {
      // Direct profile data format
      profileData = json;
      friendId = json['friend_id'] ?? json['user_id'] ?? json['id'] ?? '';
    }

    // Ensure we get the correct friend data based on current user
    if (currentUserId != null) {
      final userId1 = json['user_id'] ?? '';
      final userId2 = json['friend_id'] ?? '';

      if (userId1 == currentUserId) {
        friendId = userId2;
      } else {
        friendId = userId1;
      }
    }

    friendName =
        profileData['full_name'] ??
        profileData['display_name'] ??
        profileData['display_name'] ??
        'Unknown User';

    friendUsername = profileData['username'] ?? profileData['handle'] ?? '';

    // Parse friendship status
    FriendshipStatus status = FriendshipStatus.pending;
    final statusStr = json['status']?.toString().toLowerCase() ?? 'pending';
    switch (statusStr) {
      case 'pending':
        status = FriendshipStatus.pending;
        break;
      case 'accepted':
      case 'friends':
        status = FriendshipStatus.accepted;
        break;
      case 'declined':
      case 'rejected':
        status = FriendshipStatus.declined;
        break;
      case 'blocked':
        status = FriendshipStatus.blocked;
        break;
      default:
        status = FriendshipStatus.pending;
    }

    // Parse mutual friends data
    final mutualFriendsData = json['mutual_friends'] ?? [];
    List<String> mutualFriendIds = [];
    int mutualFriendsCount = 0;

    if (mutualFriendsData is List) {
      mutualFriendIds = mutualFriendsData
          .map((friend) => friend.toString())
          .toList();
      mutualFriendsCount = mutualFriendIds.length;
    } else if (json['mutual_friends_count'] != null) {
      mutualFriendsCount = _parseInt(json['mutual_friends_count']);
    }

    // Parse favorite sports
    List<String> favorSports = [];
    if (profileData['favorite_sports'] != null) {
      if (profileData['favorite_sports'] is String) {
        final sportsString = profileData['favorite_sports'] as String;
        favorSports = sportsString.split(',').map((s) => s.trim()).toList();
      } else if (profileData['favorite_sports'] is List) {
        favorSports = (profileData['favorite_sports'] as List)
            .map((sport) => sport.toString())
            .toList();
      }
    }

    // Parse game statistics
    Map<String, dynamic>? gameStats;
    if (profileData['game_stats'] != null) {
      gameStats = profileData['game_stats'] as Map<String, dynamic>?;
    }

    return FriendModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? currentUserId ?? '',
      friendId: friendId,
      friendName: friendName,
      friendUsername: friendUsername,
      status: status,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      friendRequestSentAt: json['friend_request_sent_at'] != null
          ? _parseDateTime(json['friend_request_sent_at'])
          : null,
      friendRequestAcceptedAt: json['friend_request_accepted_at'] != null
          ? _parseDateTime(json['friend_request_accepted_at'])
          : null,
      profilePicture:
          profileData['avatar_url'] ?? profileData['profile_picture'] ?? '',
      bio: profileData['bio'] ?? profileData['description'] ?? '',
      isVerified:
          profileData['verified'] == true || profileData['is_verified'] == true,
      isOnline:
          profileData['is_online'] == true ||
          profileData['online_status'] == 'online',
      lastSeen: profileData['last_seen'] != null
          ? _parseDateTime(profileData['last_seen'])
          : null,
      mutualFriendsCount: mutualFriendsCount,
      mutualFriendIds: mutualFriendIds,
      gameStats: gameStats,
      favorSports: favorSports,
      city: profileData['city'],
      joinedDate: profileData['created_at'] != null
          ? _parseDateTime(profileData['created_at'])
          : null,
      isBlocked:
          json['is_blocked'] == true ||
          json['blocked'] == true ||
          status == FriendshipStatus.blocked,
      hasBlockedMe:
          json['has_blocked_me'] == true || json['blocked_by_friend'] == true,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': _statusToString(status),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (friendRequestSentAt != null)
        'friend_request_sent_at': friendRequestSentAt!.toIso8601String(),
      if (friendRequestAcceptedAt != null)
        'friend_request_accepted_at': friendRequestAcceptedAt!
            .toIso8601String(),
    };
  }

  /// Create JSON for sending friend request
  Map<String, dynamic> toFriendRequestJson() {
    return {
      'user_id': userId,
      'friend_id': friendId,
      'status': 'pending',
      'friend_request_sent_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create JSON for accepting friend request
  Map<String, dynamic> toAcceptRequestJson() {
    return {
      'status': 'accepted',
      'friend_request_accepted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create JSON for declining friend request
  Map<String, dynamic> toDeclineRequestJson() {
    return {
      'status': 'declined',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create JSON for blocking user
  Map<String, dynamic> toBlockUserJson() {
    return {
      'status': 'blocked',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  FriendModel copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? friendName,
    String? friendUsername,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? friendRequestSentAt,
    DateTime? friendRequestAcceptedAt,
    String? profilePicture,
    String? bio,
    bool? isVerified,
    bool? isOnline,
    DateTime? lastSeen,
    int? mutualFriendsCount,
    List<String>? mutualFriendIds,
    Map<String, dynamic>? gameStats,
    List<String>? favorSports,
    String? location,
    DateTime? joinedDate,
    bool? isBlocked,
    bool? hasBlockedMe,
  }) {
    return FriendModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      friendName: friendName ?? this.friendName,
      friendUsername: friendUsername ?? this.friendUsername,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      friendRequestSentAt: friendRequestSentAt ?? this.friendRequestSentAt,
      friendRequestAcceptedAt:
          friendRequestAcceptedAt ?? this.friendRequestAcceptedAt,
      profilePicture: profilePicture ?? this.profilePicture,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      mutualFriendsCount: mutualFriendsCount ?? this.mutualFriendsCount,
      mutualFriendIds: mutualFriendIds ?? this.mutualFriendIds,
      gameStats: gameStats ?? this.gameStats,
      favorSports: favorSports ?? this.favorSports,
      city: city ?? city,
      joinedDate: joinedDate ?? this.joinedDate,
      isBlocked: isBlocked ?? this.isBlocked,
      hasBlockedMe: hasBlockedMe ?? this.hasBlockedMe,
    );
  }

  /// Check if friend request can be sent
  bool canSendFriendRequest() {
    return status != FriendshipStatus.accepted &&
        status != FriendshipStatus.blocked &&
        !isBlocked &&
        !hasBlockedMe;
  }

  /// Check if this is a pending request sent by current user
  bool isPendingRequestSentByUser(String currentUserId) {
    return status == FriendshipStatus.pending && userId == currentUserId;
  }

  /// Check if this is a pending request received by current user
  bool isPendingRequestReceived(String currentUserId) {
    return status == FriendshipStatus.pending && friendId == currentUserId;
  }

  /// Get display name with fallback
  String get displayName {
    if (friendName.isNotEmpty) return friendName;
    if (friendUsername.isNotEmpty) return '@$friendUsername';
    return 'Unknown User';
  }

  /// Get online status text
  String get onlineStatusText {
    if (isOnline) return 'Online';
    if (lastSeen != null) {
      final diff = DateTime.now().difference(lastSeen!);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return 'Long time ago';
    }
    return 'Offline';
  }

  // Helper methods
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.round();
    return 0;
  }

  static String _statusToString(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.pending:
        return 'pending';
      case FriendshipStatus.accepted:
        return 'accepted';
      case FriendshipStatus.declined:
        return 'declined';
      case FriendshipStatus.blocked:
        return 'blocked';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FriendModel{id: $id, friendName: $friendName, status: $status, mutualFriends: $mutualFriendsCount}';
  }
}

/// Model for mutual friends data
class MutualFriendModel {
  final String id;
  final String name;
  final String username;
  final String profilePicture;
  final bool isVerified;

  const MutualFriendModel({
    required this.id,
    required this.name,
    required this.username,
    this.profilePicture = '',
    this.isVerified = false,
  });

  factory MutualFriendModel.fromJson(Map<String, dynamic> json) {
    return MutualFriendModel(
      id: json['id'] ?? '',
      name: json['full_name'] ?? json['name'] ?? '',
      username: json['username'] ?? '',
      profilePicture: json['avatar_url'] ?? json['profile_picture'] ?? '',
      isVerified: json['verified'] == true || json['is_verified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'username': username,
      'avatar_url': profilePicture,
      'verified': isVerified,
    };
  }
}
