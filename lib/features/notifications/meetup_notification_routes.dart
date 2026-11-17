import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// KAN-978: the meetup kinds and their routes come from the kind registry
/// ([NotificationKinds]); this file keeps the entry points the screen and the
/// push service call.

/// True when [kindKey] is a meetup notification kind.
bool isMeetupNotificationKind(String kindKey) =>
    NotificationKinds.isMeetupKind(kindKey);

/// The route a meetup notification opens, or null.
///
/// Returns null when [enabled] (FeatureFlags.enableMeetups) is false, when
/// [kindKey] is not a meetup kind, or when [meetupId] is missing. Host kinds
/// route to Manage, guest kinds to the details.
String? meetupNotificationRoute({
  required String kindKey,
  required String? meetupId,
  required bool enabled,
}) => NotificationKinds.meetupRoute(kindKey, meetupId, enabled: enabled);

/// Push-tap fallback, used only when `action_route` is empty.
///
/// The push `data` carries `kind_key`, `action_route` and `entity_id`, but
/// `entity_id` is the notification row id, not the meetup id. A meetup id is
/// read only from `meetup_id` if the backend ever adds it; otherwise a meetup
/// kind lands on the Meetups list.
String? meetupPushRoute(Map<String, dynamic> data, {required bool enabled}) {
  final action = data['action_route'];
  if (action is String && action.trim().isNotEmpty) return null;
  final kind = data['kind_key'];
  if (!enabled || kind is! String || !isMeetupNotificationKind(kind)) {
    return null;
  }
  final id = data['meetup_id'];
  return meetupNotificationRoute(
        kindKey: kind,
        meetupId: id is String ? id : null,
        enabled: enabled,
      ) ??
      RoutePaths.meetups;
}
