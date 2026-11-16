/// KAN-957: `active_stream` rows for the Home Active tests.
library;

import 'package:dabbler/features/social/providers/active_item.dart';

ActiveItem activeGame({
  String id = 'g1',
  String type = 'game_created',
  DateTime? at,
  String title = 'Sunday 5-a-side',
  String? detail = 'Al Wasl Sports Club',
  String? actor = 'Omar Hassan',
  DateTime? startAt,
  DateTime? endAt,
  String kind = 'game',
  bool live = false,
  List<String> sports = const <String>['Football'],
  List<String> sportsAr = const <String>['كرة القدم'],
  String? city = 'Dubai',
}) => ActiveItem(
  eventType: type,
  eventAt: at ?? DateTime.now().subtract(const Duration(minutes: 12)),
  entityKind: kind,
  entityId: id,
  actorProfileId: actor == null ? null : 'p-$id',
  city: city,
  title: title,
  actorName: actor,
  detail: detail,
  startAt: startAt ?? DateTime(2026, 11, 20, 19),
  endAt: endAt ?? DateTime(2026, 11, 20, 21),
  isLive: live,
  sportsEn: sports,
  sportsAr: sportsAr,
);

ActiveItem activeVenue({
  String id = 'v1',
  DateTime? at,
  String title = 'JLT Padel Club',
  String? detail = 'Jumeirah Lake Towers',
  String? city = 'Dubai',
}) => ActiveItem(
  eventType: 'venue_added',
  eventAt: at ?? DateTime.now().subtract(const Duration(hours: 1)),
  entityKind: 'venue',
  entityId: id,
  city: city,
  title: title,
  detail: detail,
  sportsEn: const <String>['Padel'],
);

ActiveItem activePlayer({String id = 'u1', DateTime? at}) => ActiveItem(
  eventType: 'player_joined',
  eventAt: at ?? DateTime.now().subtract(const Duration(hours: 2)),
  entityKind: 'profile',
  entityId: id,
  actorProfileId: id,
  city: 'Abu Dhabi',
  title: 'Moataz Mustapha',
  actorName: 'Moataz Mustapha',
  sportsEn: const <String>['Tennis'],
);
