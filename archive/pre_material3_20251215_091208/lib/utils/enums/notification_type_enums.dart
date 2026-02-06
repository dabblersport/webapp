/// Notification type enum definitions with configuration and preferences
library;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Enum representing different types of notifications in the app
enum NotificationType {
  gameInvite('game_invite', 'Game Invitations', true),
  message('message', 'Messages', true),
  friendRequest('friend_request', 'Friend Requests', true),
  gameReminder('game_reminder', 'Game Reminders', true),
  systemUpdate('system_update', 'System Updates', false),
  marketing('marketing', 'Marketing', false);

  final String value;
  final String displayName;
  final bool defaultEnabled;
  const NotificationType(this.value, this.displayName, this.defaultEnabled);

  /// Create NotificationType from string value
  static NotificationType fromString(String value) =>
      NotificationType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => NotificationType.systemUpdate,
      );

  /// Get icon for this notification type
  IconData get icon {
    switch (this) {
      case NotificationType.gameInvite:
        return Iconsax.game_copy;
      case NotificationType.message:
        return Iconsax.message_copy;
      case NotificationType.friendRequest:
        return Iconsax.user_add_copy;
      case NotificationType.gameReminder:
        return Iconsax.clock_copy;
      case NotificationType.systemUpdate:
        return Iconsax.setting_2_copy;
      case NotificationType.marketing:
        return Iconsax.notification_copy;
    }
  }

  /// Get color for this notification type
  Color get color {
    switch (this) {
      case NotificationType.gameInvite:
        return Colors.blue;
      case NotificationType.message:
        return Colors.green;
      case NotificationType.friendRequest:
        return Colors.orange;
      case NotificationType.gameReminder:
        return Colors.purple;
      case NotificationType.systemUpdate:
        return Colors.grey;
      case NotificationType.marketing:
        return Colors.pink;
    }
  }

  /// Get description for this notification type
  String get description {
    switch (this) {
      case NotificationType.gameInvite:
        return 'Notifications when someone invites you to join a game';
      case NotificationType.message:
        return 'New messages from other users';
      case NotificationType.friendRequest:
        return 'Someone wants to be your friend';
      case NotificationType.gameReminder:
        return 'Reminders about upcoming games you\'ve joined';
      case NotificationType.systemUpdate:
        return 'Important updates about the app and your account';
      case NotificationType.marketing:
        return 'Promotional content and special offers';
    }
  }

  /// Get priority level for this notification type
  NotificationPriority get priority {
    switch (this) {
      case NotificationType.gameInvite:
        return NotificationPriority.high;
      case NotificationType.message:
        return NotificationPriority.high;
      case NotificationType.friendRequest:
        return NotificationPriority.medium;
      case NotificationType.gameReminder:
        return NotificationPriority.high;
      case NotificationType.systemUpdate:
        return NotificationPriority.medium;
      case NotificationType.marketing:
        return NotificationPriority.low;
    }
  }

  /// Check if this notification type can be disabled
  bool get canBeDisabled {
    switch (this) {
      case NotificationType.systemUpdate:
        return false; // System updates are mandatory
      default:
        return true;
    }
  }

  /// Get delivery methods available for this notification type
  List<NotificationDeliveryMethod> get availableDeliveryMethods {
    switch (this) {
      case NotificationType.gameInvite:
        return [
          NotificationDeliveryMethod.push,
          NotificationDeliveryMethod.email,
        ];
      case NotificationType.message:
        return [
          NotificationDeliveryMethod.push,
          NotificationDeliveryMethod.email,
        ];
      case NotificationType.friendRequest:
        return [
          NotificationDeliveryMethod.push,
          NotificationDeliveryMethod.email,
        ];
      case NotificationType.gameReminder:
        return [
          NotificationDeliveryMethod.push,
          NotificationDeliveryMethod.email,
          NotificationDeliveryMethod.sms,
        ];
      case NotificationType.systemUpdate:
        return [
          NotificationDeliveryMethod.push,
          NotificationDeliveryMethod.inApp,
        ];
      case NotificationType.marketing:
        return [
          NotificationDeliveryMethod.email,
          NotificationDeliveryMethod.push,
        ];
    }
  }

  /// Get timing options for this notification type
  List<NotificationTiming> get availableTimings {
    switch (this) {
      case NotificationType.gameInvite:
        return [NotificationTiming.immediate];
      case NotificationType.message:
        return [NotificationTiming.immediate];
      case NotificationType.friendRequest:
        return [NotificationTiming.immediate];
      case NotificationType.gameReminder:
        return [
          NotificationTiming.immediate,
          NotificationTiming.fifteenMinutes,
          NotificationTiming.oneHour,
          NotificationTiming.oneDay,
        ];
      case NotificationType.systemUpdate:
        return [NotificationTiming.immediate];
      case NotificationType.marketing:
        return [
          NotificationTiming.weekly,
          NotificationTiming.monthly,
          NotificationTiming.never,
        ];
    }
  }

  /// Generate a settings tile widget for this notification type
  Widget toSettingsTile({
    required bool enabled,
    required VoidCallback onToggle,
    bool showDescription = true,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color),
      ),
      title: Text(displayName),
      subtitle: showDescription ? Text(description) : null,
      trailing: Switch(
        value: enabled,
        onChanged: canBeDisabled ? (_) => onToggle() : null,
      ),
      onTap: canBeDisabled ? onToggle : null,
    );
  }

  /// Get all notification types that are essential
  static List<NotificationType> get essentialTypes =>
      NotificationType.values.where((type) => !type.canBeDisabled).toList();

  /// Get all notification types that can be customized
  static List<NotificationType> get customizableTypes =>
      NotificationType.values.where((type) => type.canBeDisabled).toList();

  /// Get default enabled notification types
  static List<NotificationType> get defaultEnabledTypes =>
      NotificationType.values.where((type) => type.defaultEnabled).toList();
}

/// Enum representing notification priority levels
enum NotificationPriority {
  low('low', 'Low Priority', Colors.grey),
  medium('medium', 'Medium Priority', Colors.orange),
  high('high', 'High Priority', Colors.red);

  final String value;
  final String displayName;
  final Color color;
  const NotificationPriority(this.value, this.displayName, this.color);

  /// Get importance level for Android notifications
  int get androidImportance {
    switch (this) {
      case NotificationPriority.low:
        return 2; // IMPORTANCE_LOW
      case NotificationPriority.medium:
        return 3; // IMPORTANCE_DEFAULT
      case NotificationPriority.high:
        return 4; // IMPORTANCE_HIGH
    }
  }

  /// Get sound setting for this priority
  bool get hasSound {
    return this != NotificationPriority.low;
  }

  /// Get vibration setting for this priority
  bool get hasVibration {
    return this == NotificationPriority.high;
  }
}

/// Enum representing different delivery methods for notifications
enum NotificationDeliveryMethod {
  push('push', 'Push Notifications', Iconsax.notification_copy),
  email('email', 'Email', Iconsax.sms_copy),
  sms('sms', 'SMS', Iconsax.message_copy),
  inApp('in_app', 'In-App', Iconsax.mobile_copy);

  final String value;
  final String displayName;
  final IconData icon;
  const NotificationDeliveryMethod(this.value, this.displayName, this.icon);

  /// Get description for this delivery method
  String get description {
    switch (this) {
      case NotificationDeliveryMethod.push:
        return 'Get notifications on your device';
      case NotificationDeliveryMethod.email:
        return 'Receive notifications via email';
      case NotificationDeliveryMethod.sms:
        return 'Get notifications via text message';
      case NotificationDeliveryMethod.inApp:
        return 'See notifications only when using the app';
    }
  }

  /// Check if this delivery method requires additional permissions
  bool get requiresPermission {
    switch (this) {
      case NotificationDeliveryMethod.push:
        return true;
      case NotificationDeliveryMethod.sms:
        return true;
      default:
        return false;
    }
  }
}

/// Enum representing notification timing options
enum NotificationTiming {
  immediate('immediate', 'Immediately'),
  fifteenMinutes('15_minutes', '15 minutes before'),
  thirtyMinutes('30_minutes', '30 minutes before'),
  oneHour('1_hour', '1 hour before'),
  oneDay('1_day', '1 day before'),
  weekly('weekly', 'Weekly summary'),
  monthly('monthly', 'Monthly summary'),
  never('never', 'Never');

  final String value;
  final String displayName;
  const NotificationTiming(this.value, this.displayName);

  /// Get duration offset for this timing
  Duration? get offset {
    switch (this) {
      case NotificationTiming.immediate:
        return Duration.zero;
      case NotificationTiming.fifteenMinutes:
        return const Duration(minutes: 15);
      case NotificationTiming.thirtyMinutes:
        return const Duration(minutes: 30);
      case NotificationTiming.oneHour:
        return const Duration(hours: 1);
      case NotificationTiming.oneDay:
        return const Duration(days: 1);
      case NotificationTiming.weekly:
        return const Duration(days: 7);
      case NotificationTiming.monthly:
        return const Duration(days: 30);
      case NotificationTiming.never:
        return null;
    }
  }

  /// Check if this timing is for reminders (has an offset)
  bool get isReminder => offset != null && offset! > Duration.zero;
}

/// Enum representing notification categories for grouping
enum NotificationCategory {
  social('social', 'Social', Iconsax.people_copy, [
    NotificationType.friendRequest,
    NotificationType.message,
  ]),
  gaming('gaming', 'Gaming', Iconsax.game_copy, [
    NotificationType.gameInvite,
    NotificationType.gameReminder,
  ]),
  system('system', 'System', Iconsax.setting_2_copy, [
    NotificationType.systemUpdate,
  ]),
  promotional('promotional', 'Promotional', Iconsax.ticket_copy, [
    NotificationType.marketing,
  ]);

  final String value;
  final String displayName;
  final IconData icon;
  final List<NotificationType> types;
  const NotificationCategory(
    this.value,
    this.displayName,
    this.icon,
    this.types,
  );

  /// Get color for this category
  Color get color {
    switch (this) {
      case NotificationCategory.social:
        return Colors.blue;
      case NotificationCategory.gaming:
        return Colors.green;
      case NotificationCategory.system:
        return Colors.grey;
      case NotificationCategory.promotional:
        return Colors.orange;
    }
  }

  /// Check if all notifications in this category are enabled
  bool areAllEnabled(Map<NotificationType, bool> settings) {
    return types.every((type) => settings[type] ?? type.defaultEnabled);
  }

  /// Enable/disable all notifications in this category
  Map<NotificationType, bool> toggleAll(
    Map<NotificationType, bool> currentSettings,
    bool enabled,
  ) {
    final newSettings = Map<NotificationType, bool>.from(currentSettings);
    for (final type in types) {
      if (type.canBeDisabled) {
        newSettings[type] = enabled;
      }
    }
    return newSettings;
  }
}
