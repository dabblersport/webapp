import 'package:dabbler/core/utils/json.dart';

/// Keep the name distinct from platform classes.
class AppNotification {
  final String id;
  final String userId;
  final String type; // e.g. 'friend_request', 'invite', etc.
  final Map<String, dynamic> payload; // arbitrary jsonb payload from DB
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? seenAt;

  // Optional denormalized presentation fields (if your view exposes them)
  final String? title;
  final String? body;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.readAt,
    this.seenAt,
    this.title,
    this.body,
  });

  factory AppNotification.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    return AppNotification(
      id: (m['id'] ?? m['notification_id']).toString(),
      userId: (m['user_id'] ?? m['uid']).toString(),
      type: (m['type'] ?? m['notification_type'] ?? m['type_code'] ?? '')
          .toString(),
      payload: asMap(m['payload'] ?? m['data'] ?? m['meta']),
      createdAt:
          asDateTime(m['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      readAt: asDateTime(m['read_at']),
      seenAt: asDateTime(m['seen_at']),
      title: m['title']?.toString(),
      body: m['body']?.toString(),
    );
  }

  bool get isRead => readAt != null;
  bool get isSeen => seenAt != null;

  AppNotification copyWith({
    DateTime? readAt,
    DateTime? seenAt,
    String? title,
    String? body,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      payload: payload,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      seenAt: seenAt ?? this.seenAt,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }
}
