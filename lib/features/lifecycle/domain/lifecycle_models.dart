// KAN-1002 (W2-F5): the end-of-activity state the game and meetup details
// draw, read from the server (rpc_event_lifecycle_read). The client derives
// nothing from the schedule: the server decides scheduled / started /
// awaiting_confirmation / confirmed / auto_closed / did_not_happen.

import 'package:dabbler/core/utils/instant.dart';
import 'package:flutter/foundation.dart';

enum LifecyclePhase {
  scheduled,
  started,
  awaitingConfirmation,
  confirmed,
  timeEnded,
  didNotHappen,
}

LifecyclePhase? _phase(Object? s) => switch (s) {
  'scheduled' => LifecyclePhase.scheduled,
  'started' => LifecyclePhase.started,
  'awaiting_confirmation' => LifecyclePhase.awaitingConfirmation,
  'confirmed' => LifecyclePhase.confirmed,
  'auto_closed' => LifecyclePhase.timeEnded,
  'did_not_happen' => LifecyclePhase.didNotHappen,
  _ => null,
};

/// One rpc_event_lifecycle_read reply.
@immutable
class LifecycleView {
  const LifecycleView({
    required this.phase,
    required this.isOrganiser,
    required this.isCancelled,
    this.startAt,
    this.scheduledEnd,
    this.startedAt,
    this.endedAt,
    this.autoCloseAt,
  });

  /// Null when the server sent a state this build does not know.
  final LifecyclePhase? phase;
  final bool isOrganiser;
  final bool isCancelled;
  final DateTime? startAt;
  final DateTime? scheduledEnd;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Null until the server has sent the confirmation reminder.
  final DateTime? autoCloseAt;

  factory LifecycleView.fromJson(Map<String, dynamic> m) => LifecycleView(
    phase: _phase(m['state']),
    isOrganiser: m['is_organiser'] == true,
    isCancelled: m['is_cancelled'] == true,
    startAt: parseInstantLocal(m['start_at']),
    scheduledEnd: parseInstantLocal(m['scheduled_end_at'] ?? m['end_at']),
    startedAt: parseInstantLocal(m['actual_started_at']),
    endedAt: parseInstantLocal(m['actual_ended_at'] ?? m['closed_at']),
    autoCloseAt: parseInstantLocal(m['auto_close_at']),
  );
}
