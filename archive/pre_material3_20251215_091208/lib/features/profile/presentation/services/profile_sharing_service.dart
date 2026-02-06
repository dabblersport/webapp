import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for handling profile sharing functionality
class ProfileSharingService {
  static const String _logTag = 'ProfileSharingService';
  static const String _baseUrl =
      'https://dabbler.app'; // Replace with actual domain

  /// Generate shareable profile link
  static String generateProfileLink(String userId) {
    return '$_baseUrl/profile/$userId';
  }

  /// Share profile via system share sheet
  static Future<void> shareProfile({
    required String userId,
    required String userName,
    String? customMessage,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final profileLink = generateProfileLink(userId);
      final message =
          customMessage ??
          'Check out $userName\'s profile on Dabbler! $profileLink';

      await _trackSharingEvent('profile_shared', {
        'userId': userId,
        'userName': userName,
        'method': 'system_share',
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Copy profile link to clipboard
  static Future<void> copyProfileLink({
    required BuildContext context,
    required String userId,
    required String userName,
  }) async {
    try {
      final profileLink = generateProfileLink(userId);

      await Clipboard.setData(ClipboardData(text: profileLink));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile link copied to clipboard'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await _trackSharingEvent('profile_link_copied', {
        'userId': userId,
        'userName': userName,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy link. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Generate QR code widget for profile
  static Widget generateProfileQRCode({
    required String userId,
    double size = 200,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) {
    try {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: size * 0.4, color: foregroundColor),
            const SizedBox(height: 8),
            Text(
              'QR Code',
              style: TextStyle(
                fontSize: 14,
                color: foregroundColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan to view profile',
              style: TextStyle(
                fontSize: 12,
                color: foregroundColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.error_outline, color: Colors.grey, size: 48),
      );
    }
  }

  /// Show QR code sharing dialog
  static Future<void> showQRCodeDialog({
    required BuildContext context,
    required String userId,
    required String userName,
  }) async {
    try {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$userName\'s Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  generateProfileQRCode(userId: userId, size: 200),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => copyProfileLink(
                          context: context,
                          userId: userId,
                          userName: userName,
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Link'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            shareProfile(userId: userId, userName: userName),
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      await _trackSharingEvent('qr_code_viewed', {
        'userId': userId,
        'userName': userName,
      });
    } catch (e) {}
  }

  /// Share profile to specific social media platform
  static Future<void> shareToSocialMedia({
    required String userId,
    required String userName,
    required SocialPlatform platform,
    String? customMessage,
  }) async {
    try {
      final profileLink = generateProfileLink(userId);
      final message =
          customMessage ?? 'Check out $userName\'s profile on Dabbler!';

      String shareUrl = '';

      switch (platform) {
        case SocialPlatform.twitter:
          shareUrl =
              'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}&url=${Uri.encodeComponent(profileLink)}';
          break;
        case SocialPlatform.facebook:
          shareUrl =
              'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(profileLink)}';
          break;
        case SocialPlatform.instagram:
          // Instagram doesn't support direct URL sharing, fallback to system share
          await shareProfile(
            userId: userId,
            userName: userName,
            customMessage: message,
          );
          return;
        case SocialPlatform.whatsapp:
          shareUrl =
              'https://wa.me/?text=${Uri.encodeComponent('$message $profileLink')}';
          break;
      }

      if (shareUrl.isNotEmpty) {}

      await _trackSharingEvent('social_media_share', {
        'userId': userId,
        'userName': userName,
        'platform': platform.toString(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Generate profile preview metadata for sharing
  static Map<String, String> generatePreviewMetadata({
    required String userId,
    required String userName,
    String? userBio,
    String? profileImageUrl,
    List<String>? sports,
  }) {
    try {
      final profileLink = generateProfileLink(userId);

      return {
        'og:title': '$userName\'s Dabbler Profile',
        'og:description':
            userBio ?? 'Connect and play sports with $userName on Dabbler!',
        'og:image':
            profileImageUrl ?? 'https://dabbler.app/default-profile.png',
        'og:url': profileLink,
        'og:type': 'profile',
        'og:site_name': 'Dabbler',
        'twitter:card': 'summary_large_image',
        'twitter:title': '$userName\'s Dabbler Profile',
        'twitter:description':
            userBio ?? 'Connect and play sports with $userName on Dabbler!',
        'twitter:image':
            profileImageUrl ?? 'https://dabbler.app/default-profile.png',
        if (sports != null && sports.isNotEmpty)
          'profile:sports': sports.join(', '),
      };
    } catch (e) {
      return {};
    }
  }

  /// Track shared link clicks (call this from your web app)
  static Future<void> trackSharedLinkClick({
    required String userId,
    String? referrer,
    String? userAgent,
  }) async {
    try {
      await _trackSharingEvent('shared_link_clicked', {
        'userId': userId,
        'referrer': referrer,
        'userAgent': userAgent,
      });
    } catch (e) {}
  }

  /// Private helper methods

  static Future<void> _trackSharingEvent(
    String event,
    Map<String, dynamic> parameters,
  ) async {
    try {} catch (e) {}
  }
}

/// Enum for social media platforms
enum SocialPlatform { twitter, facebook, instagram, whatsapp }

/// Extension for social platform display names
extension SocialPlatformExtension on SocialPlatform {
  String get displayName {
    switch (this) {
      case SocialPlatform.twitter:
        return 'Twitter';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.whatsapp:
        return 'WhatsApp';
    }
  }

  IconData get icon {
    switch (this) {
      case SocialPlatform.twitter:
        return Icons.flutter_dash; // Replace with actual Twitter icon
      case SocialPlatform.facebook:
        return Icons.facebook;
      case SocialPlatform.instagram:
        return Icons.camera_alt; // Replace with actual Instagram icon
      case SocialPlatform.whatsapp:
        return Icons.chat; // Replace with actual WhatsApp icon
    }
  }
}
