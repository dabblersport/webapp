// Part of the notification kind registry (notification_kinds.dart): what the
// client knows per kind. The server facts (category, active, breaks_quiet,
// can_mute) and the templates are generated into notification_kind_titles.dart.
//
// The 35 live kinds keep exactly the icon, tone, route, CTA and settings group
// they had before KAN-978 (the old rules in notif_row.dart,
// notifications_screen_v2.dart and the settings lists). Their order here is the
// order of the settings toggles.

import 'notification_kind_table_epic.dart';
import 'notification_kind_types.dart';

const _gameAmber = ('game', NotifTone.amber);
const _bell = ('notification', NotifTone.brand);
const _people = ('people', NotifTone.brand);
const _userAdd = ('user-add', NotifTone.brand);
const _heart = ('heart', NotifTone.accent);
const _message = ('message', NotifTone.info);

typedef _G = NotificationSettingsGroup;
typedef _R = NotificationRouteKind;
typedef _A = NotificationActionId;

/// The 35 live kinds, in settings order.
const List<NotificationKindClient>
notificationLiveKindTable = <NotificationKindClient>[
  // ── Games (live) ─────────────────────────────────────────────────────────
  NotificationKindClient(
    'game.invited',
    _gameAmber,
    _R.game,
    _G.gameInvites,
    needsAction: true,
    // KAN-988 (GAM-01): "View invitation" opens it; Decline runs inline.
    ctas: [NotificationCta(_A.view, filled: true), NotificationCta(_A.decline)],
  ),
  NotificationKindClient(
    'game.join_request',
    _gameAmber,
    _R.gameJoinRequest,
    _G.gameInvites,
    needsAction: true,
    // KAN-988 (GAM-02): approve or decline from the row.
    ctas: [
      NotificationCta(_A.approve, filled: true),
      NotificationCta(_A.decline),
    ],
  ),
  NotificationKindClient(
    'game.join_accepted',
    _gameAmber,
    _R.game,
    _G.gameInvites,
  ),
  NotificationKindClient(
    'game.reminder',
    _gameAmber,
    _R.game,
    _G.gameReminders,
  ),
  // Old game.updated rows only ever meant a cancellation (KAN-973 assumption).
  NotificationKindClient(
    'game.updated',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
    aliasOf: 'game.cancelled',
  ),
  NotificationKindClient(
    'game.waitlist_promoted',
    _gameAmber,
    _R.game,
    _G.waitlist,
    // KAN-988 (GAM-07 / G-14): give the place up, no penalty.
    ctas: [NotificationCta(_A.cancelPlace)],
  ),
  NotificationKindClient(
    'game.player_joined',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  NotificationKindClient('game.removed', _gameAmber, _R.game, null),
  NotificationKindClient(
    'arena.payment_required',
    ('ticket', NotifTone.info),
    _R.arena,
    _G.booking,
    needsAction: true,
  ),
  // ── Social (live) ────────────────────────────────────────────────────────
  NotificationKindClient('social.post_liked', _heart, _R.post, _G.likes),
  NotificationKindClient('social.post_reacted', _bell, _R.none, _G.likes),
  NotificationKindClient('social.comment_liked', _heart, _R.comment, _G.likes),
  NotificationKindClient(
    'social.post_commented',
    _message,
    _R.post,
    _G.comments,
  ),
  NotificationKindClient(
    'social.mentioned_in_post',
    _message,
    _R.post,
    _G.mentions,
  ),
  NotificationKindClient(
    'social.mentioned_in_comment',
    _message,
    _R.comment,
    _G.mentions,
  ),
  NotificationKindClient(
    'social.followed',
    _userAdd,
    _R.actorProfile,
    _G.followers,
    ctas: [NotificationCta(_A.followBack)],
  ),
  // F-17: "friends" are followers; friend.* are the legacy names.
  NotificationKindClient(
    'friend.requested',
    _userAdd,
    _R.friendRequests,
    _G.friends,
    needsAction: true,
    ctas: [NotificationCta(_A.respond)],
    aliasOf: 'social.friend_request',
  ),
  NotificationKindClient(
    'friend.accepted',
    _userAdd,
    _R.friendAccepted,
    _G.friends,
    aliasOf: 'social.friend_accepted',
  ),
  NotificationKindClient(
    'social.friend_request',
    _bell,
    _R.none,
    null,
    needsAction: true,
  ),
  NotificationKindClient('social.friend_accepted', _bell, _R.none, null),
  NotificationKindClient(
    'squad.invited',
    _bell,
    _R.none,
    _G.squads,
    needsAction: true,
  ),
  NotificationKindClient(
    'social.circle_joined',
    _people,
    _R.actorProfile,
    null,
    ctas: [NotificationCta(_A.seeCircle)],
  ),
  // ── Meetups (live) ───────────────────────────────────────────────────────
  NotificationKindClient(
    'meetup.invited',
    _bell,
    _R.meetupGuest,
    _G.meetups,
    needsAction: true,
  ),
  NotificationKindClient(
    'meetup.player_joined',
    _bell,
    _R.meetupGuest,
    _G.meetups,
  ),
  NotificationKindClient(
    'meetup.rsvp_received',
    _bell,
    _R.meetupHost,
    _G.meetupRsvps,
  ),
  NotificationKindClient(
    'meetup.request_received',
    _bell,
    _R.meetupHost,
    _G.meetupRequests,
    needsAction: true,
    // KAN-988 (MTG-03): approve or decline from the row.
    ctas: [
      NotificationCta(_A.approve, filled: true),
      NotificationCta(_A.decline),
    ],
  ),
  NotificationKindClient(
    'meetup.request_approved',
    _bell,
    _R.meetupGuest,
    _G.meetupApproved,
  ),
  NotificationKindClient(
    'meetup.request_declined',
    _bell,
    _R.meetupGuest,
    _G.meetupDeclined,
  ),
  NotificationKindClient(
    'meetup.cancelled',
    _bell,
    _R.meetupGuest,
    _G.meetupCancelled,
  ),
  // ── Messages and system (live) ───────────────────────────────────────────
  NotificationKindClient('message.received', _bell, _R.none, _G.messages),
  NotificationKindClient(
    'reward.badge_awarded',
    ('cup', NotifTone.amber),
    _R.rewards,
    _G.system,
  ),
  NotificationKindClient(
    'system.announcement',
    ('warning-2', NotifTone.accent),
    _R.none,
    _G.system,
  ),
  NotificationKindClient('auth.welcome', _bell, _R.none, _G.system),
  NotificationKindClient(
    'moderation.report_submitted',
    _bell,
    _R.none,
    _G.system,
  ),
  NotificationKindClient('moderation.user_blocked', _bell, _R.none, _G.system),
];

/// Every kind the client knows: the live kinds, then the Epic's new ones.
const List<NotificationKindClient> notificationKindTable =
    <NotificationKindClient>[
      ...notificationLiveKindTable,
      ...notificationEpicKindTable,
    ];
