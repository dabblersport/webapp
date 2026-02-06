import 'package:flutter/material.dart';

/// Comprehensive enums for social features in the Dabbler app
/// Provides type safety and consistency across social functionality

/// Types of posts that can be created
enum PostType {
  text('text', 'Text Post', Icons.text_fields),
  gameResult('game_result', 'Game Result', Icons.sports_score),
  achievement('achievement', 'Achievement', Icons.emoji_events),
  media('media', 'Media Post', Icons.photo_library),
  shared('shared', 'Shared Post', Icons.share);

  const PostType(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final IconData icon;

  /// Get PostType from string value
  static PostType? fromValue(String value) {
    for (final type in PostType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  /// Check if post type supports media
  bool get supportsMedia =>
      this == PostType.media || this == PostType.gameResult;

  /// Check if post type supports text content
  bool get supportsText => this != PostType.media;
}

/// Status of friendship between users
enum FriendshipStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Friends'),
  blocked('blocked', 'Blocked'),
  declined('declined', 'Declined');

  const FriendshipStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Get FriendshipStatus from string value
  static FriendshipStatus? fromValue(String value) {
    for (final status in FriendshipStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }

  // Convenience getters
  bool get isPending => this == FriendshipStatus.pending;
  bool get isAccepted => this == FriendshipStatus.accepted;
  bool get isBlocked => this == FriendshipStatus.blocked;
  bool get isDeclined => this == FriendshipStatus.declined;

  /// Get the color associated with this status
  Color get color {
    switch (this) {
      case FriendshipStatus.pending:
        return Colors.orange;
      case FriendshipStatus.accepted:
        return Colors.green;
      case FriendshipStatus.blocked:
        return Colors.red;
      case FriendshipStatus.declined:
        return Colors.grey;
    }
  }

  /// Get the icon associated with this status
  IconData get icon {
    switch (this) {
      case FriendshipStatus.pending:
        return Icons.schedule;
      case FriendshipStatus.accepted:
        return Icons.people;
      case FriendshipStatus.blocked:
        return Icons.block;
      case FriendshipStatus.declined:
        return Icons.close;
    }
  }
}

/// Visibility levels for posts
enum PostVisibility {
  public('public', 'Everyone', Icons.public),
  friends('friends', 'Friends Only', Icons.people),
  private('private', 'Only Me', Icons.lock),
  gameParticipants('game_participants', 'Game Participants', Icons.sports);

  const PostVisibility(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final IconData icon;

  /// Get PostVisibility from string value
  static PostVisibility? fromValue(String value) {
    for (final visibility in PostVisibility.values) {
      if (visibility.value == value) return visibility;
    }
    return null;
  }

  /// Get description for this visibility level
  String get description {
    switch (this) {
      case PostVisibility.public:
        return 'Anyone can see this post';
      case PostVisibility.friends:
        return 'Only your friends can see this post';
      case PostVisibility.private:
        return 'Only you can see this post';
      case PostVisibility.gameParticipants:
        return 'Only game participants can see this post';
    }
  }

  /// Check if visibility allows public access
  bool get isPublic => this == PostVisibility.public;

  /// Check if visibility is restricted to friends
  bool get isFriendsOnly => this == PostVisibility.friends;

  /// Check if visibility is private
  bool get isPrivate => this == PostVisibility.private;
}

/// Types of notifications that can be sent
enum NotificationType {
  friendRequest('friend_request', 'Friend Request', Colors.blue),
  friendAccepted('friend_accepted', 'Friend Accepted', Colors.green),
  postLike('post_like', 'Post Liked', Colors.red),
  postComment('post_comment', 'New Comment', Colors.orange),
  commentReply('comment_reply', 'Comment Reply', Colors.purple),
  mention('mention', 'Mentioned You', Colors.teal),
  message('message', 'New Message', Colors.indigo),
  gameInvite('game_invite', 'Game Invite', Colors.amber);

  const NotificationType(this.value, this.displayName, this.color);

  final String value;
  final String displayName;
  final Color color;

  /// Get NotificationType from string value
  static NotificationType? fromValue(String value) {
    for (final type in NotificationType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  /// Get the icon associated with this notification type
  IconData get icon {
    switch (this) {
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        return Icons.person_add;
      case NotificationType.postLike:
        return Icons.favorite;
      case NotificationType.postComment:
      case NotificationType.commentReply:
        return Icons.comment;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.gameInvite:
        return Icons.sports;
    }
  }

  /// Check if notification type requires immediate attention
  bool get isHighPriority {
    return this == NotificationType.friendRequest ||
        this == NotificationType.message ||
        this == NotificationType.gameInvite;
  }

  /// Check if notification type is social-related
  bool get isSocialNotification {
    return this == NotificationType.friendRequest ||
        this == NotificationType.friendAccepted ||
        this == NotificationType.mention;
  }

  /// Check if notification type is content-related
  bool get isContentNotification {
    return this == NotificationType.postLike ||
        this == NotificationType.postComment ||
        this == NotificationType.commentReply;
  }
}

/// Reasons for reporting content
enum ContentReportReason {
  spam('spam', 'Spam or misleading'),
  harassment('harassment', 'Harassment or bullying'),
  inappropriate('inappropriate', 'Inappropriate content'),
  fake('fake', 'False information'),
  copyright('copyright', 'Copyright violation'),
  other('other', 'Other');

  const ContentReportReason(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Get ContentReportReason from string value
  static ContentReportReason? fromValue(String value) {
    for (final reason in ContentReportReason.values) {
      if (reason.value == value) return reason;
    }
    return null;
  }

  /// Get the icon associated with this report reason
  IconData get icon {
    switch (this) {
      case ContentReportReason.spam:
        return Icons.report;
      case ContentReportReason.harassment:
        return Icons.person_off;
      case ContentReportReason.inappropriate:
        return Icons.warning;
      case ContentReportReason.fake:
        return Icons.fact_check;
      case ContentReportReason.copyright:
        return Icons.copyright;
      case ContentReportReason.other:
        return Icons.help_outline;
    }
  }

  /// Get severity level (1-5, 5 being most severe)
  int get severity {
    switch (this) {
      case ContentReportReason.spam:
        return 2;
      case ContentReportReason.harassment:
        return 5;
      case ContentReportReason.inappropriate:
        return 4;
      case ContentReportReason.fake:
        return 3;
      case ContentReportReason.copyright:
        return 3;
      case ContentReportReason.other:
        return 1;
    }
  }
}

/// User online status
enum OnlineStatus {
  online('online', 'Online', Colors.green),
  away('away', 'Away', Colors.orange),
  busy('busy', 'Busy', Colors.red),
  offline('offline', 'Offline', Colors.grey);

  const OnlineStatus(this.value, this.displayName, this.color);

  final String value;
  final String displayName;
  final Color color;

  /// Get OnlineStatus from string value
  static OnlineStatus? fromValue(String value) {
    for (final status in OnlineStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }

  /// Check if user is available for interaction
  bool get isAvailable => this == OnlineStatus.online;

  /// Check if user is completely offline
  bool get isOffline => this == OnlineStatus.offline;
}

/// Message types in chat
enum MessageType {
  text('text', 'Text Message', Icons.message),
  image('image', 'Image', Icons.image),
  video('video', 'Video', Icons.videocam),
  audio('audio', 'Audio', Icons.mic),
  file('file', 'File', Icons.attach_file),
  location('location', 'Location', Icons.location_city),
  gameInvite('game_invite', 'Game Invite', Icons.sports),
  system('system', 'System Message', Icons.info);

  const MessageType(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final IconData icon;

  /// Get MessageType from string value
  static MessageType? fromValue(String value) {
    for (final type in MessageType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  /// Check if message type supports media
  bool get isMedia =>
      this == MessageType.image ||
      this == MessageType.video ||
      this == MessageType.file;

  /// Check if message type is interactive
  bool get isInteractive => this == MessageType.gameInvite;

  /// Check if message is generated by system
  bool get isSystem => this == MessageType.system;
}

/// Status of chat messages
enum MessageStatus {
  sending('sending', 'Sending'),
  sent('sent', 'Sent'),
  delivered('delivered', 'Delivered'),
  read('read', 'Read'),
  failed('failed', 'Failed');

  const MessageStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Get MessageStatus from string value
  static MessageStatus? fromValue(String value) {
    for (final status in MessageStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }

  /// Check if message was successfully sent
  bool get isSent =>
      this == MessageStatus.sent ||
      this == MessageStatus.delivered ||
      this == MessageStatus.read;

  /// Check if message failed to send
  bool get isFailed => this == MessageStatus.failed;

  /// Check if message is in progress
  bool get isPending => this == MessageStatus.sending;
}

/// Reaction types for posts and messages
enum ReactionType {
  like('like', '👍', 'Like'),
  love('love', '❤️', 'Love'),
  laugh('laugh', '😂', 'Laugh'),
  celebrate('celebrate', '🎉', 'Celebrate'),
  support('support', '💪', 'Support'),
  funny('funny', '😂', 'Funny'),
  wow('wow', '😮', 'Wow'),
  sad('sad', '😢', 'Sad'),
  angry('angry', '😠', 'Angry'),
  fire('fire', '🔥', 'Fire'),
  trophy('trophy', '🏆', 'Trophy');

  const ReactionType(this.value, this.emoji, this.displayName);

  final String value;
  final String emoji;
  final String displayName;

  /// Get ReactionType from string value
  static ReactionType? fromValue(String value) {
    for (final type in ReactionType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  /// Check if reaction is positive
  bool get isPositive {
    return this == ReactionType.like ||
        this == ReactionType.love ||
        this == ReactionType.celebrate ||
        this == ReactionType.support ||
        this == ReactionType.funny ||
        this == ReactionType.wow;
  }

  /// Check if reaction is negative
  bool get isNegative => this == ReactionType.sad || this == ReactionType.angry;
}

/// Privacy settings levels
enum PrivacyLevel {
  public('public', 'Public'),
  friends('friends', 'Friends Only'),
  close('close', 'Close Friends'),
  private('private', 'Private');

  const PrivacyLevel(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Get PrivacyLevel from string value
  static PrivacyLevel? fromValue(String value) {
    for (final level in PrivacyLevel.values) {
      if (level.value == value) return level;
    }
    return null;
  }

  /// Get the icon associated with this privacy level
  IconData get icon {
    switch (this) {
      case PrivacyLevel.public:
        return Icons.public;
      case PrivacyLevel.friends:
        return Icons.people;
      case PrivacyLevel.close:
        return Icons.people_alt;
      case PrivacyLevel.private:
        return Icons.lock;
    }
  }

  /// Check if level allows public access
  bool get isPublic => this == PrivacyLevel.public;

  /// Check if level is restricted
  bool get isRestricted => this != PrivacyLevel.public;
}

/// Content moderation status
enum ModerationStatus {
  pending('pending', 'Under Review', Colors.orange),
  approved('approved', 'Approved', Colors.green),
  rejected('rejected', 'Rejected', Colors.red),
  flagged('flagged', 'Flagged', Colors.red),
  hidden('hidden', 'Hidden', Colors.grey);

  const ModerationStatus(this.value, this.displayName, this.color);

  final String value;
  final String displayName;
  final Color color;

  /// Get ModerationStatus from string value
  static ModerationStatus? fromValue(String value) {
    for (final status in ModerationStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }

  /// Check if content is visible to users
  bool get isVisible => this == ModerationStatus.approved;

  /// Check if content needs review
  bool get needsReview =>
      this == ModerationStatus.pending || this == ModerationStatus.flagged;
}

/// Activity types for unified activity feed - all user actions become posts
enum PostActivityType {
  originalPost('original_post', 'Posted', Icons.post_add, Colors.blue),
  comment('comment', 'Commented', Icons.comment, Colors.green),
  venueRating('venue_rating', 'Rated a venue', Icons.star_rate, Colors.amber),
  gameCreation('game_creation', 'Created a game', Icons.sports, Colors.orange),
  checkIn('check_in', 'Checked in', Icons.location_city, Colors.red),
  venueBooking(
    'venue_booking',
    'Booked a venue',
    Icons.event_available,
    Colors.purple,
  ),
  gameJoin('game_join', 'Joined a game', Icons.group_add, Colors.teal),
  achievement(
    'achievement',
    'Earned achievement',
    Icons.emoji_events,
    Colors.yellow,
  );

  const PostActivityType(this.value, this.displayName, this.icon, this.color);

  final String value;
  final String displayName;
  final IconData icon;
  final Color color;

  /// Get PostActivityType from string value
  static PostActivityType? fromValue(String value) {
    for (final type in PostActivityType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  /// Get the privacy levels this activity type supports
  List<ActivityPrivacyLevel> get supportedPrivacyLevels {
    switch (this) {
      case PostActivityType.comment:
        return [ActivityPrivacyLevel.thread]; // Comments inherit thread privacy
      case PostActivityType.venueRating:
      case PostActivityType.checkIn:
      case PostActivityType.venueBooking:
        return [ActivityPrivacyLevel.public, ActivityPrivacyLevel.friends];
      case PostActivityType.gameCreation:
      case PostActivityType.gameJoin:
      case PostActivityType.achievement:
        return ActivityPrivacyLevel.values; // All privacy levels
      case PostActivityType.originalPost:
        return [ActivityPrivacyLevel.public, ActivityPrivacyLevel.friends];
    }
  }

  /// Check if activity type can have media attachments
  bool get supportsMedia {
    return this == PostActivityType.originalPost ||
        this == PostActivityType.checkIn ||
        this == PostActivityType.achievement ||
        this == PostActivityType.venueRating;
  }

  /// Check if activity type supports custom text content
  bool get supportsCustomContent {
    return this == PostActivityType.originalPost ||
        this == PostActivityType.comment ||
        this == PostActivityType.checkIn ||
        this == PostActivityType.venueRating;
  }

  /// Get default content template for this activity type
  String getContentTemplate(Map<String, String> params) {
    switch (this) {
      case PostActivityType.originalPost:
        return params['content'] ?? '';
      case PostActivityType.comment:
        return params['content'] ?? '';
      case PostActivityType.venueRating:
        return 'Rated ${params['venueName']} ${params['rating']}/5 stars${params['review'] != null ? ': ${params['review']}' : ''}';
      case PostActivityType.gameCreation:
        return 'Created a new ${params['gameType']} game at ${params['venueName']}';
      case PostActivityType.checkIn:
        return 'Checked in at ${params['venueName']}${params['note'] != null ? ': ${params['note']}' : ''}';
      case PostActivityType.venueBooking:
        return 'Booked ${params['venueName']} for ${params['date']}';
      case PostActivityType.gameJoin:
        return 'Joined ${params['gameType']} game at ${params['venueName']}';
      case PostActivityType.achievement:
        return 'Earned the "${params['achievementName']}" achievement!';
    }
  }
}

/// Privacy levels specific to activity posts
enum ActivityPrivacyLevel {
  public('public', 'Public', Icons.public, 'Everyone can see this activity'),
  friends(
    'friends',
    'Friends',
    Icons.people,
    'Only friends can see this activity',
  ),
  thread(
    'thread',
    'Thread',
    Icons.forum,
    'Inherits privacy from original post/thread',
  );

  const ActivityPrivacyLevel(
    this.value,
    this.displayName,
    this.icon,
    this.description,
  );

  final String value;
  final String displayName;
  final IconData icon;
  final String description;

  /// Get ActivityPrivacyLevel from string value
  static ActivityPrivacyLevel? fromValue(String value) {
    for (final level in ActivityPrivacyLevel.values) {
      if (level.value == value) return level;
    }
    return null;
  }

  /// Convert to PostVisibility for backwards compatibility
  PostVisibility toPostVisibility() {
    switch (this) {
      case ActivityPrivacyLevel.public:
        return PostVisibility.public;
      case ActivityPrivacyLevel.friends:
        return PostVisibility.friends;
      case ActivityPrivacyLevel.thread:
        return PostVisibility.friends; // Default fallback
    }
  }
}
