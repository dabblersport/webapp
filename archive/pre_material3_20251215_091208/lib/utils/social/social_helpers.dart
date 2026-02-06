import 'dart:math' as math;
import 'social_constants.dart';

/// Helper functions for social media features
class SocialHelpers {
  /// Format post time relative to now (Just now, 5m ago, etc.)
  static String formatPostTime(DateTime postTime) {
    final now = DateTime.now();
    final difference = now.difference(postTime);

    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  /// Extract mentions from text (@username format)
  static List<String> extractMentions(String text) {
    final mentionRegex = RegExp(
      SocialConstants.mentionPattern,
      caseSensitive: false,
    );
    final matches = mentionRegex.allMatches(text);
    return matches
        .map((match) => match.group(1)!.toLowerCase())
        .toSet()
        .toList();
  }

  /// Extract hashtags from text (#hashtag format)
  static List<String> extractHashtags(String text) {
    final hashtagRegex = RegExp(
      SocialConstants.hashtagPattern,
      caseSensitive: false,
    );
    final matches = hashtagRegex.allMatches(text);
    return matches
        .map((match) => match.group(1)!.toLowerCase())
        .toSet()
        .toList();
  }

  /// Generate share text for a post
  static String generateShareText(
    String postContent,
    String authorName, {
    String? appName,
  }) {
    final cleanContent = _cleanTextForSharing(postContent);
    final shortContent = cleanContent.length > 100
        ? '${cleanContent.substring(0, 100)}...'
        : cleanContent;

    final app = appName ?? 'Dabbler';
    return 'Check out this post by $authorName on $app:\n\n"$shortContent"\n\nJoin the conversation!';
  }

  /// Calculate engagement rate (likes + comments + shares) / views
  static double calculateEngagementRate(
    int likes,
    int comments,
    int shares,
    int views,
  ) {
    if (views == 0) return 0.0;
    final totalEngagement = likes + comments + shares;
    return (totalEngagement / views) * 100; // Return as percentage
  }

  /// Format large numbers with K, M suffixes (1.2K, 3.5M)
  static String formatLargeNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      final k = number / 1000;
      return k % 1 == 0 ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else if (number < 1000000000) {
      final m = number / 1000000;
      return m % 1 == 0 ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    } else {
      final b = number / 1000000000;
      return b % 1 == 0 ? '${b.toInt()}B' : '${b.toStringAsFixed(1)}B';
    }
  }

  /// Validate post content for length, mentions, hashtags, etc.
  static PostValidationResult validatePostContent(String content) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check length
    if (content.isEmpty) {
      errors.add('Post content cannot be empty');
    } else if (content.length > SocialConstants.maxPostLength) {
      errors.add(
        'Post content exceeds ${SocialConstants.maxPostLength} characters',
      );
    }

    // Check mentions
    final mentions = extractMentions(content);
    if (mentions.length > SocialConstants.maxMentionsPerPost) {
      errors.add(
        'Too many mentions (max ${SocialConstants.maxMentionsPerPost})',
      );
    }

    // Check hashtags
    final hashtags = extractHashtags(content);
    if (hashtags.length > SocialConstants.maxHashtagsPerPost) {
      warnings.add(
        'Many hashtags may reduce visibility (${hashtags.length}/${SocialConstants.maxHashtagsPerPost})',
      );
    }

    // Check for URLs
    final urlRegex = RegExp(SocialConstants.urlPattern);
    final urlMatches = urlRegex.allMatches(content);
    if (urlMatches.length > SocialConstants.maxLinksPerPost) {
      warnings.add('Multiple links may be flagged as spam');
    }

    // Check for excessive caps
    final capsCount = content
        .split('')
        .where((c) => c == c.toUpperCase() && c != c.toLowerCase())
        .length;
    final capsPercentage = capsCount / content.length;
    if (capsPercentage > 0.7 && content.length > 10) {
      warnings.add('Excessive capitalization may reduce engagement');
    }

    return PostValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      wordCount: _countWords(content),
      characterCount: content.length,
      mentionCount: mentions.length,
      hashtagCount: hashtags.length,
    );
  }

  /// Generate trending score based on engagement and time
  static double calculateTrendingScore(
    int likes,
    int comments,
    int shares,
    DateTime postTime,
  ) {
    final now = DateTime.now();
    final ageInHours = now.difference(postTime).inHours.toDouble();

    // Engagement weight decreases over time
    final timeDecay = math.exp(-ageInHours / 24); // Half-life of 24 hours
    final engagementScore = (likes * 1.0) + (comments * 2.0) + (shares * 3.0);

    return engagementScore * timeDecay;
  }

  /// Check if content contains inappropriate language
  static bool containsInappropriateContent(String content) {
    // This would typically use a more sophisticated content moderation service
    // For now, just basic checks
    final inappropriateWords = ['spam', 'scam', 'fake', 'hate'];
    final lowerContent = content.toLowerCase();

    return inappropriateWords.any((word) => lowerContent.contains(word));
  }

  /// Generate content preview for notifications/sharing
  static String generateContentPreview(String content, {int maxLength = 100}) {
    if (content.length <= maxLength) return content;

    // Try to cut at word boundary
    final cutPoint = content.lastIndexOf(' ', maxLength);
    if (cutPoint > maxLength * 0.7) {
      return '${content.substring(0, cutPoint)}...';
    }

    return '${content.substring(0, maxLength)}...';
  }

  /// Calculate reading time estimate
  static String estimateReadingTime(String content) {
    const wordsPerMinute = 200;
    final wordCount = _countWords(content);
    final minutes = (wordCount / wordsPerMinute).ceil();

    if (minutes < 1) return 'Less than 1 min read';
    if (minutes == 1) return '1 min read';
    return '$minutes min read';
  }

  /// Get content sentiment (positive, neutral, negative)
  static ContentSentiment analyzeSentiment(String content) {
    // Simple sentiment analysis - in production, use ML service
    final positiveWords = [
      'great',
      'awesome',
      'love',
      'amazing',
      'fantastic',
      'wonderful',
      'excellent',
    ];
    final negativeWords = [
      'hate',
      'terrible',
      'awful',
      'bad',
      'worst',
      'horrible',
      'disgusting',
    ];

    final lowerContent = content.toLowerCase();
    final positiveCount = positiveWords
        .where((word) => lowerContent.contains(word))
        .length;
    final negativeCount = negativeWords
        .where((word) => lowerContent.contains(word))
        .length;

    if (positiveCount > negativeCount) return ContentSentiment.positive;
    if (negativeCount > positiveCount) return ContentSentiment.negative;
    return ContentSentiment.neutral;
  }

  // Private helper methods
  static String _cleanTextForSharing(String text) {
    // Remove excessive whitespace and newlines
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int _countWords(String text) {
    if (text.isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}

/// Result of post content validation
class PostValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final int wordCount;
  final int characterCount;
  final int mentionCount;
  final int hashtagCount;

  const PostValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.wordCount,
    required this.characterCount,
    required this.mentionCount,
    required this.hashtagCount,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

/// Content sentiment analysis result
enum ContentSentiment { positive, neutral, negative }

/// Engagement level based on metrics
enum EngagementLevel {
  low, // < 1%
  medium, // 1-5%
  high, // 5-10%
  viral, // > 10%
}

extension EngagementLevelExtension on EngagementLevel {
  static EngagementLevel fromRate(double rate) {
    if (rate < 1) return EngagementLevel.low;
    if (rate < 5) return EngagementLevel.medium;
    if (rate < 10) return EngagementLevel.high;
    return EngagementLevel.viral;
  }

  String get displayName {
    switch (this) {
      case EngagementLevel.low:
        return 'Low';
      case EngagementLevel.medium:
        return 'Medium';
      case EngagementLevel.high:
        return 'High';
      case EngagementLevel.viral:
        return 'Viral';
    }
  }

  String get description {
    switch (this) {
      case EngagementLevel.low:
        return 'Post has limited reach';
      case EngagementLevel.medium:
        return 'Good engagement from audience';
      case EngagementLevel.high:
        return 'High audience engagement';
      case EngagementLevel.viral:
        return 'Post is trending!';
    }
  }
}
