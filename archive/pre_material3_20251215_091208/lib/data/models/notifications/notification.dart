import 'package:equatable/equatable.dart';

/// Notification types supported by the system
enum NotificationType {
  gameInvite('game_invite'),
  gameUpdate('game_update'),
  bookingConfirmation('booking_confirmation'),
  bookingReminder('booking_reminder'),
  friendRequest('friend_request'),
  achievement('achievement'),
  loyaltyPoints('loyalty_points'),
  generalUpdate('general_update'),
  systemAlert('system_alert');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.generalUpdate,
    );
  }
}

/// Notification priority levels
enum NotificationPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  final String value;
  const NotificationPriority(this.value);

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationPriority.normal,
    );
  }
}

/// Domain entity for user notifications
class Notification extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String? imageUrl;
  final String? actionText;
  final String? actionRoute;
  final DateTime? readAt;

  const Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.priority = NotificationPriority.normal,
    required this.createdAt,
    this.isRead = false,
    this.data,
    this.imageUrl,
    this.actionText,
    this.actionRoute,
    this.readAt,
  });

  Notification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionText,
    String? actionRoute,
    DateTime? readAt,
  }) {
    return Notification(
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

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    message,
    type,
    priority,
    createdAt,
    isRead,
    data,
    imageUrl,
    actionText,
    actionRoute,
    readAt,
  ];
}
