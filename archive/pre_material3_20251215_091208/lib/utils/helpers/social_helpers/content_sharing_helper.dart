import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Helper class for content sharing operations
/// Handles text generation, deep linking, and social sharing
class ContentSharingHelper {
  static const String baseUrl = 'https://dabbler.app';
  static const int maxShareTextLength = 200;

  /// Generates appropriate share text based on content type
  static String generateShareText({
    required String contentType,
    required String authorName,
    String? content,
    String? gameResult,
    String? achievementName,
  }) {
    switch (contentType.toLowerCase()) {
      case 'post':
        if (content != null && content.isNotEmpty) {
          final truncatedContent = content.length > 100
              ? '${content.substring(0, 100)}...'
              : content;
          return 'Check out this post by $authorName: "$truncatedContent"\\n\\nJoin me on Dabbler!';
        }
        return 'Check out this post by $authorName on Dabbler!';

      case 'game_result':
        return gameResult != null
            ? '$authorName just played a game! $gameResult\\n\\nSee their progress on Dabbler!'
            : '$authorName just finished a game! Check it out on Dabbler!';

      case 'achievement':
        return achievementName != null
            ? '🏆 $authorName just earned the "$achievementName" achievement!\\n\\nCelebrate with them on Dabbler!'
            : '🏆 $authorName just unlocked a new achievement! Check it out on Dabbler!';

      case 'profile':
        return 'Connect with $authorName on Dabbler - the ultimate sports social app!\\n\\nJoin the community!';

      case 'media':
        return '$authorName shared some awesome content on Dabbler! Check it out!';

      default:
        return 'Check this out on Dabbler - where sports enthusiasts connect!';
    }
  }

  /// Generates deep links for app content
  static String generateDeepLink({
    required String type,
    required String id,
    Map<String, String>? queryParams,
  }) {
    var link = '$baseUrl/$type/$id';

    if (queryParams != null && queryParams.isNotEmpty) {
      final params = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      link += '?$params';
    }

    return link;
  }

  /// Shares content with optional image
  static Future<bool> shareContent({
    required String text,
    String? imageUrl,
    String? subject,
    required BuildContext context,
  }) async {
    try {
      // Truncate text if too long
      final shareText = text.length > maxShareTextLength
          ? '${text.substring(0, maxShareTextLength)}...'
          : text;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Download and share image
        final success = await _shareWithImage(
          text: shareText,
          imageUrl: imageUrl,
          subject: subject,
        );
        return success;
      } else {
        // Share text only
        final result = await Share.share(shareText, subject: subject);
        return result.status == ShareResultStatus.success;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }

  /// Shares content with image attachment
  static Future<bool> _shareWithImage({
    required String text,
    required String imageUrl,
    String? subject,
  }) async {
    try {
      // Download image
      final response = await http
          .get(Uri.parse(imageUrl), headers: {'User-Agent': 'Dabbler-App'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }

      // Save to temporary directory
      final documentDirectory = await getApplicationDocumentsDirectory();
      final fileName = 'share_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${documentDirectory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      // Share with image
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: subject,
      );

      // Clean up temporary file
      try {
        await file.delete();
      } catch (e) {
        // Ignore cleanup errors
      }

      return result.status == ShareResultStatus.success;
    } catch (e) {
      // Fallback to text-only sharing
      final result = await Share.share(text, subject: subject);
      return result.status == ShareResultStatus.success;
    }
  }

  /// Gets analytics data for share events
  static Map<String, dynamic> getShareAnalytics({
    required String contentType,
    required String contentId,
    required String shareMethod,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) {
    final analytics = <String, String>{
      'event': 'content_shared',
      'content_type': contentType,
      'content_id': contentId,
      'share_method': shareMethod,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (userId != null) {
      analytics['user_id'] = userId;
    }
    if (additionalData != null) {
      additionalData.forEach((key, value) {
        if (value != null) {
          analytics[key] = value.toString();
        }
      });
    }
    return analytics;
  }

  /// Generates shareable content for different platforms
  static Map<String, String> generatePlatformContent({
    required String contentType,
    required String authorName,
    required String content,
    String? deepLink,
  }) {
    final baseText = generateShareText(
      contentType: contentType,
      authorName: authorName,
      content: content,
    );

    return {
      'default': baseText,
      'twitter': _formatForTwitter(baseText, deepLink),
      'facebook': _formatForFacebook(baseText, deepLink),
      'instagram': _formatForInstagram(content, authorName),
      'whatsapp': _formatForWhatsApp(baseText),
      'email': _formatForEmail(baseText, authorName, deepLink),
    };
  }

  /// Formats content for Twitter
  static String _formatForTwitter(String text, String? link) {
    const maxLength = 240; // Leave room for link
    var tweetText = text;

    if (link != null) {
      tweetText += '\\n$link';
    }

    if (tweetText.length > maxLength) {
      final availableLength =
          maxLength - (link?.length ?? 0) - 5; // 5 for newline + ellipsis
      tweetText = '${text.substring(0, availableLength)}...';
      if (link != null) {
        tweetText += '\\n$link';
      }
    }

    return tweetText;
  }

  /// Formats content for Facebook
  static String _formatForFacebook(String text, String? link) {
    var fbText = text;
    if (link != null) {
      fbText += '\\n\\n$link';
    }
    return fbText;
  }

  /// Formats content for Instagram
  static String _formatForInstagram(String content, String authorName) {
    // Instagram is more visual, so focus on engaging text
    return 'Amazing content from $authorName! 🔥\\n\\n#Dabbler #Sports #Community';
  }

  /// Formats content for WhatsApp
  static String _formatForWhatsApp(String text) {
    // WhatsApp supports longer messages
    return '$text\\n\\n📱 Download Dabbler and join the sports community!';
  }

  /// Formats content for email
  static String _formatForEmail(String text, String authorName, String? link) {
    var emailBody = 'Hi!\\n\\n$text\\n\\n';
    emailBody +=
        'I thought you might be interested in connecting with $authorName ';
    emailBody +=
        'on Dabbler, the sports social app where athletes and enthusiasts ';
    emailBody += 'come together to share their passion.\\n\\n';

    if (link != null) {
      emailBody += 'Check it out here: $link\\n\\n';
    }

    emailBody += 'Best regards!';

    return emailBody;
  }

  /// Validates if content can be shared
  static bool canShareContent({
    required String contentType,
    required String contentId,
    bool isPublic = true,
    bool isOwnContent = false,
  }) {
    // Private content can only be shared by owner
    if (!isPublic && !isOwnContent) return false;

    // Validate content type
    const allowedTypes = [
      'post',
      'game_result',
      'achievement',
      'profile',
      'media',
    ];

    if (!allowedTypes.contains(contentType.toLowerCase())) return false;

    // Validate ID
    if (contentId.isEmpty) return false;

    return true;
  }

  /// Gets suggested share platforms based on content type
  static List<String> getSuggestedPlatforms(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'game_result':
        return ['twitter', 'facebook', 'whatsapp', 'instagram'];
      case 'achievement':
        return ['twitter', 'instagram', 'facebook', 'whatsapp'];
      case 'media':
        return ['instagram', 'facebook', 'twitter', 'whatsapp'];
      case 'profile':
        return ['whatsapp', 'email', 'facebook', 'twitter'];
      default:
        return ['facebook', 'twitter', 'whatsapp', 'email'];
    }
  }

  /// Tracks share completion
  static void trackShareCompletion({
    required String contentType,
    required String contentId,
    required String platform,
    required bool success,
  }) {
    // This would integrate with your analytics service
    // Example implementation:
    // AnalyticsService.track('share_completed', {
    //   'content_type': contentType,
    //   'content_id': contentId,
    //   'platform': platform,
    //   'success': success,
    //   'timestamp': DateTime.now().toIso8601String(),
    // });
  }
}
