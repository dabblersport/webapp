// Part of the notification kind registry (notification_kinds.dart): the new
// kinds of the Notification Center Epic (KAN-973), all inactive until their
// producer ticket ships. Same shape as notification_kind_table.dart.

import 'notification_kind_types.dart';

const _gameAmber = ('game', NotifTone.amber);
const _people = ('people', NotifTone.brand);
const _message = ('message', NotifTone.info);
const _calendar = ('calendar', NotifTone.info);
const _shield = ('security', NotifTone.accent);

typedef _G = NotificationSettingsGroup;
typedef _R = NotificationRouteKind;
typedef _A = NotificationActionId;

/// The Epic's new kinds, in settings order.
const List<NotificationKindClient>
notificationEpicKindTable = <NotificationKindClient>[
  // Membership (W1-B4)
  NotificationKindClient(
    'game.join_declined',
    _gameAmber,
    _R.game,
    _G.gameInvites,
  ),
  NotificationKindClient(
    'game.invite_accepted',
    _gameAmber,
    _R.game,
    _G.gameInvites,
  ),
  NotificationKindClient(
    'game.invite_declined',
    _gameAmber,
    _R.game,
    _G.gameInvites,
  ),
  NotificationKindClient(
    'game.invite_withdrawn',
    _gameAmber,
    _R.game,
    _G.gameInvites,
  ),
  NotificationKindClient(
    'game.invite_expired',
    _gameAmber,
    _R.game,
    _G.gameInvites,
  ),
  NotificationKindClient(
    'game.player_left',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  NotificationKindClient('game.full', _gameAmber, _R.game, _G.gameUpdates),
  NotificationKindClient(
    'game.waitlist_joined',
    _gameAmber,
    _R.game,
    _G.waitlist,
  ),
  NotificationKindClient(
    'game.waitlist_position_changed',
    _gameAmber,
    _R.game,
    _G.waitlist,
  ),
  NotificationKindClient('meetup.removed', _people, _R.meetupGuest, _G.meetups),
  NotificationKindClient(
    'meetup.player_left',
    _people,
    _R.meetupHost,
    _G.meetupRsvps,
  ),
  NotificationKindClient(
    'meetup.rsvp_interested',
    _people,
    _R.meetupHost,
    _G.meetupRsvps,
  ),
  // KAN-1013: someone wants a place in the organiser's full meetup; in-app
  // only, grouped ("See all N people"), opens the meetup, no actions.
  NotificationKindClient(
    'meetup.wants_to_join_full',
    _people,
    _R.meetupHost,
    _G.meetupRequests,
  ),
  // Event changes and cancel (W1-B3)
  NotificationKindClient('game.cancelled', _gameAmber, _R.game, _G.gameUpdates),
  NotificationKindClient(
    'game.time_changed',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  NotificationKindClient(
    'game.venue_changed',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  NotificationKindClient(
    'game.details_changed',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  NotificationKindClient(
    'game.occurrence_cancelled',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  NotificationKindClient(
    'game.series_changed',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  // KAN-1015: the whole series was cancelled (breaks quiet hours, like every
  // cancel); its target opens as "This was cancelled".
  NotificationKindClient(
    'game.series_cancelled',
    _gameAmber,
    _R.game,
    _G.gameUpdates,
  ),
  NotificationKindClient(
    'meetup.time_changed',
    _people,
    _R.meetupGuest,
    _G.meetups,
  ),
  NotificationKindClient(
    'meetup.venue_changed',
    _people,
    _R.meetupGuest,
    _G.meetups,
  ),
  NotificationKindClient(
    'meetup.details_changed',
    _people,
    _R.meetupGuest,
    _G.meetups,
  ),
  NotificationKindClient(
    'meetup.occurrence_cancelled',
    _people,
    _R.meetupGuest,
    _G.meetupCancelled,
  ),
  NotificationKindClient(
    'meetup.series_changed',
    _people,
    _R.meetupGuest,
    _G.meetups,
  ),
  // Reminders (W1-B5)
  NotificationKindClient(
    'meetup.reminder',
    _people,
    _R.meetupGuest,
    _G.gameReminders,
  ),
  NotificationKindClient(
    'meetup.confirm_attendance',
    _people,
    _R.meetupGuest,
    _G.gameReminders,
    needsAction: true,
    ctas: [
      NotificationCta(_A.going, filled: true),
      NotificationCta(_A.notGoing),
    ],
  ),
  // Attendance (W2-B1)
  NotificationKindClient(
    'activity.checkin_open',
    _calendar,
    _R.checkIn,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.checkIn, filled: true)],
  ),
  NotificationKindClient(
    'activity.checkin_closing',
    _calendar,
    _R.checkIn,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.checkIn, filled: true)],
  ),
  NotificationKindClient(
    'activity.checked_in',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.attendance_corrected',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.no_show_pending',
    _calendar,
    _R.noShow,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.requestReview)],
  ),
  NotificationKindClient(
    'activity.review_requested',
    _calendar,
    _R.attendanceList,
    _G.activities,
    needsAction: true,
    ctas: [
      NotificationCta(_A.accept, filled: true),
      NotificationCta(_A.keepDecision),
    ],
  ),
  NotificationKindClient(
    'activity.review_accepted',
    _calendar,
    _R.noShow,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.review_kept',
    _calendar,
    _R.noShow,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.no_show_confirmed',
    _calendar,
    _R.noShow,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.showup_rate_updated',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  // Lifecycle (W2-B2)
  NotificationKindClient(
    'activity.confirm_end',
    _calendar,
    _R.activity,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.confirmEnd, filled: true)],
  ),
  NotificationKindClient(
    'activity.confirm_end_reminder',
    _calendar,
    _R.activity,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.confirmEnd, filled: true)],
  ),
  NotificationKindClient(
    'activity.auto_closed',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.ended',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  // Results (W2-B3) and ratings (W2-B4)
  NotificationKindClient(
    'activity.post_activity',
    _calendar,
    _R.activity,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.enterScore, filled: true)],
  ),
  NotificationKindClient(
    'activity.result_ready',
    _calendar,
    _R.activity,
    _G.activities,
    needsAction: true,
    ctas: [
      NotificationCta(_A.approve, filled: true),
      NotificationCta(_A.reject),
    ],
  ),
  NotificationKindClient(
    'activity.result_enter_final',
    _calendar,
    _R.activity,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.enterScore, filled: true)],
  ),
  NotificationKindClient(
    'activity.result_confirmed',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.result_corrected',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.result_closed',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  NotificationKindClient(
    'activity.rating_reminder',
    _calendar,
    _R.activity,
    _G.activities,
    needsAction: true,
    ctas: [NotificationCta(_A.rate)],
  ),
  NotificationKindClient(
    'activity.summary',
    _calendar,
    _R.activity,
    _G.activities,
  ),
  // Security notices (W1-B7): always on; the route lands with W1-B7.
  NotificationKindClient(
    'security.new_signin',
    _shield,
    _R.none,
    _G.security,
    needsAction: true,
    ctas: [
      NotificationCta(_A.thisWasMe),
      NotificationCta(_A.notMe, filled: true),
    ],
  ),
  NotificationKindClient(
    'security.password_changed',
    _shield,
    _R.none,
    _G.security,
  ),
  NotificationKindClient(
    'security.email_changed',
    _shield,
    _R.none,
    _G.security,
  ),
  // Replies and reposts
  NotificationKindClient(
    'social.comment_replied',
    _message,
    _R.comment,
    _G.comments,
  ),
  NotificationKindClient(
    'social.post_reposted',
    ('refresh', NotifTone.brand),
    _R.post,
    _G.likes,
  ),
];
