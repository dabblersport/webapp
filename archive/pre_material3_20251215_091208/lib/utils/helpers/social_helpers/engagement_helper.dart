import 'dart:math';
import 'package:dabbler/data/models/social/post_model.dart';

/// Helper class for calculating engagement metrics
class EngagementHelper {
  /// Calculates viral coefficient for a post
  static ViralData calculateViralCoefficient(PostModel post) {
    // Basic viral coefficient calculation
    final totalEngagement =
        post.likesCount + post.commentsCount + (post.sharesCount * 2);

    // Simple coefficient based on engagement relative to recency
    final hoursSincePost = DateTime.now().difference(post.createdAt).inHours;
    final timeDecay = max(
      0.1,
      1.0 - (hoursSincePost / 168.0),
    ); // Decay over week

    final coefficient = (totalEngagement * timeDecay) / max(1, hoursSincePost);

    return ViralData(
      coefficient: coefficient,
      engagementVelocity: totalEngagement / max(1, hoursSincePost),
      timeDecay: timeDecay,
    );
  }

  /// Formats engagement count for display (e.g., 1.2K, 500, 2.5M)
  static String formatEngagementCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      final k = count / 1000;
      if (k == k.roundToDouble()) {
        return '${k.round()}K';
      } else {
        return '${k.toStringAsFixed(1)}K';
      }
    } else {
      final m = count / 1000000;
      if (m == m.roundToDouble()) {
        return '${m.round()}M';
      } else {
        return '${m.toStringAsFixed(1)}M';
      }
    }
  }

  /// Calculates engagement rate as percentage
  static double calculateEngagementRate(PostModel post) {
    final totalEngagement =
        post.likesCount + post.commentsCount + post.sharesCount;

    // For now, assume a baseline reach (could be enhanced with actual reach data)
    final estimatedReach = max(100, totalEngagement * 10); // Simple estimation

    return (totalEngagement / estimatedReach) * 100;
  }

  /// Calculates trending score for post ranking
  static double calculateTrendingScore(PostModel post) {
    final viralData = calculateViralCoefficient(post);
    final engagementRate = calculateEngagementRate(post);

    // Combine viral coefficient with engagement rate
    return (viralData.coefficient * 0.7) + (engagementRate * 0.3);
  }

  /// Determines if post is trending based on multiple factors
  static bool isTrending(PostModel post, {double threshold = 5.0}) {
    return calculateTrendingScore(post) >= threshold;
  }

  /// Gets engagement breakdown by type
  static Map<String, double> getEngagementBreakdown(PostModel post) {
    final total = post.likesCount + post.commentsCount + post.sharesCount;

    if (total == 0) {
      return {'likes': 0.0, 'comments': 0.0, 'shares': 0.0};
    }

    return {
      'likes': (post.likesCount / total) * 100,
      'comments': (post.commentsCount / total) * 100,
      'shares': (post.sharesCount / total) * 100,
    };
  }
}

/// Data class for viral metrics
class ViralData {
  final double coefficient;
  final double engagementVelocity;
  final double timeDecay;

  const ViralData({
    required this.coefficient,
    required this.engagementVelocity,
    required this.timeDecay,
  });

  @override
  String toString() {
    return 'ViralData(coefficient: $coefficient, velocity: $engagementVelocity, decay: $timeDecay)';
  }
}
