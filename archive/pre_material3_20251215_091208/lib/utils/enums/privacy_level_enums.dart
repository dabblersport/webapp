/// Privacy level enum definitions with access control logic
library;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Enum representing different privacy levels for user content and profile visibility
enum PrivacyLevel {
  public('public', 'Everyone', Iconsax.global_copy),
  friends('friends', 'Friends Only', Iconsax.people_copy),
  private('private', 'Only Me', Iconsax.lock_copy);

  final String value;
  final String displayName;
  final IconData icon;
  const PrivacyLevel(this.value, this.displayName, this.icon);

  /// Create PrivacyLevel from string value
  static PrivacyLevel fromString(String value) =>
      PrivacyLevel.values.firstWhere(
        (e) => e.value == value,
        orElse: () => PrivacyLevel.friends, // Default to friends-only
      );

  /// Check if content with this privacy level can be viewed by a user
  bool canView(bool isFriend, bool isOwner) {
    switch (this) {
      case PrivacyLevel.public:
        return true;
      case PrivacyLevel.friends:
        return isFriend || isOwner;
      case PrivacyLevel.private:
        return isOwner;
    }
  }

  /// Check if content can be shared externally
  bool get canShare {
    return this == PrivacyLevel.public;
  }

  /// Check if content appears in search results
  bool get appearsInSearch {
    return this == PrivacyLevel.public;
  }

  /// Get color representation for the privacy level
  Color get color {
    switch (this) {
      case PrivacyLevel.public:
        return Colors.blue;
      case PrivacyLevel.friends:
        return Colors.orange;
      case PrivacyLevel.private:
        return Colors.red;
    }
  }

  /// Get description explaining what this privacy level means
  String get description {
    switch (this) {
      case PrivacyLevel.public:
        return 'Visible to everyone on Dabbler, including non-users';
      case PrivacyLevel.friends:
        return 'Only visible to your friends and people you follow';
      case PrivacyLevel.private:
        return 'Only visible to you. Complete privacy';
    }
  }

  /// Get warning message for this privacy level
  String? get warningMessage {
    switch (this) {
      case PrivacyLevel.public:
        return 'This content will be visible to anyone, including search engines';
      case PrivacyLevel.friends:
        return null; // No warning for friends-only
      case PrivacyLevel.private:
        return 'This content will only be visible to you';
    }
  }

  /// Generate a privacy level selector widget
  Widget toChip({
    bool selected = false,
    VoidCallback? onSelected,
    bool showDescription = false,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Colors.grey,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: selected ? color : Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  displayName,
                  style: TextStyle(
                    color: selected ? color : Colors.grey[700],
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (showDescription) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get recommended privacy level for different content types
  static PrivacyLevel getRecommendedFor(ContentType contentType) {
    switch (contentType) {
      case ContentType.profile:
        return PrivacyLevel.friends;
      case ContentType.gameHistory:
        return PrivacyLevel.public;
      case ContentType.personalInfo:
        return PrivacyLevel.private;
      case ContentType.achievements:
        return PrivacyLevel.friends;
      case ContentType.location:
        return PrivacyLevel.friends;
      case ContentType.contactInfo:
        return PrivacyLevel.private;
    }
  }

  /// Get all privacy levels as options
  static List<PrivacyLevel> get allLevels => PrivacyLevel.values;

  /// Get privacy levels that allow social interaction
  static List<PrivacyLevel> get socialLevels => [
    PrivacyLevel.public,
    PrivacyLevel.friends,
  ];
}

/// Enum representing different types of content that can have privacy settings
enum ContentType {
  profile('profile', 'Profile Information', Iconsax.user_copy),
  gameHistory('game_history', 'Game History', Iconsax.clock_copy),
  personalInfo(
    'personal_info',
    'Personal Information',
    Iconsax.info_circle_copy,
  ),
  achievements('achievements', 'Achievements', Iconsax.medal_copy),
  location('location', 'Location', Iconsax.location_copy),
  contactInfo('contact_info', 'Contact Information', Iconsax.call_copy);

  final String value;
  final String displayName;
  final IconData icon;
  const ContentType(this.value, this.displayName, this.icon);

  /// Get description for this content type
  String get description {
    switch (this) {
      case ContentType.profile:
        return 'Basic profile details like name, bio, and avatar';
      case ContentType.gameHistory:
        return 'Your game participation and results';
      case ContentType.personalInfo:
        return 'Age, gender, and other personal details';
      case ContentType.achievements:
        return 'Awards, badges, and accomplishments';
      case ContentType.location:
        return 'Your location and location history';
      case ContentType.contactInfo:
        return 'Email, phone number, and social media';
    }
  }

  /// Get sensitivity level (how private this content should typically be)
  PrivacySensitivity get sensitivity {
    switch (this) {
      case ContentType.profile:
        return PrivacySensitivity.medium;
      case ContentType.gameHistory:
        return PrivacySensitivity.low;
      case ContentType.personalInfo:
        return PrivacySensitivity.high;
      case ContentType.achievements:
        return PrivacySensitivity.low;
      case ContentType.location:
        return PrivacySensitivity.high;
      case ContentType.contactInfo:
        return PrivacySensitivity.high;
    }
  }
}

/// Enum representing privacy sensitivity levels
enum PrivacySensitivity {
  low('low', Colors.green),
  medium('medium', Colors.orange),
  high('high', Colors.red);

  final String value;
  final Color color;
  const PrivacySensitivity(this.value, this.color);

  /// Get recommended privacy level for this sensitivity
  PrivacyLevel get recommendedPrivacyLevel {
    switch (this) {
      case PrivacySensitivity.low:
        return PrivacyLevel.public;
      case PrivacySensitivity.medium:
        return PrivacyLevel.friends;
      case PrivacySensitivity.high:
        return PrivacyLevel.private;
    }
  }
}

/// Enum representing different privacy settings categories
enum PrivacyCategory {
  visibility('visibility', 'Profile Visibility', Iconsax.eye_copy),
  communication('communication', 'Communication', Iconsax.message_copy),
  discovery('discovery', 'Search & Discovery', Iconsax.search_normal_copy),
  sharing('sharing', 'Data Sharing', Iconsax.share_copy),
  analytics('analytics', 'Analytics & Tracking', Iconsax.chart_copy);

  final String value;
  final String displayName;
  final IconData icon;
  const PrivacyCategory(this.value, this.displayName, this.icon);

  /// Get settings keys for this category
  List<String> get settingsKeys {
    switch (this) {
      case PrivacyCategory.visibility:
        return [
          'profile_visibility',
          'show_online_status',
          'show_last_active',
          'show_game_history',
        ];
      case PrivacyCategory.communication:
        return [
          'allow_messages_from_strangers',
          'allow_friend_requests',
          'allow_game_invites',
        ];
      case PrivacyCategory.discovery:
        return [
          'appear_in_search',
          'show_in_suggestions',
          'allow_discovery_by_email',
        ];
      case PrivacyCategory.sharing:
        return [
          'share_with_partners',
          'allow_data_export',
          'marketing_communications',
        ];
      case PrivacyCategory.analytics:
        return ['usage_analytics', 'performance_tracking', 'crash_reporting'];
    }
  }
}
