// Part of the notification kind registry (notification_kinds.dart): the types
// a kind is described with.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// The icon tile tone of a kind (a design-system tone).
typedef NotifTone = DabblerIconTileTone;

/// `notification_kinds.category` (KAN-974).
enum NotificationCategory {
  social,
  messages,
  games,
  meetups,
  activities,
  system,
  security,
  booking;

  static NotificationCategory? parse(String? raw) {
    for (final c in values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}

/// The Notification Center chips (W1-F3). [all], [unread] and [needsAction]
/// cut across kinds; every kind belongs to exactly one of the others.
enum NotificationChip {
  all,
  unread,
  needsAction,
  social,
  messages,
  games,
  meetups,
  system,
}

/// The settings row a kind is toggled with (the settings screen and the
/// Notifications prefs sheet).
enum NotificationSettingsGroup {
  gameInvites,
  gameReminders,
  gameUpdates,
  waitlist,
  booking,
  likes,
  comments,
  mentions,
  followers,
  friends,
  squads,
  meetups,
  meetupRsvps,
  meetupRequests,
  meetupApproved,
  meetupDeclined,
  meetupCancelled,
  messages,
  activities,
  system,
  security,
}

/// What a kind's tap opens; the builder lives in the registry.
enum NotificationRouteKind {
  none,
  post,
  comment,
  actorProfile,
  friendRequests,
  friendAccepted,
  game,
  gameJoinRequest,
  arena,
  rewards,
  meetupGuest,
  meetupHost,
  activity,
}

/// A row action. The first four are the live CTAs (they open the row); the
/// rest are wired by W1-F2.
enum NotificationActionId {
  respond,
  followBack,
  view,
  seeCircle,
  accept,
  approve,
  reject,
  going,
  notGoing,
  checkIn,
  requestReview,
  keepDecision,
  confirmEnd,
  enterScore,
  rate,
  thisWasMe,
  notMe;

  String label(AppLocalizations l) => switch (this) {
    respond => l.notif_action_respond,
    followBack => l.notif_action_follow_back,
    view => l.notif_action_view,
    seeCircle => l.notif_action_see_circle,
    accept => l.notif_action_accept,
    approve => l.notif_action_approve,
    reject => l.notif_action_reject,
    going => l.notif_action_going,
    notGoing => l.notif_action_not_going,
    checkIn => l.notif_action_check_in,
    requestReview => l.notif_action_request_review,
    keepDecision => l.notif_action_keep_decision,
    confirmEnd => l.notif_action_confirm_end,
    enterScore => l.notif_action_enter_score,
    rate => l.notif_action_rate,
    thisWasMe => l.notif_action_this_was_me,
    notMe => l.notif_action_not_me,
  };
}

/// One CTA of a kind; [filled] is the primary (filled) pill.
@immutable
class NotificationCta {
  const NotificationCta(this.action, {this.filled = false});

  final NotificationActionId action;
  final bool filled;

  String label(AppLocalizations l) => action.label(l);
}

/// What the client knows about one kind (the table row).
@immutable
class NotificationKindClient {
  const NotificationKindClient(
    this.key,
    this.visual,
    this.route,
    this.settingsGroup, {
    this.needsAction = false,
    this.ctas = const <NotificationCta>[],
    this.aliasOf,
  });

  final String key;

  /// The icon (a design-system icon name) and the tile tone.
  final (String, NotifTone) visual;
  final NotificationRouteKind route;
  final NotificationSettingsGroup? settingsGroup;
  final bool needsAction;
  final List<NotificationCta> ctas;

  /// The canonical kind a legacy key stands for (`friend.*`, `game.updated`).
  final String? aliasOf;
}
