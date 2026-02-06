import 'package:dabbler/core/utils/json.dart';

/// App-level model for a user-submitted abuse report against a post.
/// This maps to the `public.post_reports` table (fields are tolerant).
class AbuseFlag {
  final String id;
  final String reporterUserId;
  final String postId;

  /// Optional metadata if present in your schema.
  final String? reason; // e.g. 'spam', 'abuse', 'nsfw'
  final String? details; // freeform text
  final String? status; // if your schema tracks workflow status
  final DateTime createdAt;

  const AbuseFlag({
    required this.id,
    required this.reporterUserId,
    required this.postId,
    required this.createdAt,
    this.reason,
    this.details,
    this.status,
  });

  factory AbuseFlag.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    return AbuseFlag(
      id: (m['id'] ?? m['report_id'] ?? '').toString(),
      reporterUserId: (m['reporter_user_id'] ?? m['user_id'] ?? '').toString(),
      postId: (m['post_id'] ?? '').toString(),
      reason: m['reason']?.toString(),
      details: m['details']?.toString() ?? m['note']?.toString(),
      status: m['status']?.toString(),
      createdAt:
          asDateTime(m['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'reporter_user_id': reporterUserId,
      'post_id': postId,
      if (reason != null) 'reason': reason,
      if (details != null) 'details': details,
    };
  }
}
