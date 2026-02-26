import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/notification_model.dart';

/// Callback signature for new realtime notifications.
typedef OnNewNotification = void Function(AppNotification notification);

/// Handles Supabase Realtime channel subscription for INSERT events
/// on the `public.notifications` table, filtered by `to_user_id`.
///
/// Responsibilities:
/// - Subscribe / unsubscribe to a single channel per user.
/// - Prevent duplicate subscriptions.
/// - Surface new rows via [OnNewNotification] callback.
/// - Clean up resources on dispose.
class NotificationRealtimeService {
  NotificationRealtimeService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  RealtimeChannel? _channel;
  bool _isSubscribed = false;
  String? _subscribedUserId;

  /// Whether the service currently holds an active subscription.
  bool get isSubscribed => _isSubscribed;

  /// Begin listening for INSERT events on `public.notifications`
  /// where `to_user_id` equals [userId].
  ///
  /// If already subscribed for the same [userId], this is a no-op.
  /// If subscribed for a different user, the old subscription is removed first.
  void subscribe({
    required String userId,
    required OnNewNotification onNewNotification,
  }) {
    // Already listening for the same user – nothing to do.
    if (_isSubscribed && _subscribedUserId == userId && _channel != null) {
      dev.log(
        'NotificationRealtimeService: already subscribed for user $userId',
        name: 'notifications',
      );
      return;
    }

    // Tear down any existing channel first.
    if (_channel != null) {
      unsubscribe();
    }

    _subscribedUserId = userId;

    // Use a unique channel name to avoid conflicts with stale channel
    // references in the Supabase client after rapid unsubscribe/subscribe.
    final channelName =
        'notifications:$userId:${DateTime.now().microsecondsSinceEpoch}';

    _channel = _client.channel(channelName);

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user_id',
            value: userId,
          ),
          callback: (PostgresChangePayload payload) {
            try {
              final newRecord = payload.newRecord;
              if (newRecord.isEmpty) return;

              final model = AppNotification.fromJson(newRecord);
              onNewNotification(model);
            } catch (e, st) {
              dev.log(
                'NotificationRealtimeService: failed to parse payload – $e',
                name: 'notifications',
                error: e,
                stackTrace: st,
              );
            }
          },
        )
        .subscribe((status, [error]) {
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              _isSubscribed = true;
              dev.log(
                'NotificationRealtimeService: subscribed for user $userId',
                name: 'notifications',
              );
            case RealtimeSubscribeStatus.timedOut:
              _isSubscribed = false;
              dev.log(
                'NotificationRealtimeService: subscription timed out',
                name: 'notifications',
              );
            case RealtimeSubscribeStatus.channelError:
              _isSubscribed = false;
              dev.log(
                'NotificationRealtimeService: channel error – $error',
                name: 'notifications',
              );
            case RealtimeSubscribeStatus.closed:
              _isSubscribed = false;
              dev.log(
                'NotificationRealtimeService: channel closed',
                name: 'notifications',
              );
          }
        });
  }

  /// Remove the current channel subscription, if any.
  void unsubscribe() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
      _isSubscribed = false;
      _subscribedUserId = null;
      dev.log(
        'NotificationRealtimeService: unsubscribed',
        name: 'notifications',
      );
    }
  }

  /// Alias for [unsubscribe]. Call from widget/provider dispose methods.
  void dispose() => unsubscribe();
}
