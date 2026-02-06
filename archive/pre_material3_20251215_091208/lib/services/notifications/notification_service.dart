import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_item.dart';

/// Service layer around the Supabase notification engine (RPCs + views).
///
/// This uses the already-initialized `Supabase.instance.client` and does not
/// perform any additional client setup.
class NotificationService {
  NotificationService(this._client);

  final SupabaseClient _client;

  /// Enqueue a new notification via the `enqueue_notification` RPC.
  ///
  /// Returns the notification id (if Supabase returns one) or `null`.
  Future<String?> enqueue({
    required String toUserId,
    required String kindKey,
    required String title,
    String? body,
    String? actionRoute,
    Map<String, dynamic>? context,
    String? priority, // 'low' | 'normal' | 'high' | 'urgent'
    List<String>? channels, // ['inapp','push',...]
    DateTime? scheduledAt,
  }) async {
    try {
      final payload = <String, dynamic>{
        'to_user_id': toUserId,
        'kind_key': kindKey,
        'title': title,
        if (body != null) 'body': body,
        if (actionRoute != null) 'action_route': actionRoute,
        if (context != null) 'context': jsonEncode(context),
        if (priority != null) 'priority': priority,
        if (channels != null) 'channels': channels,
        if (scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      };

      final result = await _client.rpc('enqueue_notification', params: payload);

      // Common patterns:
      // - RPC returns the id as a string
      // - RPC returns a row map with an `id` field
      if (result is String) return result;
      if (result is Map && result['id'] is String) {
        return result['id'] as String;
      }

      return null;
    } on PostgrestException catch (e) {
      throw Exception('Failed to enqueue notification: ${e.message}');
    } catch (e) {
      throw Exception('Failed to enqueue notification: $e');
    }
  }

  /// Realtime inbox stream based on `v_notifications`.
  ///
  /// Ordered with unread first, then newest first.
  Stream<List<NotificationItem>> watchInbox() async* {
    try {
      final stream = _client
          .from('v_notifications')
          .stream(primaryKey: const ['id'])
          .order('is_read', ascending: true)
          .order('created_at', ascending: false);

      await for (final rows in stream) {
        try {
          final items = rows
              .map((row) => NotificationItem.fromMap(row))
              .toList(growable: false);
          yield items;
        } catch (e) {
          // On mapping error, emit an empty list but keep the stream alive.
          yield const <NotificationItem>[];
        }
      }
    } on PostgrestException catch (e) {
      // Surface a terminal error to the listener.
      throw Exception('Failed to stream notifications: ${e.message}');
    } catch (e) {
      throw Exception('Failed to stream notifications: $e');
    }
  }

  /// Realtime unread count stream based on `v_unread_counts`.
  Stream<int> watchUnreadCount() async* {
    try {
      final stream = _client
          .from('v_unread_counts')
          .stream(primaryKey: const ['user_id']);

      await for (final rows in stream) {
        try {
          if (rows.isEmpty) {
            yield 0;
            continue;
          }

          final row = rows.first;
          final raw = row['unread_count'];

          // Supabase may return this as int or num.
          final count = raw is int
              ? raw
              : raw is num
              ? raw.toInt()
              : 0;

          yield count;
        } catch (e) {
          // Emit 0 on mapping error but keep the stream alive.
          yield 0;
        }
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to stream unread counts: ${e.message}');
    } catch (e) {
      throw Exception('Failed to stream unread counts: $e');
    }
  }

  /// Mark a single notification as read via `mark_notification_read` RPC.
  Future<void> markRead(String notificationId) async {
    try {
      await _client.rpc(
        'mark_notification_read',
        params: <String, dynamic>{'notification_id': notificationId},
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to mark notification as read: ${e.message}');
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications before [cutoff] as read via `mark_all_read_before` RPC.
  ///
  /// Returns the number of notifications affected.
  Future<int> markAllReadBefore(DateTime cutoff) async {
    try {
      final result = await _client.rpc(
        'mark_all_read_before',
        params: <String, dynamic>{'cutoff': cutoff.toUtc().toIso8601String()},
      );

      if (result is int) return result;
      if (result is Map && result['count'] is int) {
        return result['count'] as int;
      }
      return 0;
    } on PostgrestException catch (e) {
      throw Exception('Failed to mark notifications as read: ${e.message}');
    } catch (e) {
      throw Exception('Failed to mark notifications as read: $e');
    }
  }
}
