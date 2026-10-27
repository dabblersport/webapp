/// One of the fixed tags the server publishes, with its two labels (KAN-666).
class RatingTag {
  const RatingTag({
    required this.key,
    required this.labelEn,
    required this.labelAr,
  });

  final String key;
  final String labelEn;
  final String labelAr;

  String label(bool arabic) => arabic && labelAr.isNotEmpty ? labelAr : labelEn;
}

/// A player's rating aggregate, as the server returns it once the player is
/// past the visibility threshold. There is no rater, game or time in it.
class RatingAggregate {
  const RatingAggregate({
    required this.average,
    required this.count,
    required this.topTags,
  });

  /// Builds the aggregate from the single row of
  /// `rpc_get_user_rating_aggregate`; [labels] maps dimension key to tag.
  /// The top tags are the best-scoring dimensions, at most [maxTags].
  factory RatingAggregate.fromRow(
    Map<String, dynamic> row,
    Map<String, RatingTag> labels, {
    int maxTags = 3,
  }) {
    final means = <String, double>{
      for (final e in ((row['dimension_means'] as Map?) ?? const {}).entries)
        if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    };
    final keys = means.keys.where(labels.containsKey).toList()
      ..sort((a, b) {
        final byMean = means[b]!.compareTo(means[a]!);
        return byMean != 0 ? byMean : a.compareTo(b);
      });
    final count = row['event_count'];
    return RatingAggregate(
      average: (row['composite_score'] as num).toDouble(),
      count: count is num && count > 0 ? count.toInt() : null,
      topTags: [for (final k in keys.take(maxTags)) labels[k]!],
    );
  }

  /// Average on the server's 0..5 scale.
  final double average;

  /// Number of ratings, only when the server returned it.
  final int? count;

  final List<RatingTag> topTags;
}
