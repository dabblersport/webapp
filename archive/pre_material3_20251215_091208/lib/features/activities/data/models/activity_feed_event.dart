/// Model representing an activity event from the rpc_get_activity_feed RPC.
///
/// This model matches the exact contract returned by the Supabase RPC function.
/// The UI must not reconstruct or guess any of these fields - only read and render.
class ActivityFeedEvent {
  final String id;
  final String subjectType; // 'game', 'payment', 'reward', 'social', etc.
  final String subjectId;
  final String verb; // 'created', 'joined', 'left', 'payment_succeeded', etc.
  final String? status; // High-level status (null for MVP)
  final String timeBucket; // 'past', 'present', 'upcoming'
  final DateTime happenedAt; // Timestamp for ordering the timeline
  final DateTime? scheduledFor; // When the event is supposed to happen
  final int priority; // Relative priority for sorting (higher = more important)
  final Map<String, dynamic>? payload; // Free-form JSON with extra context

  ActivityFeedEvent({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.verb,
    this.status,
    required this.timeBucket,
    required this.happenedAt,
    this.scheduledFor,
    required this.priority,
    this.payload,
  });

  /// Creates an ActivityFeedEvent from a JSON map (as returned by Supabase RPC).
  factory ActivityFeedEvent.fromJson(Map<String, dynamic> json) {
    return ActivityFeedEvent(
      id: json['id'] as String,
      subjectType: json['subject_type'] as String,
      subjectId: json['subject_id'] as String,
      verb: json['verb'] as String,
      status: json['status'] as String?,
      timeBucket: json['time_bucket'] as String,
      happenedAt: DateTime.parse(json['happened_at'] as String),
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.parse(json['scheduled_for'] as String)
          : null,
      priority: json['priority'] as int,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  /// Converts the event to a JSON map (for debugging/testing).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_type': subjectType,
      'subject_id': subjectId,
      'verb': verb,
      'status': status,
      'time_bucket': timeBucket,
      'happened_at': happenedAt.toIso8601String(),
      'scheduled_for': scheduledFor?.toIso8601String(),
      'priority': priority,
      'payload': payload,
    };
  }

  @override
  String toString() {
    return 'ActivityFeedEvent(id: $id, subjectType: $subjectType, verb: $verb, timeBucket: $timeBucket)';
  }
}
