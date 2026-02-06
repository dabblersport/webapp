import 'package:dabbler/core/utils/json.dart';

/// Canonical client model for rows in `public.ratings`.
/// The shape is tolerant to schema variations.
class Rating {
  final String id;
  final String raterUserId;

  /// One of these target fields will be set depending on context.
  final String? targetUserId;
  final String? targetGameId;
  final String? targetVenueId;

  /// Optional context row (e.g., game id used for venue derivation server-side).
  final String? contextId;

  /// The numeric score. If your schema uses integer scores, this will coerce to double.
  final double score;

  final String? category; // e.g., 'host', 'player', etc. (optional)
  final String? note; // free text (optional)
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.raterUserId,
    required this.score,
    required this.createdAt,
    this.targetUserId,
    this.targetGameId,
    this.targetVenueId,
    this.contextId,
    this.category,
    this.note,
  });

  factory Rating.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    return Rating(
      id: (m['id'] ?? '').toString(),
      raterUserId: (m['rater_user_id'] ?? m['raterId'] ?? '').toString(),
      targetUserId: m['target_user_id']?.toString(),
      targetGameId: m['target_game_id']?.toString(),
      targetVenueId: m['target_venue_id']?.toString(),
      contextId: m['context_id']?.toString(),
      score:
          asDouble(m['score']) ??
          asInt(m['score'])?.toDouble() ??
          asDouble(m['rating']) ??
          0.0,
      category: m['category']?.toString(),
      note: m['note']?.toString(),
      createdAt:
          asDateTime(m['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

/// Generic "average + count (+ last time)" aggregate the API may expose.
/// We keep it loose so different materialized views can map into it.
class RatingAggregate {
  final String subjectId; // user_id, game_id, or venue_id depending on source
  final double average;
  final int count;
  final DateTime? lastRatedAt;

  const RatingAggregate({
    required this.subjectId,
    required this.average,
    required this.count,
    this.lastRatedAt,
  });

  factory RatingAggregate.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);
    final subj =
        (m['user_id'] ?? m['game_id'] ?? m['venue_id'] ?? m['id'] ?? '')
            .toString();

    // Try a few common avg/count field names.
    final avg =
        asDouble(m['avg']) ??
        asDouble(m['avg_score']) ??
        asDouble(m['score_avg']) ??
        asDouble(m['rating_avg']) ??
        (asInt(m['avg'])?.toDouble()) ??
        0.0;

    final cnt =
        asInt(m['count']) ??
        asInt(m['rating_count']) ??
        asInt(m['num']) ??
        asInt(m['n']) ??
        0;

    final last =
        asDateTime(m['last_rated_at']) ??
        asDateTime(m['updated_at']) ??
        asDateTime(m['last_at']);

    return RatingAggregate(
      subjectId: subj,
      average: avg,
      count: cnt,
      lastRatedAt: last,
    );
  }
}
