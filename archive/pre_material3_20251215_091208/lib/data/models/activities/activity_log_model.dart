import 'package:dabbler/data/models/activities/activity_log.dart';

/// Activity log model for data layer
class ActivityLogModel extends ActivityLog {
  const ActivityLogModel({
    required super.id,
    required super.userId,
    required super.type,
    super.subType,
    required super.title,
    super.description,
    required super.status,
    super.targetId,
    super.targetType,
    super.targetUserId,
    super.targetUserName,
    super.targetUserAvatar,
    super.venue,
    super.location,
    super.amount,
    super.currency,
    super.points,
    super.count,
    required super.createdAt,
    super.updatedAt,
    super.scheduledDate,
    super.metadata,
    super.iconUrl,
    super.thumbnailUrl,
    super.actionRoute,
  });

  /// From JSON factory
  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: _parseActivityType(json['activity_type'] as String),
      subType: json['activity_subtype'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: _parseActivityStatus(json['status'] as String? ?? 'completed'),
      targetId: json['target_id'] as String?,
      targetType: json['target_type'] as String?,
      targetUserId: json['target_user_id'] as String?,
      targetUserName: json['target_user_name'] as String?,
      targetUserAvatar: json['target_user_avatar'] as String?,
      venue: json['venue'] as String?,
      location: json['location'] as String?,
      amount: json['amount'] != null
          ? (json['amount'] as num).toDouble()
          : null,
      currency: json['currency'] as String?,
      points: json['points'] as int?,
      count: json['count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      iconUrl: json['icon_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      actionRoute: json['action_route'] as String?,
    );
  }

  /// To JSON method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'activity_type': type.name,
      'activity_subtype': subType,
      'title': title,
      'description': description,
      'status': status.name,
      'target_id': targetId,
      'target_type': targetType,
      'target_user_id': targetUserId,
      'target_user_name': targetUserName,
      'target_user_avatar': targetUserAvatar,
      'venue': venue,
      'location': location,
      'amount': amount,
      'currency': currency,
      'points': points,
      'count': count,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'scheduled_date': scheduledDate?.toIso8601String(),
      'metadata': metadata,
      'icon_url': iconUrl,
      'thumbnail_url': thumbnailUrl,
      'action_route': actionRoute,
    };
  }

  /// Parse activity type from string
  static ActivityType _parseActivityType(String type) {
    try {
      return ActivityType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => ActivityType.other,
      );
    } catch (e) {
      return ActivityType.other;
    }
  }

  /// Parse activity status from string
  static ActivityStatus _parseActivityStatus(String status) {
    try {
      return ActivityStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => ActivityStatus.completed,
      );
    } catch (e) {
      return ActivityStatus.completed;
    }
  }

  /// To Entity conversion
  ActivityLog toEntity() {
    return ActivityLog(
      id: id,
      userId: userId,
      type: type,
      subType: subType,
      title: title,
      description: description,
      status: status,
      targetId: targetId,
      targetType: targetType,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      targetUserAvatar: targetUserAvatar,
      venue: venue,
      location: location,
      amount: amount,
      currency: currency,
      points: points,
      count: count,
      createdAt: createdAt,
      updatedAt: updatedAt,
      scheduledDate: scheduledDate,
      metadata: metadata,
      iconUrl: iconUrl,
      thumbnailUrl: thumbnailUrl,
      actionRoute: actionRoute,
    );
  }

  /// From Entity conversion
  factory ActivityLogModel.fromEntity(ActivityLog activity) {
    return ActivityLogModel(
      id: activity.id,
      userId: activity.userId,
      type: activity.type,
      subType: activity.subType,
      title: activity.title,
      description: activity.description,
      status: activity.status,
      targetId: activity.targetId,
      targetType: activity.targetType,
      targetUserId: activity.targetUserId,
      targetUserName: activity.targetUserName,
      targetUserAvatar: activity.targetUserAvatar,
      venue: activity.venue,
      location: activity.location,
      amount: activity.amount,
      currency: activity.currency,
      points: activity.points,
      count: activity.count,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
      scheduledDate: activity.scheduledDate,
      metadata: activity.metadata,
      iconUrl: activity.iconUrl,
      thumbnailUrl: activity.thumbnailUrl,
      actionRoute: activity.actionRoute,
    );
  }
}
