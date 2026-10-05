import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';

/// The RSVP call-to-action state of the detail screen, from the
/// `can_current_user_rsvp_meetup` cta and the caller's own status.
///
/// `already` is split by [myStatus]; a meetup with no room left reads `full`
/// whenever the RPC would otherwise offer to join or request.
DabblerRsvpCtaState rsvpStateFromEligibility({
  required RsvpCta cta,
  String? myStatus,
  int? capacity,
  int going = 0,
}) {
  final full = capacity != null && going >= capacity;
  switch (cta) {
    case RsvpCta.rsvpGoing:
      return full ? DabblerRsvpCtaState.full : DabblerRsvpCtaState.join;
    case RsvpCta.request:
      return full ? DabblerRsvpCtaState.full : DabblerRsvpCtaState.request;
    case RsvpCta.already:
      return switch (myStatus) {
        'interested' => DabblerRsvpCtaState.interested,
        'pending' => DabblerRsvpCtaState.pending,
        _ => DabblerRsvpCtaState.going,
      };
    case RsvpCta.closed:
      return DabblerRsvpCtaState.closed;
    case RsvpCta.cancelled:
      return DabblerRsvpCtaState.cancelled;
    case RsvpCta.started:
      return DabblerRsvpCtaState.started;
    case RsvpCta.notVisible:
      return DabblerRsvpCtaState.notVisible;
    case RsvpCta.notAllowed:
    case RsvpCta.acceptInvite:
    case RsvpCta.inviteOnly:
    case RsvpCta.linkRequired:
    case RsvpCta.circleOnly:
    case RsvpCta.unknown:
      return DabblerRsvpCtaState.notAllowed;
  }
}

/// The same state for a listing card, from the list row alone (no RPC per
/// card).
DabblerRsvpCtaState rsvpStateFromListItem(MeetupListItem m, DateTime now) {
  switch (m.lifecycle(now)) {
    case MeetupLifecycle.cancelled:
      return DabblerRsvpCtaState.cancelled;
    case MeetupLifecycle.started:
      return DabblerRsvpCtaState.started;
    case MeetupLifecycle.upcoming:
      break;
  }
  switch (m.myRsvpStatus) {
    case 'going':
      return DabblerRsvpCtaState.going;
    case 'interested':
      return DabblerRsvpCtaState.interested;
    case 'pending':
      return DabblerRsvpCtaState.pending;
  }
  if (m.isFull) return DabblerRsvpCtaState.full;
  return switch (m.rsvpPolicy) {
    RsvpPolicy.open => DabblerRsvpCtaState.join,
    RsvpPolicy.request => DabblerRsvpCtaState.request,
    RsvpPolicy.closed => DabblerRsvpCtaState.closed,
  };
}

/// The words for [state].
String rsvpLabel(AppLocalizations l, DabblerRsvpCtaState state) =>
    switch (state) {
      DabblerRsvpCtaState.join => l.meetups_join,
      DabblerRsvpCtaState.request => l.meetups_request,
      DabblerRsvpCtaState.going => l.meetups_cta_going,
      DabblerRsvpCtaState.interested => l.meetups_cta_interested,
      DabblerRsvpCtaState.pending => l.listing_request_sent,
      DabblerRsvpCtaState.full => l.meetups_cta_full,
      DabblerRsvpCtaState.closed => l.meetups_cta_closed,
      DabblerRsvpCtaState.cancelled => l.meetups_cta_cancelled,
      DabblerRsvpCtaState.started => l.meetups_cta_started,
      DabblerRsvpCtaState.notVisible => l.meetups_cta_unavailable,
      DabblerRsvpCtaState.notAllowed => l.meetups_cta_not_allowed,
    };

/// The RSVP action a press on [state] runs, or null when the press opens the
/// sheet, switches profile or does nothing.
RsvpAction? rsvpActionFor(DabblerRsvpCtaState state) => switch (state) {
  DabblerRsvpCtaState.join => RsvpAction.going,
  DabblerRsvpCtaState.request => RsvpAction.request,
  DabblerRsvpCtaState.full => RsvpAction.interested,
  _ => null,
};
