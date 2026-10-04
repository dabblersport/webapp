import 'package:json_annotation/json_annotation.dart';

/// Values of the `meetups.rsvp_policy` CHECK constraint the v1 client supports.
/// The database also allows `invite` and `link`; those are deferred and any
/// unknown/deferred value is read as [closed] so the UI never offers an RSVP.
enum RsvpPolicy {
  @JsonValue('open')
  open,
  @JsonValue('request')
  request,
  @JsonValue('closed')
  closed;

  String get dbValue => name;

  static RsvpPolicy fromDb(Object? v) => switch (v?.toString()) {
    'open' => RsvpPolicy.open,
    'request' => RsvpPolicy.request,
    _ => RsvpPolicy.closed,
  };
}

/// `meetup_rsvps.status` CHECK: going, interested, pending, declined, cancelled.
/// (`pending` is the stored value for a join request; `rpc_meetup_rsvp`
/// returns it for p_action = 'request'.) `meetup_attendees.status` (legacy,
/// read by rpc_meetup_attendees) only holds going/interested/declined.
enum RsvpStatus {
  @JsonValue('going')
  going,
  @JsonValue('interested')
  interested,
  @JsonValue('pending')
  pending,
  @JsonValue('declined')
  declined,
  @JsonValue('cancelled')
  cancelled,
  unknown;

  String get dbValue => name;

  static RsvpStatus? fromDbOrNull(Object? v) =>
      v == null ? null : fromDb(v);

  static RsvpStatus fromDb(Object? v) {
    final raw = v?.toString();
    for (final s in RsvpStatus.values) {
      if (s.name == raw && s != RsvpStatus.unknown) return s;
    }
    return RsvpStatus.unknown;
  }
}

/// `p_action` accepted by `rpc_meetup_rsvp` (accept_invite is deferred).
enum RsvpAction {
  going('going'),
  interested('interested'),
  cancel('cancel'),
  request('request');

  const RsvpAction(this.rpcValue);
  final String rpcValue;
}

/// `p_decision` accepted by `rpc_meetup_decide_request`.
enum MeetupDecision {
  approve('approve'),
  decline('decline');

  const MeetupDecision(this.rpcValue);
  final String rpcValue;
}

/// `cta` values returned by `can_current_user_rsvp_meetup`.
enum RsvpCta {
  rsvpGoing('rsvp_going'),
  request('request'),
  acceptInvite('accept_invite'),
  closed('closed'),
  cancelled('cancelled'),
  started('started'),
  already('already'),
  notAllowed('not_allowed'),
  notVisible('not_visible'),
  inviteOnly('invite_only'),
  linkRequired('link_required'),
  circleOnly('circle_only'),
  unknown('unknown');

  const RsvpCta(this.dbValue);
  final String dbValue;

  static RsvpCta fromDb(Object? v) {
    final raw = v?.toString();
    for (final c in RsvpCta.values) {
      if (c.dbValue == raw) return c;
    }
    return RsvpCta.unknown;
  }
}

/// `meetups` has no status column: lifecycle is `is_cancelled` + `start_at`.
enum MeetupLifecycle { upcoming, started, cancelled }
