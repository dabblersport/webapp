/// KAN-993: when a notification that arrives while the app is open shows an
/// in-app pop-up, as one pure function so every rule is tested alone.
library;

import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings_keys.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Why a pop-up is (not) shown.
enum NotificationPopupDecision {
  show,

  /// The app is in the background (the push shows it there).
  background,

  /// A kind whose cards are hidden (booking and payment, F-12).
  hiddenKind,

  /// The row arrived already read.
  alreadyRead,

  /// The user is on the Notifications screen: the new row is in front of them.
  onNotificationsScreen,

  /// The screen the row opens is the one already open.
  targetOpen,

  /// A message for the conversation that is open.
  conversationOpen,

  /// The kind is muted ("Turn off notifications like this").
  muted,

  /// The category's in-app switch is off.
  categoryOff,

  /// Quiet hours: pushes arrive silently, so the pop-up stays silent too,
  /// except for kinds that break through (event updates, security).
  quietHours,
}

/// The route a row opens: its `action_route`, one embedded in its context,
/// or the registry's route builder (the same order as the inbox row).
String? notificationPopupRoute(AppNotification n) {
  final String? direct = n.actionRoute;
  if (direct != null && direct.trim().isNotEmpty) return direct.trim();
  final Map<String, dynamic>? ctx = n.payload;
  final Object? embedded = ctx?['action_route'];
  if (embedded is String && embedded.trim().isNotEmpty) return embedded.trim();
  return NotificationKinds.route(n.kindKey, ctx);
}

String _path(String location) {
  final Uri? u = Uri.tryParse(location);
  final String p = u?.path ?? location;
  return p.length > 1 && p.endsWith('/') ? p.substring(0, p.length - 1) : p;
}

/// Whether [minute] (after local midnight) is inside the quiet window of [s]
/// (end exclusive, may cross midnight).
bool notificationInQuietHours(NotificationSettings s, int minute) {
  final int? start = s.quietStartMin;
  final int? end = s.quietEndMin;
  if (start == null || end == null || start == end) return false;
  return start < end
      ? minute >= start && minute < end
      : minute >= start || minute < end;
}

/// Whether the in-app switch of [n]'s category is on in [s]. Security is
/// always on; an activity kind follows Games or Meetups by its entity.
bool notificationInAppOn(NotificationSettings s, AppNotification n) {
  final NotificationKindSpec? spec = NotificationKinds.of(n.kindKey);
  if (spec == null) return true;
  if (spec.category == NotificationCategory.security) return true;
  if (spec.category == NotificationCategory.booking) {
    return s.categoryOn(NotifCategoryKey.booking, NotifChannel.inApp);
  }
  final String key = switch (spec.chipFor(n.payload)) {
    NotificationChip.social => NotifCategoryKey.social,
    NotificationChip.messages => NotifCategoryKey.messages,
    NotificationChip.games => NotifCategoryKey.games,
    NotificationChip.meetups => NotifCategoryKey.meetups,
    _ => NotifCategoryKey.system,
  };
  return s.categoryOn(key, NotifChannel.inApp);
}

/// The decision for [n], arriving at [now], with the app showing [location]
/// (a GoRouter location such as `/messaging/thread/c1`).
NotificationPopupDecision decideNotificationPopup({
  required AppNotification n,
  required String location,
  required DateTime now,
  required bool foreground,
  NotificationSettings? settings,
}) {
  if (!foreground) return NotificationPopupDecision.background;
  if (!NotificationKinds.isShown(n.kindKey)) {
    return NotificationPopupDecision.hiddenKind;
  }
  if (n.isRead) return NotificationPopupDecision.alreadyRead;
  final String here = _path(location);
  if (here == RoutePaths.notifications ||
      here.startsWith('${RoutePaths.notifications}/')) {
    return NotificationPopupDecision.onNotificationsScreen;
  }
  final NotificationKindSpec? spec = NotificationKinds.of(n.kindKey);
  if (spec?.category == NotificationCategory.messages ||
      n.kindKey.startsWith('message.')) {
    final Map<String, dynamic> ctx = n.payload ?? const <String, dynamic>{};
    final Object? conversation = ctx['conversation_id'];
    final Object? game = ctx['game_id'];
    if ((conversation is String && here == '/messaging/thread/$conversation') ||
        (game is String && here == '/messaging/game/$game')) {
      return NotificationPopupDecision.conversationOpen;
    }
  }
  final String? route = notificationPopupRoute(n);
  if (route != null && _path(route) == here) {
    return NotificationPopupDecision.targetOpen;
  }
  final bool security = spec?.category == NotificationCategory.security;
  if (settings != null && !security) {
    final String canonical = NotificationKinds.canonical(n.kindKey);
    if (settings.isKindMuted(n.kindKey) || settings.isKindMuted(canonical)) {
      return NotificationPopupDecision.muted;
    }
    if (!notificationInAppOn(settings, n)) {
      return NotificationPopupDecision.categoryOff;
    }
    final bool breaksQuiet = spec?.breaksQuiet ?? false;
    final DateTime local = now.toLocal();
    if (!breaksQuiet &&
        notificationInQuietHours(settings, local.hour * 60 + local.minute)) {
      return NotificationPopupDecision.quietHours;
    }
  }
  return NotificationPopupDecision.show;
}
