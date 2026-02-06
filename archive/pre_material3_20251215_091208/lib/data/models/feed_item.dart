import 'dart:convert';
import 'package:dabbler/core/utils/json.dart';
import 'post.dart';

/// A polymorphic feed item. For now only `post`, but intentionally open for future kinds.
class FeedItem {
  final String id; // underlying entity id (e.g., post id)
  final String kind; // 'post' (future: 'game', 'meetup', etc.)
  final DateTime createdAt; // ordering key (desc)
  final Post? post;
  final Map<String, dynamic>? extra;

  const FeedItem({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.post,
    this.extra,
  });

  /// Build from a posts row (server returns visible rows only via RLS).
  factory FeedItem.fromPostRow(Map<String, dynamic> row) {
    final m = asMap(row);
    final p = Post.fromMap(m);
    return FeedItem(
      id: p.id,
      kind: 'post',
      createdAt: p.createdAt,
      post: p,
      extra: null,
    );
  }

  /// Stable opaque cursor encoding (createdAt + id).
  /// Format: base64url("ISO8601UTC|id")
  String toCursor() {
    final iso = createdAt.toUtc().toIso8601String();
    return base64Url.encode(utf8.encode('$iso|$id'));
  }

  /// Decode cursor -> (createdAt, id). Returns null if invalid.
  static ({DateTime createdAt, String id})? decodeCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    try {
      final raw = utf8.decode(base64Url.decode(cursor));
      final parts = raw.split('|');
      if (parts.length != 2) return null;
      final dt = DateTime.parse(parts[0]).toUtc();
      final id = parts[1];
      return (createdAt: dt, id: id);
    } catch (_) {
      return null;
    }
  }
}
