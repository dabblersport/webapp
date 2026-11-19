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
  int? count,
  int? capacity,
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
  participantCount: count,
  capacity: capacity,
);

ActiveItem activeVenue({
  String id = 'v1',
  DateTime? at,
  String title = 'JLT Padel Club',
  String? detail = 'Jumeirah Lake Towers',
  String? city = 'Dubai',
  int? spaces,
}) => ActiveItem(
  eventType: 'venue_added',
  eventAt: at ?? DateTime.now().subtract(const Duration(hours: 1)),
  entityKind: 'venue',
  entityId: id,
  city: city,
  title: title,
  detail: detail,
  spaceCount: spaces,
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

/// KAN-967: a trending sport or hashtag row (the design's samples).
ActiveItem activeTrend({
  String id = 't1',
  bool hashtag = false,
  DateTime? at,
  String? title,
  String metricKind = 'games_growth_pct',
  num metricValue = 38,
  List<String> sports = const <String>['Padel'],
  List<String> sportsAr = const <String>['بادل'],
}) => ActiveItem(
  eventType: hashtag ? 'trending_hashtag' : 'trending_sport',
  eventAt: at ?? DateTime.now().subtract(const Duration(minutes: 10)),
  entityKind: hashtag ? 'hashtag' : 'sport',
  entityId: id,
  city: 'Dubai',
  title: title ?? (hashtag ? '#dabblernight' : 'Padel'),
  detail: hashtag ? 'dabblernight' : null,
  sportsEn: sports,
  sportsAr: sportsAr,
  metricKind: metricKind,
  metricValue: metricValue,
);

/// KAN-967: a player of the week or month.
ActiveItem activeAward({
  String id = 'p1',
  bool month = false,
  DateTime? at,
  DateTime? period,
}) => ActiveItem(
  eventType: month ? 'player_month' : 'player_week',
  eventAt: at ?? DateTime.now().subtract(const Duration(hours: 2)),
  entityKind: 'profile',
  entityId: id,
  actorProfileId: id,
  city: 'Dubai',
  actorName: 'Khalid Al Mansouri',
  sportsEn: const <String>['Football'],
  sportsAr: const <String>['كرة القدم'],
  periodStart: period ?? (month ? DateTime(2026, 10) : DateTime(2026, 11, 16)),
  stats: month
      ? const <ActiveStat>[
          (key: 'games', value: 22),
          (key: 'rating', value: 5),
          (key: 'hosted', value: 7),
          (key: 'mvp_votes', value: 9),
          (key: 'wins', value: 14),
        ]
      : const <ActiveStat>[
          (key: 'games', value: 6),
          (key: 'rating', value: 4.9),
          (key: 'hosted', value: 2),
          (key: 'mvp_votes', value: 3),
          (key: 'wins', value: 4),
        ],
);

/// KAN-967: a venue of the week, month or day, or a new venue rating.
ActiveItem activeVenueHonour({
  String id = 'v9',
  String type = 'venue_week',
  DateTime? at,
}) => ActiveItem(
  eventType: type,
  eventAt: at ?? DateTime.now().subtract(const Duration(hours: 3)),
  entityKind: 'venue',
  entityId: id,
  city: 'Dubai',
  title: type == 'venue_rating'
      ? 'Al Quoz Pitches'
      : 'Nad Al Sheba Sports Complex',
  detail: type == 'venue_rating' ? 'Al Quoz' : 'Nad Al Sheba',
  actorName: type == 'venue_rating' ? 'Aisha Khan' : null,
  sportsEn: const <String>['Football', 'Padel'],
  spaceCount: 4,
  rating: type == 'venue_rating' ? 5 : 4.8,
  ratingCount: type == 'venue_rating' ? 186 : 204,
  venueRatingAvg: type == 'venue_rating' ? 4.8 : null,
  quote: type == 'venue_rating' ? 'Best lit pitch in Al Quoz.' : null,
  ratedGameAt: type == 'venue_rating' ? DateTime(2026, 11, 10, 20) : null,
  periodStart: type == 'venue_month'
      ? DateTime(2026, 10)
      : (type == 'venue_week' ? DateTime(2026, 11, 16) : null),
  stats: type == 'venue_week' || type == 'venue_month'
      ? const <ActiveStat>[
          (key: 'bookings', value: 128),
          (key: 'games', value: 41),
          (key: 'rating', value: 4.8),
        ]
      : const <ActiveStat>[],
  reasons: type == 'venue_day'
      ? const <ActiveReason>[
          (kind: 'free_from', value: null, text: '19:00'),
          (kind: 'distance_km', value: 2.1, text: null),
          (kind: 'price_aed', value: 120, text: null),
        ]
      : const <ActiveReason>[],
  distanceKm: type == 'venue_day' ? 2.1 : null,
);
