// KAN-1046 (NOTIF-2): the Android notification channels, one per
// `notification_channels` row (KAN-1045), each inside its group. The Android
// channel id is the row's `key` (the push's `data.channel_key`). This table
// mirrors the database; test/services/notifications/push_channel_table_test.dart
// checks it against a snapshot of the rows so drift is caught.
//
// Kept plugin-free so every rule is unit-tested.

/// Android importance, as the plugin's levels (kept as an enum here so the
/// rules stay plugin-free).
enum PushImportance {
  min,
  low,
  defaultLevel,
  high,
  max;

  /// `notification_channels.android_importance` → level; unknown → default.
  static PushImportance parse(String? raw) => switch (raw) {
    'min' => min,
    'low' => low,
    'high' => high,
    'max' => max,
    _ => defaultLevel,
  };

  /// Low and min channels are silent: no sound, no vibration.
  bool get sounds => this != low && this != min;
}

/// One row of `notification_channels`.
class PushChannelSpec {
  const PushChannelSpec(
    this.key,
    this.group,
    this.labelEn,
    this.labelAr,
    this.importance,
  );

  /// The channel_key, also the Android channel id.
  final String key;
  final String group;
  final String labelEn;
  final String labelAr;
  final PushImportance importance;

  /// The label in [languageCode] (`ar` → Arabic, else English).
  String label(String languageCode) =>
      languageCode.startsWith('ar') ? labelAr : labelEn;
}

abstract final class PushChannelTable {
  /// The groups, in `sort_order`.
  static const List<String> groups = <String>[
    'games',
    'meetups',
    'activities',
    'messages',
    'social',
    'booking',
    'security',
    'system',
  ];

  /// The 20 channels, in `sort_order`.
  static const List<PushChannelSpec> channels = <PushChannelSpec>[
    PushChannelSpec(
      'games.invites',
      'games',
      'Invites & join requests',
      'الدعوات وطلبات الانضمام',
      PushImportance.high,
    ),
    PushChannelSpec(
      'games.reminders',
      'games',
      'Reminders',
      'التذكيرات',
      PushImportance.max,
    ),
    PushChannelSpec(
      'games.changes',
      'games',
      'Changes & cancellations',
      'التغييرات والإلغاءات',
      PushImportance.high,
    ),
    PushChannelSpec(
      'games.roster',
      'games',
      'Roster updates',
      'تحديثات قائمة اللاعبين',
      PushImportance.defaultLevel,
    ),
    PushChannelSpec(
      'meetups.invites',
      'meetups',
      'Invites & RSVPs',
      'الدعوات وتأكيدات الحضور',
      PushImportance.high,
    ),
    PushChannelSpec(
      'meetups.reminders',
      'meetups',
      'Reminders',
      'التذكيرات',
      PushImportance.max,
    ),
    PushChannelSpec(
      'meetups.changes',
      'meetups',
      'Changes & cancellations',
      'التغييرات والإلغاءات',
      PushImportance.high,
    ),
    PushChannelSpec(
      'activities.checkin',
      'activities',
      'Check-in',
      'تسجيل الحضور',
      PushImportance.max,
    ),
    PushChannelSpec(
      'activities.attendance',
      'activities',
      'Attendance',
      'الحضور',
      PushImportance.defaultLevel,
    ),
    PushChannelSpec(
      'activities.results',
      'activities',
      'Results & ratings',
      'النتائج والتقييمات',
      PushImportance.defaultLevel,
    ),
    PushChannelSpec(
      'messages.direct',
      'messages',
      'Direct chats',
      'المحادثات المباشرة',
      PushImportance.max,
    ),
    PushChannelSpec(
      'messages.threads',
      'messages',
      'Game & meet-up chats',
      'محادثات المباريات واللقاءات',
      PushImportance.high,
    ),
    PushChannelSpec(
      'social.follows',
      'social',
      'New followers',
      'المتابعون الجدد',
      PushImportance.defaultLevel,
    ),
    PushChannelSpec(
      'social.reactions',
      'social',
      'Likes & comments',
      'الإعجابات والتعليقات',
      PushImportance.defaultLevel,
    ),
    PushChannelSpec(
      'social.mentions',
      'social',
      'Mentions',
      'الإشارات',
      PushImportance.high,
    ),
    PushChannelSpec(
      'booking.confirmations',
      'booking',
      'Confirmations & changes',
      'التأكيدات والتغييرات',
      PushImportance.high,
    ),
    PushChannelSpec(
      'booking.payments',
      'booking',
      'Payments',
      'المدفوعات',
      PushImportance.high,
    ),
    PushChannelSpec(
      'security.alerts',
      'security',
      'Sign-in & security alerts',
      'تنبيهات تسجيل الدخول والأمان',
      PushImportance.max,
    ),
    PushChannelSpec(
      'system.announcements',
      'system',
      'Announcements',
      'الإعلانات',
      PushImportance.defaultLevel,
    ),
    PushChannelSpec(
      'system.rewards',
      'system',
      'Rewards & badges',
      'المكافآت والشارات',
      PushImportance.defaultLevel,
    ),
  ];

  static final Map<String, PushChannelSpec> _byKey = {
    for (final c in channels) c.key: c,
  };

  /// The channel for [key], or null when the table does not have it.
  static PushChannelSpec? byKey(String? key) =>
      key == null ? null : _byKey[key];

  /// The pre-KAN-1046 flat category channels (`dabbler_<category>`), deleted
  /// once the grouped ones exist, and the channel_key a push still naming
  /// one lands on when its data has no `channel_key`.
  static const Map<String, String> legacy = <String, String>{
    'dabbler_social': 'social.reactions',
    'dabbler_messages': 'messages.direct',
    'dabbler_games': 'games.invites',
    'dabbler_meetups': 'meetups.invites',
    'dabbler_activities': 'activities.checkin',
    'dabbler_system': 'system.announcements',
    'dabbler_security': 'security.alerts',
    'dabbler_booking': 'booking.confirmations',
  };
}
