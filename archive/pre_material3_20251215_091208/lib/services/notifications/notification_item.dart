import 'package:flutter/foundation.dart';

/// Lightweight projection of a row from `v_notifications`.
@immutable
class NotificationItem {
  final String id;
  final String kindKey;
  final String title;
  final String? body;
  final String? actionRoute;
  final Map<String, dynamic>? context;
  final String priority; // 'low' | 'normal' | 'high' | 'urgent'
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const NotificationItem({
    required this.id,
    required this.kindKey,
    required this.title,
    this.body,
    this.actionRoute,
    this.context,
    this.priority = 'normal',
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    // Supabase returns dynamic json; handle both map and JSON-string for context.
    Map<String, dynamic>? parsedContext;
    final rawContext = map['context'];
    if (rawContext is Map<String, dynamic>) {
      parsedContext = rawContext;
    } else if (rawContext is Map) {
      parsedContext = Map<String, dynamic>.from(rawContext);
    } else {
      parsedContext = null;
    }

    return NotificationItem(
      id: map['id'] as String,
      kindKey: map['kind_key'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      actionRoute: map['action_route'] as String?,
      context: parsedContext,
      priority: (map['priority'] as String?) ?? 'normal',
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead: map['is_read'] as bool? ?? false,
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'] as String)
          : null,
    );
  }
}
