import 'package:equatable/equatable.dart';

/// Activity type categories for comprehensive audit logging
enum ActivityType {
  // Core activities
  game,
  booking,

  // Social activities
  post,
  comment,
  like,
  share,
  follow,

  // Team & Community
  team,
  challenge,
  group,
  event,

  // Financial
  payment,
  refund,
  loyaltyPoints,

  // Achievements
  achievement,
  badge,
  reward,

  // Profile & Settings
  profileUpdate,
  settingsChange,

  // Communication
  message,
  friendRequest,

  // Venue & Location
  venueReview,
  checkIn,

  // Game specific
  gameInvite,
  gameJoin,
  gameLeave,
  gameComplete,
  gameCancel,

  // Booking specific
  bookingConfirm,
  bookingCancel,
  bookingModify,

  // Misc
  other,
}

/// Activity status for tracking completion state
enum ActivityStatus { pending, completed, cancelled, failed, inProgress }

/// Comprehensive activity log entity for audit trail
class ActivityLog extends Equatable {
  final String id;
  final String userId;
  final ActivityType type;
  final String?
  subType; // More specific categorization (e.g., 'like', 'comment')
  final String title;
  final String? description;
  final ActivityStatus status;

  // Target references
  final String?
  targetId; // Reference to related entity (game_id, post_id, etc.)
  final String? targetType; // Type of target ('game', 'post', 'user', etc.)
  final String? targetUserId; // User who is target of action
  final String? targetUserName;
  final String? targetUserAvatar;

  // Location/Venue data
  final String? venue;
  final String? location;

  // Financial data
  final double? amount;
  final String? currency;

  // Engagement metrics
  final int? points; // Loyalty points earned/spent
  final int? count; // Generic count (likes, comments, etc.)

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? scheduledDate; // For future events

  // Additional metadata
  final Map<String, dynamic>? metadata;

  // Display helpers
  final String? iconUrl;
  final String? thumbnailUrl;
  final String? actionRoute; // Deep link to related screen

  const ActivityLog({
    required this.id,
    required this.userId,
    required this.type,
    this.subType,
    required this.title,
    this.description,
    required this.status,
    this.targetId,
    this.targetType,
    this.targetUserId,
    this.targetUserName,
    this.targetUserAvatar,
    this.venue,
    this.location,
    this.amount,
    this.currency,
    this.points,
    this.count,
    required this.createdAt,
    this.updatedAt,
    this.scheduledDate,
    this.metadata,
    this.iconUrl,
    this.thumbnailUrl,
    this.actionRoute,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    subType,
    title,
    description,
    status,
    targetId,
    targetType,
    targetUserId,
    targetUserName,
    targetUserAvatar,
    venue,
    location,
    amount,
    currency,
    points,
    count,
    createdAt,
    updatedAt,
    scheduledDate,
    metadata,
    iconUrl,
    thumbnailUrl,
    actionRoute,
  ];

  /// Get category for filtering
  String get category {
    switch (type) {
      case ActivityType.game:
      case ActivityType.gameInvite:
      case ActivityType.gameJoin:
      case ActivityType.gameLeave:
      case ActivityType.gameComplete:
      case ActivityType.gameCancel:
        return 'Games';

      case ActivityType.booking:
      case ActivityType.bookingConfirm:
      case ActivityType.bookingCancel:
      case ActivityType.bookingModify:
        return 'Bookings';

      case ActivityType.team:
        return 'Teams';

      case ActivityType.challenge:
        return 'Challenges';

      case ActivityType.payment:
      case ActivityType.refund:
        return 'Payments';

      case ActivityType.post:
      case ActivityType.comment:
      case ActivityType.like:
      case ActivityType.share:
      case ActivityType.follow:
      case ActivityType.message:
      case ActivityType.friendRequest:
        return 'Community';

      case ActivityType.group:
        return 'Groups';

      case ActivityType.event:
        return 'Events';

      case ActivityType.achievement:
      case ActivityType.badge:
      case ActivityType.reward:
      case ActivityType.loyaltyPoints:
        return 'Rewards';

      default:
        return 'Other';
    }
  }

  /// Check if activity is from today
  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  /// Check if activity is from yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return createdAt.year == yesterday.year &&
        createdAt.month == yesterday.month &&
        createdAt.day == yesterday.day;
  }

  /// Check if activity is from this week
  bool get isThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return createdAt.isAfter(weekStart);
  }

  /// Check if activity is from this month
  bool get isThisMonth {
    final now = DateTime.now();
    return createdAt.year == now.year && createdAt.month == now.month;
  }

  /// Get formatted date for display
  String get formattedDate {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    if (isThisWeek) return 'This Week';
    if (isThisMonth) return 'This Month';
    return 'Older';
  }

  /// Copy with method for immutability
  ActivityLog copyWith({
    String? id,
    String? userId,
    ActivityType? type,
    String? subType,
    String? title,
    String? description,
    ActivityStatus? status,
    String? targetId,
    String? targetType,
    String? targetUserId,
    String? targetUserName,
    String? targetUserAvatar,
    String? venue,
    String? location,
    double? amount,
    String? currency,
    int? points,
    int? count,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? scheduledDate,
    Map<String, dynamic>? metadata,
    String? iconUrl,
    String? thumbnailUrl,
    String? actionRoute,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      subType: subType ?? this.subType,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      targetUserAvatar: targetUserAvatar ?? this.targetUserAvatar,
      venue: venue ?? this.venue,
      location: location ?? this.location,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      points: points ?? this.points,
      count: count ?? this.count,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      metadata: metadata ?? this.metadata,
      iconUrl: iconUrl ?? this.iconUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }
}
