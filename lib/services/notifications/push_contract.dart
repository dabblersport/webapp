// KAN-992 (W1-F6): what the device does with a push, as pure rules over the
// FCM `data` map that send-push-notification v14 sends (KAN-979, comment
// 16428): `kind_key`, `entity_type`, `entity_id`, `notification_id`,
// `dedupe_key`, `category` (the iOS category id) and `delivery_mode`
// (`alert` | `silent`).
//
// Kept free of plugins so every rule is unit-tested: the Android channel, the
// iOS category and its actions, the open-conversation rule, the badge and the
// tap's route or target state.

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_target_states.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Android importance, as the plugin's levels (kept as an enum here so the
/// rules stay plugin-free).
enum PushImportance { low, defaultLevel, high, max }

/// One Android notification channel.
class PushChannel {
  const PushChannel(
    this.id,
    this.name,
    this.description, {
    this.importance = PushImportance.high,
    this.sound = true,
  });

  final String id;
  final String name;
  final String description;
  final PushImportance importance;
  final bool sound;
}

/// The channels KAN-979 sends to: one per category, `dabbler_quiet` for every
/// quiet-hours push (low, no sound) and `dabbler_default` for direct calls.
/// Social and messages are not urgent (I-3); events, security and the default
/// are.
abstract final class PushChannels {
  static const String quiet = 'dabbler_quiet';
  static const String fallback = 'dabbler_default';

  static const List<PushChannel> all = <PushChannel>[
    PushChannel(
      'dabbler_social',
      'Social',
      'Follows, likes, comments and mentions',
      importance: PushImportance.defaultLevel,
    ),
    PushChannel(
      'dabbler_messages',
      'Messages',
      'Chats and game and meet-up threads',
    ),
    PushChannel(
      'dabbler_games',
      'Games',
      'Invites, changes, reminders and cancellations',
      importance: PushImportance.max,
    ),
    PushChannel(
      'dabbler_meetups',
      'Meet-ups',
      'Invites, changes, reminders and cancellations',
      importance: PushImportance.max,
    ),
    PushChannel(
      'dabbler_activities',
      'Check-in and results',
      'Check-in, attendance, results and ratings',
      importance: PushImportance.high,
    ),
    PushChannel(
      'dabbler_system',
      'Dabbler',
      'Announcements and rewards',
      importance: PushImportance.defaultLevel,
    ),
    PushChannel(
      'dabbler_security',
      'Account security',
      'Sign-ins and account changes',
      importance: PushImportance.max,
    ),
    PushChannel(
      'dabbler_booking',
      'Bookings',
      'Bookings and payments',
      importance: PushImportance.high,
    ),
    PushChannel(
      quiet,
      'Quiet hours',
      'Delivered silently during quiet hours',
      importance: PushImportance.low,
      sound: false,
    ),
    PushChannel(
      fallback,
      'General',
      'General notifications',
      importance: PushImportance.max,
    ),
  ];

  static final Set<String> _ids = {for (final c in all) c.id};

  static PushChannel byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.last);

  /// The channel a push belongs to: the server's channel when it names a
  /// known one, `dabbler_quiet` for a silent push, else by the kind's
  /// category, else the default.
  static String of(Map<String, dynamic> data, {String? serverChannelId}) {
    for (final raw in [
      serverChannelId,
      data['android_channel_id'],
      data['channel_id'],
    ]) {
      if (raw is String && _ids.contains(raw)) return raw;
    }
    if (data['delivery_mode'] == 'silent') return quiet;
    final kind = data['kind_key'];
    final spec = kind is String ? NotificationKinds.of(kind) : null;
    if (spec == null) return fallback;
    final id = 'dabbler_${spec.category.name}';
    return _ids.contains(id) ? id : fallback;
  }
}

/// A notification action button.
enum PushActionId {
  reply('REPLY'),
  markRead('MARK_READ'),
  going('GOING'),
  notGoing('NOT_GOING'),
  cancelPlace('CANCEL_PLACE');

  const PushActionId(this.wire);

  /// The action identifier on both platforms (iOS UNNotificationAction,
  /// Android AndroidNotificationAction).
  final String wire;

  static PushActionId? parse(String? wire) {
    for (final a in values) {
      if (a.wire == wire) return a;
    }
    return null;
  }

  /// Reply takes text; Cancel my place asks for confirmation in the app
  /// (G-14), so it opens it.
  bool get needsText => this == reply;
  bool get opensApp => this == cancelPlace;
}

/// The iOS notification categories (also `data.category` for Android).
abstract final class PushCategories {
  static const String message = 'DABBLER_MESSAGE';
  static const String rsvp = 'DABBLER_RSVP';
  static const String waitlist = 'DABBLER_WAITLIST';
  static const String security = 'DABBLER_SECURITY';
  static const String fallback = 'DABBLER_DEFAULT';

  static const Map<String, List<PushActionId>> actions = {
    message: [PushActionId.reply, PushActionId.markRead],
    rsvp: [PushActionId.going, PushActionId.notGoing],
    waitlist: [PushActionId.cancelPlace],
    security: <PushActionId>[],
    fallback: [PushActionId.markRead],
  };

  /// The push's category: the server's when known, else from its kind.
  static String of(Map<String, dynamic> data) {
    final raw = data['category'];
    if (raw is String && actions.containsKey(raw)) return raw;
    final kind = data['kind_key'];
    if (kind is! String) return fallback;
    if (kind.startsWith('security.')) return security;
    return switch (NotificationKinds.canonical(kind)) {
      'message.received' => message,
      'meetup.confirm_attendance' => rsvp,
      'game.waitlist_promoted' => waitlist,
      _ => fallback,
    };
  }

  static List<PushActionId> actionsOf(Map<String, dynamic> data) =>
      actions[of(data)] ?? const <PushActionId>[];

  /// G-08: a security push never shows device or city on the lock screen.
  static bool hidesPreview(Map<String, dynamic> data) => of(data) == security;
}

/// The chat open on screen, as the router names it.
class OpenChat {
  const OpenChat({this.conversationId, this.gameId, this.meetupId});

  final String? conversationId;
  final String? gameId;
  final String? meetupId;

  static const OpenChat none = OpenChat();

  /// The chat a router location shows, or [none]: a DM thread
  /// (`/messaging/thread/:id`), a game chat (`/messaging/game/:id`) or a
  /// meet-up chat (`/meetups/:id/chat`).
  static OpenChat fromLocation(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    final s = path.split('/').where((p) => p.isNotEmpty).toList();
    if (s.length >= 3 && s[0] == 'messaging' && s[1] == 'thread') {
      return OpenChat(conversationId: s[2]);
    }
    if (s.length >= 3 && s[0] == 'messaging' && s[1] == 'game') {
      return OpenChat(gameId: s[2]);
    }
    if (s.length >= 3 && s[0] == 'meetups' && s[2] == 'chat') {
      return OpenChat(meetupId: s[1]);
    }
    return none;
  }

  bool get isNone =>
      conversationId == null && gameId == null && meetupId == null;

  /// Whether a message push belongs to this chat.
  bool shows(Map<String, dynamic> data) {
    if (isNone) return false;
    bool eq(String? mine, Object? theirs) =>
        mine != null && theirs is String && theirs == mine;
    return eq(conversationId, data['conversation_id']) ||
        eq(gameId, data['game_id']) ||
        eq(meetupId, data['meetup_id']) ||
        (data['entity_type'] == 'conversation' &&
            eq(conversationId, data['entity_id']));
  }
}

/// Foreground: whether the system alert is skipped. A message for the chat
/// already open on screen shows nothing (KAN-992), and when the in-app
/// banner (W1-F7) presents foreground rows the system alert steps aside for
/// it (one de-dup key, never both).
bool suppressForegroundAlert(
  Map<String, dynamic> data, {
  required OpenChat openChat,
  bool inAppBannerShows = false,
}) {
  final kind = data['kind_key'];
  final isMessage =
      PushCategories.of(data) == PushCategories.message ||
      (kind is String && kind.startsWith('message.'));
  if (isMessage && openChat.shows(data)) return true;
  return inAppBannerShows;
}

/// The de-dup key shared with the in-app banner: the row's `dedupe_key`, else
/// its id.
String? pushDedupeKey(Map<String, dynamic> data) {
  for (final k in const ['dedupe_key', 'notification_id']) {
    final v = data[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

/// The app-icon badge a push carries (the server's unread count), from the
/// data, the APNs badge or Android's notification count; null when absent.
int? pushBadge(
  Map<String, dynamic> data, {
  String? appleBadge,
  int? androidCount,
}) {
  for (final raw in [data['badge'], appleBadge, androidCount]) {
    if (raw is int) return raw < 0 ? 0 : raw;
    if (raw is String) {
      final n = int.tryParse(raw);
      if (n != null) return n < 0 ? 0 : n;
    }
  }
  return null;
}

/// Where a tapped push goes.
class PushTarget {
  const PushTarget.route(this.route) : state = NotifTargetState.available;
  const PushTarget.unavailable(this.state) : route = null;
  const PushTarget.none() : route = null, state = NotifTargetState.available;

  final String? route;
  final NotifTargetState state;

  bool get opens => route != null;
  bool get showsSheet => state != NotifTargetState.available;
}

/// The push as an inbox row, for the registry's route and target rules.
AppNotification pushAsNotification(
  Map<String, dynamic> data, {
  DateTime? now,
}) => AppNotification(
  id: (data['notification_id'] as String?) ?? '',
  toUserId: '',
  kindKey: (data['kind_key'] as String?) ?? '',
  title: '',
  actionRoute: data['action_route'] as String?,
  payload: data,
  createdAt: now ?? DateTime.now(),
);

/// A tap: the target state from the row's facts (W1-F3's sheet when it cannot
/// open), else the server's `action_route`, else the registry's route for the
/// kind, else the meetup fallback.
PushTarget pushTarget(
  Map<String, dynamic> data, {
  required DateTime now,
  bool meetupsEnabled = true,
}) {
  final state = notifTargetStateOf(pushAsNotification(data, now: now), now);
  if (state != NotifTargetState.available) return PushTarget.unavailable(state);
  final direct = data['action_route'];
  if (direct is String && direct.trim().isNotEmpty) {
    return PushTarget.route(direct);
  }
  final kind = data['kind_key'];
  if (kind is! String) return const PushTarget.none();
  final route = NotificationKinds.route(
    kind,
    data,
    meetupsEnabled: meetupsEnabled,
  );
  if (route != null) return PushTarget.route(route);
  if (meetupsEnabled && NotificationKinds.isMeetupKind(kind)) {
    return const PushTarget.route(RoutePaths.meetups);
  }
  return const PushTarget.none();
}
