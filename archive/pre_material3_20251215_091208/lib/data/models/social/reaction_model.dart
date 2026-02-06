import '../../../../utils/enums/social_enums.dart';
import 'package:dabbler/data/models/social/reaction.dart';

/// Data model for reactions on posts and comments
class ReactionModel extends Reaction {
  final String userName;
  final String userAvatar;
  final bool userIsVerified;
  final List<GroupedReaction> groupedReactions;
  final Map<String, dynamic>? metadata;

  const ReactionModel({
    required super.id,
    required super.userId,
    required super.targetId,
    required super.targetType,
    required super.reactionType,
    required super.createdAt,
    this.userName = '',
    this.userAvatar = '',
    this.userIsVerified = false,
    this.groupedReactions = const [],
    this.metadata,
  });

  /// Create ReactionModel from Supabase JSON response
  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    // Parse target type
    ReactionTargetType targetType = ReactionTargetType.post;
    final targetTypeStr =
        json['target_type']?.toString().toLowerCase() ?? 'post';
    switch (targetTypeStr) {
      case 'post':
        targetType = ReactionTargetType.post;
        break;
      case 'comment':
        targetType = ReactionTargetType.comment;
        break;
      case 'profile':
        targetType = ReactionTargetType.profile;
        break;
      case 'message':
        targetType = ReactionTargetType.message;
        break;
      default:
        targetType = ReactionTargetType.post;
    }

    // Parse reaction type
    ReactionType reactionType = ReactionType.like;
    final reactionTypeStr =
        json['reaction_type']?.toString().toLowerCase() ??
        json['type']?.toString().toLowerCase() ??
        'like';
    switch (reactionTypeStr) {
      case 'like':
      case '👍':
        reactionType = ReactionType.like;
        break;
      case 'love':
      case '❤️':
        reactionType = ReactionType.love;
        break;
      case 'laugh':
      case 'haha':
      case 'funny':
      case '😂':
        reactionType = ReactionType.laugh;
        break;
      case 'wow':
      case 'amazing':
      case '😮':
        reactionType = ReactionType.wow;
        break;
      case 'sad':
      case '😢':
        reactionType = ReactionType.sad;
        break;
      case 'angry':
      case '😡':
        reactionType = ReactionType.angry;
        break;
      case 'celebrate':
      case 'party':
      case '🎉':
        reactionType = ReactionType.celebrate;
        break;
      case 'support':
      case 'care':
      case '🤗':
        reactionType = ReactionType.support;
        break;
      case 'fire':
      case '🔥':
        reactionType = ReactionType.fire;
        break;
      case 'trophy':
      case 'achievement':
      case '🏆':
        reactionType = ReactionType.trophy;
        break;
      default:
        reactionType = ReactionType.like;
    }

    // Parse user information from nested profiles data
    final userData = json['user'] ?? json['profiles'] ?? {};

    // Parse grouped reactions if available
    List<GroupedReaction> groupedReactions = [];
    if (json['grouped_reactions'] != null &&
        json['grouped_reactions'] is List) {
      groupedReactions = (json['grouped_reactions'] as List)
          .map((group) => GroupedReaction.fromJson(group))
          .toList();
    } else if (json['reaction_counts'] != null) {
      // Alternative format with counts
      final counts = json['reaction_counts'] as Map<String, dynamic>;
      groupedReactions = counts.entries.map((entry) {
        final type = _stringToReactionType(entry.key);
        final count = entry.value is int
            ? entry.value
            : int.tryParse(entry.value.toString()) ?? 0;
        return GroupedReaction(
          reactionType: type,
          count: count,
          users: [], // Users list would need separate API call
        );
      }).toList();
    }

    return ReactionModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      targetId:
          json['target_id'] ?? json['post_id'] ?? json['comment_id'] ?? '',
      targetType: targetType,
      reactionType: reactionType,
      createdAt: _parseDateTime(json['created_at']),
      userName:
          userData['full_name'] ??
          userData['display_name'] ??
          userData['username'] ??
          'Unknown User',
      userAvatar: userData['avatar_url'] ?? userData['profile_picture'] ?? '',
      userIsVerified:
          userData['verified'] == true || userData['is_verified'] == true,
      groupedReactions: groupedReactions,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'target_id': targetId,
      'target_type': _targetTypeToString(targetType),
      'reaction_type': _reactionTypeToString(reactionType),
      'created_at': createdAt.toIso8601String(),
    };

    if (metadata != null) {
      json['metadata'] = metadata;
    }

    return json;
  }

  /// Create JSON for adding new reaction
  Map<String, dynamic> toCreateJson() {
    return {
      'user_id': userId,
      'target_id': targetId,
      'target_type': _targetTypeToString(targetType),
      'reaction_type': _reactionTypeToString(reactionType),
    };
  }

  /// Create JSON for updating reaction type
  Map<String, dynamic> toUpdateJson() {
    return {'reaction_type': _reactionTypeToString(reactionType)};
  }

  /// Create a copy with updated fields
  ReactionModel copyWith({
    String? id,
    String? userId,
    String? targetId,
    ReactionTargetType? targetType,
    ReactionType? reactionType,
    DateTime? createdAt,
    String? userName,
    String? userAvatar,
    bool? userIsVerified,
    List<GroupedReaction>? groupedReactions,
    Map<String, dynamic>? metadata,
  }) {
    return ReactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      reactionType: reactionType ?? this.reactionType,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userIsVerified: userIsVerified ?? this.userIsVerified,
      groupedReactions: groupedReactions ?? this.groupedReactions,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get reaction emoji
  String get emoji => _reactionTypeToEmoji(reactionType);

  /// Get reaction display name
  String get displayName => _reactionTypeToDisplayName(reactionType);

  /// Get reaction type (alias for reactionType for compatibility)
  ReactionType get type => reactionType;

  /// Check if reaction is from current user
  bool isFromUser(String currentUserId) => userId == currentUserId;

  /// Get total reaction count for this target
  int get totalReactionCount {
    return groupedReactions.fold(0, (sum, group) => sum + group.count);
  }

  /// Get count for specific reaction type
  int getCountForType(ReactionType type) {
    try {
      return groupedReactions
          .firstWhere((group) => group.reactionType == type)
          .count;
    } catch (e) {
      return 0;
    }
  }

  /// Check if specific reaction type exists
  bool hasReactionType(ReactionType type) {
    return groupedReactions.any((group) => group.reactionType == type);
  }

  /// Get users who reacted with specific type
  List<ReactionUser> getUsersForType(ReactionType type) {
    try {
      return groupedReactions
          .firstWhere((group) => group.reactionType == type)
          .users;
    } catch (e) {
      return [];
    }
  }

  /// Get most popular reaction type
  ReactionType? get mostPopularReaction {
    if (groupedReactions.isEmpty) return null;

    final sorted = List<GroupedReaction>.from(groupedReactions)
      ..sort((a, b) => b.count.compareTo(a.count));

    return sorted.first.reactionType;
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

  static String _targetTypeToString(ReactionTargetType type) {
    switch (type) {
      case ReactionTargetType.post:
        return 'post';
      case ReactionTargetType.comment:
        return 'comment';
      case ReactionTargetType.profile:
        return 'profile';
      case ReactionTargetType.message:
        return 'message';
    }
  }

  static String _reactionTypeToString(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return 'like';
      case ReactionType.love:
        return 'love';
      case ReactionType.laugh:
        return 'laugh';
      case ReactionType.funny:
        return 'funny';
      case ReactionType.wow:
        return 'wow';
      case ReactionType.sad:
        return 'sad';
      case ReactionType.angry:
        return 'angry';
      case ReactionType.celebrate:
        return 'celebrate';
      case ReactionType.support:
        return 'support';
      case ReactionType.fire:
        return 'fire';
      case ReactionType.trophy:
        return 'trophy';
    }
  }

  static ReactionType _stringToReactionType(String str) {
    switch (str.toLowerCase()) {
      case 'like':
      case '👍':
        return ReactionType.like;
      case 'love':
      case '❤️':
        return ReactionType.love;
      case 'laugh':
      case 'haha':
      case '😂':
        return ReactionType.laugh;
      case 'wow':
      case 'amazing':
      case '😮':
        return ReactionType.wow;
      case 'sad':
      case '😢':
        return ReactionType.sad;
      case 'angry':
      case '😡':
        return ReactionType.angry;
      case 'celebrate':
      case 'party':
      case '🎉':
        return ReactionType.celebrate;
      case 'support':
      case 'care':
      case '🤗':
        return ReactionType.support;
      case 'fire':
      case '🔥':
        return ReactionType.fire;
      case 'trophy':
      case 'achievement':
      case '🏆':
        return ReactionType.trophy;
      default:
        return ReactionType.like;
    }
  }

  static String _reactionTypeToEmoji(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.laugh:
        return '😂';
      case ReactionType.funny:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😡';
      case ReactionType.celebrate:
        return '🎉';
      case ReactionType.support:
        return '🤗';
      case ReactionType.fire:
        return '🔥';
      case ReactionType.trophy:
        return '🏆';
    }
  }

  static String _reactionTypeToDisplayName(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return 'Like';
      case ReactionType.love:
        return 'Love';
      case ReactionType.laugh:
        return 'Laugh';
      case ReactionType.funny:
        return 'Funny';
      case ReactionType.wow:
        return 'Wow';
      case ReactionType.sad:
        return 'Sad';
      case ReactionType.angry:
        return 'Angry';
      case ReactionType.celebrate:
        return 'Celebrate';
      case ReactionType.support:
        return 'Support';
      case ReactionType.fire:
        return 'Fire';
      case ReactionType.trophy:
        return 'Trophy';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ReactionModel{id: $id, user: $userName, type: $reactionType, target: $targetId}';
  }
}

/// Model for grouped reactions (same type, multiple users)
class GroupedReaction {
  final ReactionType reactionType;
  final int count;
  final List<ReactionUser> users;

  const GroupedReaction({
    required this.reactionType,
    required this.count,
    required this.users,
  });

  factory GroupedReaction.fromJson(Map<String, dynamic> json) {
    // Parse reaction type
    ReactionType reactionType = ReactionType.like;
    final typeStr =
        json['reaction_type']?.toString().toLowerCase() ??
        json['type']?.toString().toLowerCase() ??
        'like';
    reactionType = ReactionModel._stringToReactionType(typeStr);

    // Parse users array
    List<ReactionUser> users = [];
    if (json['users'] != null && json['users'] is List) {
      users = (json['users'] as List)
          .map((user) => ReactionUser.fromJson(user))
          .toList();
    }

    return GroupedReaction(
      reactionType: reactionType,
      count: json['count'] ?? users.length,
      users: users,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reaction_type': ReactionModel._reactionTypeToString(reactionType),
      'count': count,
      'users': users.map((user) => user.toJson()).toList(),
    };
  }

  /// Get reaction emoji
  String get emoji => ReactionModel._reactionTypeToEmoji(reactionType);

  /// Get reaction display name
  String get displayName =>
      ReactionModel._reactionTypeToDisplayName(reactionType);

  /// Check if specific user is in this group
  bool containsUser(String userId) {
    return users.any((user) => user.id == userId);
  }

  /// Get user names for display (e.g., "John, Jane and 3 others")
  String getDisplayText({int maxNames = 2}) {
    if (users.isEmpty) return '';

    if (users.length <= maxNames) {
      if (users.length == 1) {
        return users.first.displayName;
      } else if (users.length == 2) {
        return '${users[0].displayName} and ${users[1].displayName}';
      } else {
        final names = users
            .take(maxNames - 1)
            .map((u) => u.displayName)
            .join(', ');
        return '$names and ${users.last.displayName}';
      }
    } else {
      final names = users.take(maxNames).map((u) => u.displayName).join(', ');
      final remaining = users.length - maxNames;
      return '$names and $remaining other${remaining > 1 ? 's' : ''}';
    }
  }
}

/// Model for users in reaction groups
class ReactionUser {
  final String id;
  final String name;
  final String avatar;
  final bool verified;

  const ReactionUser({
    required this.id,
    required this.name,
    this.avatar = '',
    this.verified = false,
  });

  // Getter for display name (uses name field for backward compatibility)
  String get displayName => name;

  factory ReactionUser.fromJson(Map<String, dynamic> json) {
    return ReactionUser(
      id: json['id'] ?? json['user_id'] ?? '',
      name:
          json['display_name'] ??
          json['name'] ??
          json['full_name'] ??
          json['username'] ??
          'Unknown User',
      avatar:
          json['avatar'] ?? json['avatar_url'] ?? json['profile_picture'] ?? '',
      verified: json['verified'] == true || json['is_verified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'avatar': avatar, 'verified': verified};
  }
}
