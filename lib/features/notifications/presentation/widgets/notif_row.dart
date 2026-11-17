// Extracted from notifications_screen_v2.dart by KAN-151 (pt.B of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// A notification is one DabblerNotificationRow. Leading is the actor's DS
// avatar when the payload names one, otherwise a tinted DS icon tile for the
// kind. The unread dot follows the time (Notifications.dc.html).

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/utils/notification_localizer.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show isFollowingProvider, profileIdByUserIdProvider, myProfileIdProvider;
import '../../data/models/notification_model.dart';
import 'notif_visual.dart';

/// Whether the "Follow back" CTA should show on a follow notification —
/// false when the recipient already follows the notification's sender.
/// KAN-101: the CTA must not render on an already-mutual follow.
final _followBackVisibleProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, actorUserId) async {
      final myProfileId = await ref.watch(myProfileIdProvider.future);
      if (myProfileId == null) return true;
      final targetProfileId = await ref.watch(
        profileIdByUserIdProvider(actorUserId).future,
      );
      if (targetProfileId == null) return true;
      final alreadyFollowing = await ref.watch(
        isFollowingProvider((
          currentProfileId: myProfileId,
          targetProfileId: targetProfileId,
        )).future,
      );
      return !alreadyFollowing;
    });

class NotificationRow extends ConsumerWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = _visualForKind(notification.kindKey);
    final unread = !notification.isRead;
    final actor = _actorFromPayload(notification.payload);
    final body = notification.body;
    final action = _quickAction(context, ref, notification);

    final Widget leading = actor != null
        ? DabblerAvatar(seed: actor, size: DabblerAvatarSize.sm)
        : DabblerIconTile.named(
            visual.icon,
            tone: visual.tone,
            size: DabblerSizing.touchTargetMin,
          );

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
      ),
      child: DabblerNotificationRow(
        leading: leading,
        actor: localizedNotificationTitle(context, notification),
        subject: (body != null && body.trim().isNotEmpty) ? body : null,
        time: _formatTime(context, notification.createdAt),
        unread: unread,
        actions: [
          if (action != null)
            DabblerNotificationAction(
              action.label,
              filled: action.filled,
              onPressed: onTap,
            ),
        ],
        onTap: onTap,
      ),
    );
  }

  /// Returns the quick-action pill for [n], or null when no action applies —
  /// or, for a follow notification, when the recipient already follows the
  /// sender back (KAN-101).
  ({String label, bool filled})? _quickAction(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) {
    // KAN-978: the kind's CTA comes from the registry.
    final cta = NotificationKinds.ctaOf(n.kindKey);
    if (cta == null) return null;

    if (cta.action == NotificationActionId.followBack) {
      final actorId = _actorUserId(n.payload);
      if (actorId != null) {
        final visible = ref.watch(_followBackVisibleProvider(actorId));
        if (visible.valueOrNull != true) return null;
      }
    }

    return (label: cta.label(AppLocalizations.of(context)), filled: cta.filled);
  }

  String? _actorUserId(Map<String, dynamic>? ctx) {
    if (ctx == null) return null;
    final direct = ctx['actor_user_id'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    for (final key in const ['follower_user_ids', 'actor_user_ids']) {
      final list = ctx[key];
      if (list is List && list.isNotEmpty) {
        final first = list.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
      }
    }
    return null;
  }

  String? _actorFromPayload(Map<String, dynamic>? p) {
    if (p == null) return null;
    for (final k in const ['actor_username', 'actor_name', 'actor_user_name']) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}

/// KAN-978: the kind's icon and tone come from the registry.
NotifVisual _visualForKind(String kindKey) {
  final (icon, tone) = NotificationKinds.visualOf(kindKey);
  return NotifVisual(icon, tone);
}

String _formatTime(BuildContext context, DateTime dateTime) {
  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inMinutes < 1) return l10n.time_just_now;
  if (diff.inHours < 1) return l10n.time_minutes_ago(diff.inMinutes);
  if (diff.inDays < 1) return l10n.time_hours_ago(diff.inHours);
  if (diff.inDays < 7) return l10n.time_days_ago(diff.inDays);
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}
