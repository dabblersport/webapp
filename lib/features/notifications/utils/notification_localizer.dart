import 'package:flutter/widgets.dart';

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Returns the locale-appropriate title for a notification.
///
/// Builds the headline from `kindKey` + `payload.actor_*` so the line
/// follows the app locale regardless of what the server stored in
/// `notification.title`. Falls back to the snapshot `notification.title`
/// for any kindKey not explicitly templated here.
String localizedNotificationTitle(
  BuildContext context,
  AppNotification notification,
) {
  final l10n = AppLocalizations.of(context);
  final actor = _actorFromPayload(notification.payload);
  final kind = notification.kindKey;

  String pickActor(String withActor, String anon) =>
      (actor != null && actor.isNotEmpty) ? withActor : anon;

  switch (kind) {
    case 'friend.requested':
      return pickActor(
        l10n.notif_kind_friend_requested(actor ?? ''),
        l10n.notif_kind_friend_requested_anon,
      );
    case 'friend.accepted':
      return pickActor(
        l10n.notif_kind_friend_accepted(actor ?? ''),
        l10n.notif_kind_friend_accepted_anon,
      );
    case 'social.followed':
      return pickActor(
        l10n.notif_kind_social_followed(actor ?? ''),
        l10n.notif_kind_social_followed_anon,
      );
    case 'social.circle_joined':
      return pickActor(
        l10n.notif_kind_social_circle_joined(actor ?? ''),
        l10n.notif_kind_social_circle_joined_anon,
      );
    case 'social.post_liked':
      return pickActor(
        l10n.notif_kind_social_post_liked(actor ?? ''),
        l10n.notif_kind_social_post_liked_anon,
      );
    case 'social.post_commented':
      return pickActor(
        l10n.notif_kind_social_post_commented(actor ?? ''),
        l10n.notif_kind_social_post_commented_anon,
      );
    case 'social.comment_liked':
      return pickActor(
        l10n.notif_kind_social_comment_liked(actor ?? ''),
        l10n.notif_kind_social_comment_liked_anon,
      );
    case 'social.mentioned':
      return pickActor(
        l10n.notif_kind_social_mentioned(actor ?? ''),
        l10n.notif_kind_social_mentioned_anon,
      );
    case 'game.invited':
      return pickActor(
        l10n.notif_kind_game_invited(actor ?? ''),
        l10n.notif_kind_game_invited_anon,
      );
    case 'game.updated':
      return l10n.notif_kind_game_updated;
    case 'game.join_request':
      return pickActor(
        l10n.notif_kind_game_join_request(actor ?? ''),
        l10n.notif_kind_game_join_request_anon,
      );
    case 'game.waitlist_promoted':
      return l10n.notif_kind_game_waitlist_promoted;
    case 'game.reminder':
      return l10n.notif_kind_game_reminder;
    case 'arena.payment_required':
      return l10n.notif_kind_arena_payment_required;
    case 'reward.badge_awarded':
      return l10n.notif_kind_reward_badge_awarded;
  }
  if (kind.startsWith('achievement')) {
    return l10n.notif_kind_achievement_earned;
  }
  return notification.title;
}

/// Resolves the actor display name from the payload using common keys.
String? _actorFromPayload(Map<String, dynamic>? p) {
  if (p == null) return null;
  for (final k in const [
    'actor_display_name',
    'actor_name',
    'actor_username',
    'actor_user_name',
  ]) {
    final v = p[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}
