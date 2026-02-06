import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service to send push notifications to users via Edge Function
class NotificationSender {
  static final supabase = Supabase.instance.client;

  /// Send a push notification to a specific user
  static Future<bool> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
    List<String>? platforms, // Optional: ['android', 'iOS', etc.]
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
          if (platforms != null) 'platforms': platforms,
        },
      );

      if (response.status == 200) {
        debugPrint('✅ Notification sent to $userId');
        return true;
      } else {
        debugPrint('❌ Failed to send notification: ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      return false;
    }
  }

  /// Send game invitation notification
  static Future<void> notifyGameInvite({
    required String recipientUserId,
    required String inviterName,
    required String sportName,
    required String gameId,
  }) async {
    await sendToUser(
      userId: recipientUserId,
      title: 'Game Invitation',
      body: '$inviterName invited you to play $sportName',
      data: {'type': 'game_invite', 'game_id': gameId},
    );
  }

  /// Send friend request notification
  static Future<void> notifyFriendRequest({
    required String recipientUserId,
    required String requesterName,
    required String requestId,
  }) async {
    await sendToUser(
      userId: recipientUserId,
      title: 'Friend Request',
      body: '$requesterName sent you a friend request',
      data: {'type': 'friend_request', 'request_id': requestId},
    );
  }

  /// Send game canceled notification
  static Future<void> notifyGameCanceled({
    required String recipientUserId,
    required String sportName,
    required String gameId,
  }) async {
    await sendToUser(
      userId: recipientUserId,
      title: 'Game Canceled',
      body: 'Your $sportName game has been canceled',
      data: {'type': 'game_canceled', 'game_id': gameId},
    );
  }

  /// Send player joined notification (to organizer)
  static Future<void> notifyPlayerJoined({
    required String organizerId,
    required String playerName,
    required String sportName,
    required String gameId,
  }) async {
    await sendToUser(
      userId: organizerId,
      title: 'New Player Joined',
      body: '$playerName joined your $sportName game',
      data: {'type': 'player_joined', 'game_id': gameId},
    );
  }

  /// Send achievement unlocked notification
  static Future<void> notifyAchievement({
    required String userId,
    required String achievementName,
    required String achievementId,
  }) async {
    await sendToUser(
      userId: userId,
      title: '🏆 Achievement Unlocked!',
      body: achievementName,
      data: {'type': 'achievement', 'achievement_id': achievementId},
    );
  }

  /// Send check-in reminder
  static Future<void> notifyCheckInReminder({required String userId}) async {
    await sendToUser(
      userId: userId,
      title: '⏰ Check-In Reminder',
      body: 'Don\'t forget to check in today!',
      data: {'type': 'check_in_reminder'},
    );
  }
}
