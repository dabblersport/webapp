import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/notifications/notification_model.dart';

/// Exception for notification operations
class NotificationException implements Exception {
  final String message;
  const NotificationException(this.message);

  @override
  String toString() => 'NotificationException: $message';
}

/// Data source interface for notifications
abstract class NotificationsDataSource {
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<List<NotificationModel>> getUnreadNotifications(String userId);
  Future<List<NotificationModel>> getNotificationsByType(
    String userId,
    String type,
  );
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String notificationId);
  Future<void> deleteAllNotifications(String userId);
  Future<NotificationModel> createNotification(NotificationModel notification);
}

/// Supabase implementation of notifications data source
class SupabaseNotificationsDataSource implements NotificationsDataSource {
  final SupabaseClient client;

  SupabaseNotificationsDataSource(this.client);

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw NotificationException(
        'Failed to fetch notifications: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<NotificationModel>> getUnreadNotifications(String userId) async {
    try {
      final response = await client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw NotificationException(
        'Failed to fetch unread notifications: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<NotificationModel>> getNotificationsByType(
    String userId,
    String type,
  ) async {
    try {
      final response = await client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('type', type)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw NotificationException(
        'Failed to fetch notifications by type: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e) {
      throw NotificationException(
        'Failed to mark notification as read: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw NotificationException(
        'Failed to mark all notifications as read: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await client.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      throw NotificationException(
        'Failed to delete notification: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await client.from('notifications').delete().eq('user_id', userId);
    } catch (e) {
      throw NotificationException(
        'Failed to delete all notifications: ${e.toString()}',
      );
    }
  }

  @override
  Future<NotificationModel> createNotification(
    NotificationModel notification,
  ) async {
    try {
      final response = await client
          .from('notifications')
          .insert(notification.toJson())
          .select()
          .single();

      return NotificationModel.fromJson(response);
    } catch (e) {
      throw NotificationException(
        'Failed to create notification: ${e.toString()}',
      );
    }
  }
}
