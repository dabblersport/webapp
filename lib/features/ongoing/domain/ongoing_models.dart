// KAN-1008 (W3-F1): one row of rpc_my_ongoing_events, and the card state it
// maps to. The server decides the lifecycle state and the check-in state; the
// client only compares the schedule with the clock to tell "starting soon"
// from "scheduled time running" and to show the countdown.

import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/core/utils/instant.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:flutter/foundation.dart';

/// Check-in closes this long after the start (rpc_attendance_my closes_at).
const Duration ongoingCheckInCloses = NotificationTiming.checkInCloses;

enum OngoingKind { game, meetup }

/// The card's main line. Check-in is a separate line ([OngoingEvent.checkIn]).
enum OngoingStatus {
  /// Before the start: "Starts in 12 min".
  startingSoon,

  /// Past the start, not started by the organiser: "Scheduled time running".
  running,

  /// The organiser pressed Start: "Started 8:05 PM".
  started,

  /// Past the scheduled end, waiting for the organiser to confirm.
  timeEnded,

  /// Closed: the organiser confirmed the end.
  confirmed,

  /// Closed: the organiser marked it as did not happen.
  didNotHappen,

  /// Closed by the server after the confirm reminder: "Scheduled time ended".
  autoClosed,

  cancelled,
}

/// One rpc_my_ongoing_events row.
@immutable
class OngoingEvent {
  const OngoingEvent({
    required this.eventId,
    required this.kind,
    required this.title,
    required this.startAt,
    required this.state,
    required this.isCancelled,
    required this.isOrganiser,
    required this.checkIn,
    this.scheduledEnd,
    this.startedAt,
    this.autoCloseAt,
    this.previousStartAt,
    this.previousEndAt,
    this.scheduleRevision,
    this.sportKey,
    this.sportEmoji,
  });

  /// events.id, which is also games.id / meetups.id.
  final String eventId;
  final OngoingKind kind;
  final String title;
  final DateTime startAt;
  final DateTime? scheduledEnd;
  final DateTime? startedAt;
  final DateTime? autoCloseAt;

  /// The server's lifecycle state (scheduled, started, awaiting_confirmation,
  /// confirmed, auto_closed, did_not_happen).
  final String state;
  final bool isCancelled;
  final bool isOrganiser;

  /// rpc_attendance_my's state for the caller; the organiser is notEligible.
  final CheckInPhase checkIn;

  /// The start and end before the last schedule change; null when unchanged.
  final DateTime? previousStartAt;
  final DateTime? previousEndAt;
  final int? scheduleRevision;

  /// The event's sport, for the Home ring's emoji.
  final String? sportKey;
  final String? sportEmoji;

  bool get isClosed =>
      isCancelled ||
      state == 'confirmed' ||
      state == 'did_not_happen' ||
      state == 'auto_closed';

  /// The start moved (old → new) and the event is not over.
  bool get isStartChanged =>
      !isClosed && previousStartAt != null && previousStartAt != startAt;

  /// Only the end moved (old → new) and the event is not over.
  bool get isEndOnlyChanged =>
      !isClosed &&
      !isStartChanged &&
      previousEndAt != null &&
      scheduledEnd != null &&
      previousEndAt != scheduledEnd;

  /// The start or the end moved and the event is not over.
  bool get isChanged => isStartChanged || isEndOnlyChanged;

  /// The main line at [now].
  OngoingStatus statusAt(DateTime now) {
    if (isCancelled) return OngoingStatus.cancelled;
    switch (state) {
      case 'confirmed':
        return OngoingStatus.confirmed;
      case 'did_not_happen':
        return OngoingStatus.didNotHappen;
      case 'auto_closed':
        return OngoingStatus.autoClosed;
      case 'awaiting_confirmation':
        return OngoingStatus.timeEnded;
    }
    final end = scheduledEnd;
    if (end != null && !now.isBefore(end)) return OngoingStatus.timeEnded;
    if (state == 'started') return OngoingStatus.started;
    return now.isBefore(startAt)
        ? OngoingStatus.startingSoon
        : OngoingStatus.running;
  }

  /// Check in is offered: an eligible participant (never the organiser) while
  /// the server says the window is open and the event is not closed.
  bool get canCheckIn =>
      !isOrganiser && !isClosed && checkIn == CheckInPhase.open;

  bool get isCheckedIn =>
      !isOrganiser && !isCancelled && checkIn == CheckInPhase.checkedIn;

  /// The instants after which the server's answer can change, so the list is
  /// read again: the start, check-in close, the scheduled end and the
  /// auto-close.
  Iterable<DateTime> get boundaries sync* {
    if (isClosed) return;
    yield startAt;
    yield startAt.add(ongoingCheckInCloses);
    if (scheduledEnd != null) yield scheduledEnd!;
    if (autoCloseAt != null) yield autoCloseAt!;
  }

  static OngoingEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['event_id'];
    final start = parseInstantLocal(m['start_at']);
    if (id is! String || start == null) return null;
    final rev = m['schedule_revision'];
    return OngoingEvent(
      eventId: id,
      kind: m['kind'] == 'meetup' ? OngoingKind.meetup : OngoingKind.game,
      title: (m['title'] as String?) ?? '',
      startAt: start,
      scheduledEnd: parseInstantLocal(m['scheduled_end_at']),
      startedAt: parseInstantLocal(m['actual_started_at']),
      autoCloseAt: parseInstantLocal(m['auto_close_at']),
      state: (m['state'] as String?) ?? 'scheduled',
      isCancelled: m['is_cancelled'] == true,
      isOrganiser: m['is_organiser'] == true,
      checkIn: phaseFromServer(
        m['check_in_state'] as String?,
        checkedIn: false,
      ),
      previousStartAt: parseInstantLocal(m['previous_start_at']),
      previousEndAt: parseInstantLocal(m['previous_end_at']),
      scheduleRevision: rev is num ? rev.toInt() : null,
      sportKey: m['sport_key'] as String?,
      sportEmoji: m['sport_emoji'] as String?,
    );
  }
}

/// Ordering rule for overlapping activities (KAN-1008, PO ruling after PEER
/// review), at [now]:
///
/// 1. Active: the caller can act now or it is running — check-in open,
///    starting soon, started, scheduled time running.
/// 2. Awaiting confirmation: past the scheduled end, waiting for the
///    organiser (an overrun).
/// 3. Closed: confirmed, did not happen, auto-closed, cancelled.
///
/// Within each group, the earliest `start_at` first; ties by `event_id`.
/// The card shows the first; every other one is reachable from "+N more".
List<OngoingEvent> orderOngoing(Iterable<OngoingEvent> events, DateTime now) {
  int group(OngoingEvent e) {
    if (e.isClosed) return 2;
    return e.statusAt(now) == OngoingStatus.timeEnded ? 1 : 0;
  }

  final list = events.toList();
  list.sort((a, b) {
    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final byStart = a.startAt.compareTo(b.startAt);
    return byStart != 0 ? byStart : a.eventId.compareTo(b.eventId);
  });
  return list;
}
