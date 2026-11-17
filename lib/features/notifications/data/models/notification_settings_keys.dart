/// KAN-991: the wire vocabulary of `public.notification_settings` and its RPCs
/// (KAN-975, `docs/SCHEMA.md` section 17). Plain constants, so the model, the
/// repository, the sync handler and the screen spell every key one way.
library;

import 'package:dabbler/features/notifications/domain/notification_kinds.dart';

/// `category_prefs` keys the settings screen shows, in screen order.
/// `booking` exists on the server but is hidden (F-12); `security` has no key
/// (always on).
abstract final class NotifCategoryKey {
  static const String social = 'social';
  static const String messages = 'messages';
  static const String games = 'games';
  static const String meetups = 'meetups';

  /// "Rewards & announcements" in the UI.
  static const String system = 'system';
  static const String booking = 'booking';

  static const List<String> shown = <String>[
    social,
    messages,
    games,
    meetups,
    system,
  ];
  static const List<String> all = <String>[...shown, booking];
}

/// The two channels of a category.
abstract final class NotifChannel {
  static const String inApp = 'in_app';
  static const String push = 'push';
}

/// `reminder_rungs` groups and rungs (F-4, I-5: four rungs for both groups).
abstract final class NotifRung {
  static const String going = 'going';
  static const String interested = 'interested';
  static const List<String> groups = <String>[going, interested];

  static const String day = '24h';
  static const String morning = '09:00';
  static const String twoHours = '2h';
  static const String thirtyMinutes = '30m';
  static const List<String> rungs = <String>[
    day,
    morning,
    twoHours,
    thirtyMinutes,
  ];
}

/// `message_preview` values (F-2).
abstract final class NotifPreview {
  static const String senderAndMessage = 'sender_and_message';
  static const String senderOnly = 'sender_only';
}

/// The quiet window used when quiet hours are switched on with none set
/// (F-14: 00:00 – 08:00), in minutes after local midnight.
const int kQuietDefaultStartMin = 0;
const int kQuietDefaultEndMin = 8 * 60;

/// The table defaults of `reminder_rungs`: every rung on.
const Map<String, Map<String, bool>> kDefaultReminderRungs = {
  NotifRung.going: {
    NotifRung.day: true,
    NotifRung.morning: true,
    NotifRung.twoHours: true,
    NotifRung.thirtyMinutes: true,
  },
  NotifRung.interested: {
    NotifRung.day: true,
    NotifRung.morning: true,
    NotifRung.twoHours: true,
    NotifRung.thirtyMinutes: true,
  },
};

/// The table defaults of `category_prefs`: every category on, both channels.
const Map<String, Map<String, bool>> kDefaultCategoryPrefs = {
  NotifCategoryKey.social: {NotifChannel.inApp: true, NotifChannel.push: true},
  NotifCategoryKey.messages: {
    NotifChannel.inApp: true,
    NotifChannel.push: true,
  },
  NotifCategoryKey.games: {NotifChannel.inApp: true, NotifChannel.push: true},
  NotifCategoryKey.meetups: {NotifChannel.inApp: true, NotifChannel.push: true},
  NotifCategoryKey.system: {NotifChannel.inApp: true, NotifChannel.push: true},
  NotifCategoryKey.booking: {NotifChannel.inApp: true, NotifChannel.push: true},
};

/// Whether [kindKey] may never be muted: a security kind, or one the registry
/// marks unmutable. The server rejects such a mute with 22023; the client
/// refuses it first (SET-13).
bool notificationKindIsUnmutable(String kindKey) {
  if (kindKey.startsWith('security.')) return true;
  final NotificationKindSpec? spec = NotificationKinds.of(kindKey);
  if (spec == null) return false;
  return spec.category == NotificationCategory.security || !spec.canMute;
}
