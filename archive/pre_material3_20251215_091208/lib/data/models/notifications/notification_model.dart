import 'dart:convert';
import 'package:dabbler/data/models/notifications/notification.dart' as domain;

/// Data model for notifications
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String priority;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String? imageUrl;
  final String? actionText;
  final String? actionRoute;
  final DateTime? readAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.priority = 'normal',
    required this.createdAt,
    this.isRead = false,
    this.data,
    this.imageUrl,
    this.actionText,
    this.actionRoute,
    this.readAt,
  });

  /// Convert to domain entity
  domain.Notification toEntity() {
    return domain.Notification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: domain.NotificationType.fromString(type),
      priority: domain.NotificationPriority.fromString(priority),
      createdAt: createdAt,
      isRead: isRead,
      data: data,
      imageUrl: imageUrl,
      actionText: actionText,
      actionRoute: actionRoute,
      readAt: readAt,
    );
  }

  /// Convert from domain entity
  factory NotificationModel.fromEntity(domain.Notification entity) {
    return NotificationModel(
      id: entity.id,
      userId: entity.userId,
      title: entity.title,
      message: entity.message,
      type: entity.type.value,
      priority: entity.priority.value,
      createdAt: entity.createdAt,
      isRead: entity.isRead,
      data: entity.data,
      imageUrl: entity.imageUrl,
      actionText: entity.actionText,
      actionRoute: entity.actionRoute,
      readAt: entity.readAt,
    );
  }

  /// Convert from JSON (Supabase)
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String? ?? 'normal',
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      data: json['data'] != null
          ? (json['data'] is String
                ? jsonDecode(json['data'] as String) as Map<String, dynamic>
                : json['data'] as Map<String, dynamic>)
          : null,
      imageUrl: json['image_url'] as String?,
      actionText: json['action_text'] as String?,
      actionRoute: json['action_route'] as String?,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  /// Convert to JSON (Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'data': data != null ? jsonEncode(data) : null,
      'image_url': imageUrl,
      'action_text': actionText,
      'action_route': actionRoute,
      'read_at': readAt?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    String? priority,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionText,
    String? actionRoute,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      imageUrl: imageUrl ?? this.imageUrl,
      actionText: actionText ?? this.actionText,
      actionRoute: actionRoute ?? this.actionRoute,
      readAt: readAt ?? this.readAt,
    );
  }
}
