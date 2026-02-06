import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/notifications/notification.dart';

/// Repository interface for notifications
abstract class NotificationsRepository {
  /// Get all notifications for a user
  Future<Either<Failure, List<Notification>>> getNotifications(String userId);

  /// Get unread notifications for a user
  Future<Either<Failure, List<Notification>>> getUnreadNotifications(
    String userId,
  );

  /// Get notifications by type
  Future<Either<Failure, List<Notification>>> getNotificationsByType(
    String userId,
    NotificationType type,
  );

  /// Mark a notification as read
  Future<Either<Failure, void>> markAsRead(String notificationId);

  /// Mark all notifications as read for a user
  Future<Either<Failure, void>> markAllAsRead(String userId);

  /// Delete a notification
  Future<Either<Failure, void>> deleteNotification(String notificationId);

  /// Delete all notifications for a user
  Future<Either<Failure, void>> deleteAllNotifications(String userId);

  /// Create a new notification
  Future<Either<Failure, Notification>> createNotification(
    Notification notification,
  );
}
