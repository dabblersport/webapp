// Extracted from notifications_screen_v2.dart by KAN-151 (pt.B of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/notifications/utils/notification_localizer.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show isFollowingProvider, profileIdByUserIdProvider, myProfileIdProvider;
import '../../data/models/notification_model.dart';
import 'notif_avatar_chip.dart';
import 'notif_visual.dart';

/// Whether the "Follow back" CTA should show on a follow notification —
/// false when the recipient already follows the notification's sender.
/// KAN-101: the CTA must not render on an already-mutual follow.
final _followBackVisibleProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, actorUserId) async {
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
    final cs = context.colorScheme;
    final visual = _visualForKind(notification.kindKey, context);
    final unread = !notification.isRead;
    final actor = _actorFromPayload(notification.payload);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: unread ? cs.primaryContainer.withValues(alpha: 0.18) : null,
          border: BorderDirectional(
            bottom: BorderSide(color: context.colorTokens.stroke, width: 1),
            start: BorderSide(
              color: unread ? cs.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          visual.color.withValues(alpha: 0.20),
                          visual.color.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: visual.color.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(visual.icon, color: visual.color, size: 20),
                  ),
                  if (actor != null)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: AvatarChip(name: actor),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizedNotificationTitle(context, notification),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: unread ? 1 : 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (notification.body != null &&
                      notification.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        _formatTime(context, notification.createdAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildQuickAction(context, ref, notification),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (unread)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: visual.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: visual.color.withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Returns the quick-action chip for [n], or an empty widget when no
  /// action applies — or, for a follow notification, when the recipient
  /// already follows the sender back (KAN-101).
  Widget _buildQuickAction(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) {
    final label = _actionLabelFor(context, n.kindKey);
    if (label == null) return const SizedBox.shrink();

    if (n.kindKey.startsWith('social.followed')) {
      final actorId = _actorUserId(n.payload);
      if (actorId == null) return _quickAction(context, label);
      final visible = ref.watch(_followBackVisibleProvider(actorId));
      if (visible.valueOrNull != true) return const SizedBox.shrink();
    }

    return _quickAction(context, label);
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

  Widget _quickAction(BuildContext context, String label) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final isPrimary = notification.kindKey.contains('invited') ||
        notification.kindKey.contains('reminder');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: isPrimary
            ? null
            : Border.all(
                color: cs.onSurface.withValues(alpha: 0.10),
                width: 1.5,
              ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isPrimary ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }

  String? _actionLabelFor(BuildContext context, String kindKey) {
    final l10n = AppLocalizations.of(context);
    if (kindKey.startsWith('friend.requested')) return l10n.notif_action_respond;
    if (kindKey.startsWith('social.followed')) return l10n.notif_action_follow_back;
    if (kindKey.startsWith('game.invited')) return l10n.notif_action_view;
    if (kindKey.startsWith('social.circle_joined')) return l10n.notif_action_see_circle;
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

NotifVisual _visualForKind(String kindKey, BuildContext context) {
  final cs = context.colorScheme;
  if (kindKey.startsWith('social.post_liked') ||
      kindKey.startsWith('social.comment_liked')) {
    return NotifVisual(Iconsax.heart_copy, cs.error);
  }
  if (kindKey.startsWith('social.post_commented') ||
      kindKey.startsWith('social.mentioned')) {
    return NotifVisual(Iconsax.message_copy, cs.tertiary);
  }
  if (kindKey.startsWith('social.followed') || kindKey.startsWith('friend')) {
    return NotifVisual(Iconsax.user_add_copy, cs.primary);
  }
  if (kindKey.startsWith('social.circle_joined')) {
    return NotifVisual(Iconsax.people_copy, cs.primary);
  }
  if (kindKey.startsWith('booking') || kindKey.startsWith('arena')) {
    return const NotifVisual(Iconsax.ticket_copy, DesignTokens.success);
  }
  if (kindKey.startsWith('game')) {
    return const NotifVisual(Iconsax.game_copy, DesignTokens.warning);
  }
  if (kindKey.startsWith('achievement') || kindKey.startsWith('reward')) {
    return const NotifVisual(Iconsax.cup_copy, DesignTokens.warning);
  }
  if (kindKey.startsWith('loyalty')) {
    return const NotifVisual(Iconsax.coin_copy, DesignTokens.warning);
  }
  if (kindKey.startsWith('system')) {
    return NotifVisual(Iconsax.warning_2_copy, cs.error);
  }
  return NotifVisual(Iconsax.notification_copy, cs.primary);
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
