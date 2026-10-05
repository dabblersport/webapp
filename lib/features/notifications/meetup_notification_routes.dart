import 'package:dabbler/utils/constants/route_constants.dart';

/// Meetup notification kinds addressed to the host: they open Manage.
const Set<String> meetupHostKinds = {
  'meetup.rsvp_received',
  'meetup.request_received',
};

/// Meetup notification kinds addressed to a guest: they open the details.
const Set<String> meetupGuestKinds = {
  'meetup.invited',
  'meetup.player_joined',
  'meetup.request_approved',
  'meetup.request_declined',
  'meetup.cancelled',
};

/// True when [kindKey] is one of the seven meetup notification kinds.
bool isMeetupNotificationKind(String kindKey) =>
    meetupHostKinds.contains(kindKey) || meetupGuestKinds.contains(kindKey);

/// The route a meetup notification opens, or null.
///
/// Returns null when [enabled] (FeatureFlags.enableMeetups) is false, when
/// [kindKey] is not a meetup kind, or when [meetupId] is missing. The DB only
/// sends host kinds to the host, so a host kind routes to Manage.
String? meetupNotificationRoute({
  required String kindKey,
  required String? meetupId,
  required bool enabled,
}) {
  if (!enabled || !isMeetupNotificationKind(kindKey)) return null;
  if (meetupId == null || meetupId.isEmpty) return null;
  return meetupHostKinds.contains(kindKey)
      ? RoutePaths.meetupManage(meetupId)
      : RoutePaths.meetupDetail(meetupId);
}

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
