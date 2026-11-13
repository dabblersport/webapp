import 'package:dabbler/core/utils/instant.dart';

/// Lightweight model for a meetup returned by the unified search RPC.
class MeetupSearchResult {
  final String id;

  /// The `public.events` parent id. [id] keeps meaning the meetups id; null
  /// when the payload carries no `event_id`.
  final String? eventId;
  final String title;
  final String? description;
  final DateTime? startAt;

  const MeetupSearchResult({
    required this.id,
    this.eventId,
    required this.title,
    this.description,
    this.startAt,
  });

  factory MeetupSearchResult.fromJson(Map<String, dynamic> json) {
    return MeetupSearchResult(
      id: (json['entity_id'] ?? json['id'] ?? '').toString(),
      eventId: json['event_id']?.toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['subtitle'] ?? json['description'])?.toString(),
      startAt: json['start_at'] != null
          ? parseInstantLocal(json['start_at'])
          : null,
    );
  }
}
