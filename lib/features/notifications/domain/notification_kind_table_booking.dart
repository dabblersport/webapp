/// KAN-1010 (W4-1, F-12): the client rows of the booking and payment kinds.
/// Part of the notification kind registry (notification_kinds.dart).
///
/// The server keeps these kinds inactive (templates only, not wired) and no
/// booking destination exists yet (BKG-08), so every row routes nowhere and
/// carries no action. Their cards show only with
/// `FeatureFlags.bookingNotifications` on (`NotificationKinds.isShown`); there
/// is no Booking chip, category or settings row either way.
library;

import 'notification_kind_types.dart';

const _ticket = ('ticket', NotifTone.info);
const _ticketAlert = ('ticket', NotifTone.accent);
const _card = ('card', NotifTone.info);
const _cardAlert = ('card', NotifTone.accent);
const _star = ('star', NotifTone.amber);

typedef _G = NotificationSettingsGroup;
typedef _R = NotificationRouteKind;

/// The booking (BKG-01…07) and payment (PAY-02…07) kinds.
const List<NotificationKindClient>
notificationBookingKindTable = <NotificationKindClient>[
  NotificationKindClient('booking.pending', _ticket, _R.none, _G.booking),
  NotificationKindClient('booking.confirmed', _ticket, _R.none, _G.booking),
  NotificationKindClient('booking.rejected', _ticketAlert, _R.none, _G.booking),
  NotificationKindClient(
    'booking.hold_expiring',
    _ticketAlert,
    _R.none,
    _G.booking,
  ),
  NotificationKindClient('booking.changed', _ticket, _R.none, _G.booking),
  NotificationKindClient(
    'booking.cancelled',
    _ticketAlert,
    _R.none,
    _G.booking,
  ),
  NotificationKindClient('venue.feedback_request', _star, _R.none, _G.booking),
  NotificationKindClient('payment.pending', _card, _R.none, _G.booking),
  NotificationKindClient('payment.succeeded', _card, _R.none, _G.booking),
  NotificationKindClient('payment.failed', _cardAlert, _R.none, _G.booking),
  NotificationKindClient('refund.processing', _card, _R.none, _G.booking),
  NotificationKindClient('refund.completed', _card, _R.none, _G.booking),
  NotificationKindClient('refund.failed', _cardAlert, _R.none, _G.booking),
];
