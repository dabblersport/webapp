import 'package:meta/meta.dart';

@immutable
class SportProfileEvent {
  const SportProfileEvent({
    required this.id,
    required this.profileId,
    required this.sportKey,
    required this.eventType,
    this.eventData = const <String, dynamic>{},
    required this.createdAt,
  });

  factory SportProfileEvent.fromJson(Map<String, dynamic> json) {
    return SportProfileEvent(
      id: json['id'] as String? ?? json['event_id'] as String? ?? '',
      profileId:
          json['profile_id'] as String? ?? json['profileId'] as String? ?? '',
      sportKey:
          json['sport_key'] as String? ?? json['sportKey'] as String? ?? '',
      eventType:
          json['event_type'] as String? ?? json['eventType'] as String? ?? '',
      eventData: _readMap(json['event_data'] ?? json['eventData']),
      createdAt:
          _readDate(json['created_at'] ?? json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String profileId;
  final String sportKey;
  final String eventType;
  final Map<String, dynamic> eventData;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'profile_id': profileId,
      'sport_key': sportKey,
      'event_type': eventType,
      'event_data': eventData,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
  return const <String, dynamic>{};
}

DateTime? _readDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
