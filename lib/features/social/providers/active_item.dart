import 'package:flutter/foundation.dart';

/// KAN-957: one row of the `active_stream` RPC (KAN-595), the Home Active
/// tab's source. The server filters by event type and city and pages by
/// (event_at, event_type, entity_id); this is the row as the card reads it.
@immutable
class ActiveItem {
  const ActiveItem({
    required this.eventType,
    required this.eventAt,
    required this.entityKind,
    required this.entityId,
    this.actorProfileId,
    this.city,
    this.title,
    this.actorName,
    this.actorAvatarUrl,
    this.detail,
    this.startAt,
    this.endAt,
    this.isLive = false,
    this.sportsEn = const <String>[],
    this.sportsAr = const <String>[],
    this.participantCount,
    this.capacity,
    this.spaceCount,
    this.metricKind,
    this.metricValue,
    this.periodStart,
    this.stats = const <ActiveStat>[],
    this.rating,
    this.ratingCount,
    this.venueRatingAvg,
    this.photoUrl,
    this.quote,
    this.ratedGameAt,
    this.reasons = const <ActiveReason>[],
    this.distanceKm,
  });

  /// `player_joined`, `venue_added`, `game_created|started|ended`,
  /// `meetup_created|started|completed`.
  final String eventType;
  final DateTime eventAt;

  /// `profile`, `venue`, `game` or `meetup`.
  final String entityKind;
  final String entityId;
  final String? actorProfileId;
  final String? city;
  final String? title;
  final String? actorName;
  final String? actorAvatarUrl;

  /// Venue or area name (games, meetups), area name (venues).
  final String? detail;

  /// Scheduled start of a game or meetup: the date tile.
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isLive;
  final List<String> sportsEn;
  final List<String> sportsAr;

  /// KAN-964 (`active_stream` 08bfa568): a game's active players (the host
  /// included on hosted and casual games) or a meetup's RSVPs marked going,
  /// read now (also on ended rows). Null for players and venues.
  final int? participantCount;

  /// The event's capacity; null when open or not an event.
  final int? capacity;

  /// A new venue's active spaces (courts, pitches).
  final int? spaceCount;

  // --- KAN-967 card types (trending, awards, featured venues, ratings) ---

  /// The trending figure's kind: `games_growth_pct`, `players_growth_pct`,
  /// `posts_today` or `posts_yesterday`.
  final String? metricKind;
  final num? metricValue;

  /// The first day of the award's week or month.
  final DateTime? periodStart;

  /// The award's or featured venue's three figures, in order.
  final List<ActiveStat> stats;

  /// The venue's average rating (0-5) and how many ratings it has; on a
  /// `venue_rating` row, [rating] is that rating's stars and the venue's
  /// average is [venueRatingAvg] (over [ratingCount] ratings).
  final double? rating;
  final int? ratingCount;

  /// KAN-967 (CEO 2026-11-16): a `venue_rating` row's venue average.
  final double? venueRatingAvg;

  /// The featured venue's first photo.
  final String? photoUrl;

  /// A `venue_rating` row's comment, and when the rater played there.
  final String? quote;
  final DateTime? ratedGameAt;

  /// Why `venue_day` is recommended. The server does not emit `venue_day`
  /// yet (a paid placement later, CEO 2026-11-16) and sends no `reasons` or
  /// `distance_km` column; both read as empty.
  final List<ActiveReason> reasons;

  /// The viewer's distance to the venue (`venue_day`), when known.
  final double? distanceKm;

  /// One of the KAN-967 trending strips.
  bool get isSlim =>
      eventType == 'trending_sport' || eventType == 'trending_hashtag';

  /// Unique in the stream: one row per (event_type, entity_id).
  String get id => '$eventType:$entityId';

  bool get isVenue => entityKind == 'venue';
  bool get hasActor => (actorName ?? '').trim().isNotEmpty;

  /// A listing row: anything but a player, with a title.
  bool get hasListing => entityKind != 'profile' && (title ?? '').isNotEmpty;

  /// A game or meetup row.
  bool get isEvent => entityKind == 'game' || entityKind == 'meetup';

  /// KAN-964: where the game or meetup stands at [now], whatever event the
  /// row records (a `game_created` row of a game that has since ended is
  /// finished). Null for a player or a venue. The schedule decides; the
  /// server's [isLive] (true at fetch time, possibly stale in the cache)
  /// counts only while the event has not passed its end.
  ActivePhase? phaseAt(DateTime now) {
    if (!isEvent) return null;
    final end = endAt ?? startAt;
    if (end != null && !now.isBefore(end)) return ActivePhase.finished;
    final start = startAt;
    if (isLive || (start != null && !now.isBefore(start))) {
      return ActivePhase.live;
    }
    if (start == null && eventType.endsWith('_started')) {
      return ActivePhase.live;
    }
    if (start == null &&
        (eventType.endsWith('_ended') || eventType.endsWith('_completed'))) {
      return ActivePhase.finished;
    }
    return ActivePhase.upcoming;
  }

  /// KAN-965: each sport tag for [languageCode] (falling back to English per
  /// tag) with its English name, which keys the sport's emoji.
  List<({String label, String en})> sportTagsFor(String languageCode) =>
      <({String label, String en})>[
        for (var i = 0; i < sportsEn.length; i++)
          if (sportsEn[i].isNotEmpty)
            (
              label:
                  languageCode == 'ar' &&
                      i < sportsAr.length &&
                      sportsAr[i].isNotEmpty
                  ? sportsAr[i]
                  : sportsEn[i],
              en: sportsEn[i],
            ),
      ];

  /// The sport tags for [languageCode], falling back to English per tag.
  List<String> sportsFor(String languageCode) {
    if (languageCode != 'ar' || sportsAr.isEmpty) return sportsEn;
    return <String>[
      for (var i = 0; i < sportsAr.length; i++)
        sportsAr[i].isNotEmpty
            ? sportsAr[i]
            : (i < sportsEn.length ? sportsEn[i] : ''),
    ].where((s) => s.isNotEmpty).toList();
  }

  static DateTime? _date(dynamic raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  static int? _int(dynamic raw) => raw is num ? raw.toInt() : null;

  static double? _double(dynamic raw) => raw is num ? raw.toDouble() : null;

  static List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? <Map<String, dynamic>>[
          for (final m in raw)
            if (m is Map) Map<String, dynamic>.from(m),
        ]
      : const <Map<String, dynamic>>[];

  static List<String> _strings(dynamic raw) => raw is List
      ? <String>[
          for (final s in raw)
            if (s is String && s.isNotEmpty) s,
        ]
      : const <String>[];

  /// Null for a row without a type, an id or a time (an older cache shape).
  static ActiveItem? fromRow(Map<String, dynamic> r) {
    final type = r['event_type']?.toString();
    final id = r['entity_id']?.toString();
    final at = _date(r['event_at']);
    if (type == null || id == null || id.isEmpty || at == null) return null;
    String? s(String k) {
      final v = r[k]?.toString().trim();
      return v == null || v.isEmpty ? null : v;
    }

    return ActiveItem(
      eventType: type,
      eventAt: at,
      entityKind: s('entity_kind') ?? '',
      entityId: id,
      actorProfileId: s('actor_profile_id'),
      city: s('city'),
      title: s('title'),
      actorName: s('actor_display_name'),
      actorAvatarUrl: s('actor_avatar_url'),
      detail: s('detail'),
      startAt: _date(r['start_at']),
      endAt: _date(r['end_at']),
      isLive: r['is_live'] == true,
      sportsEn: _strings(r['sport_names_en']),
      sportsAr: _strings(r['sport_names_ar']),
      participantCount: _int(r['participant_count']),
      capacity: _int(r['capacity']),
      spaceCount: _int(r['space_count']),
      metricKind: s('metric_kind'),
      metricValue: r['metric_value'] is num ? r['metric_value'] as num : null,
      periodStart: _date(r['period_start']),
      stats: <ActiveStat>[
        for (final m in _maps(r['stats']))
          if (m['key'] is String && m['value'] is num)
            (key: m['key'] as String, value: m['value'] as num),
      ],
      rating: _double(r['rating']),
      ratingCount: _int(r['rating_count']),
      venueRatingAvg: _double(r['venue_rating_avg']),
      photoUrl: s('photo_url'),
      quote: s('quote'),
      ratedGameAt: _date(r['rated_game_at']),
      reasons: <ActiveReason>[
        for (final m in _maps(r['reasons']))
          if (m['kind'] is String)
            (
              kind: m['kind'] as String,
              value: m['value'] is num ? m['value'] as num : null,
              text: m['text'] is String ? m['text'] as String : null,
            ),
      ],
      distanceKm: _double(r['distance_km']),
    );
  }

  /// The row back in the RPC's shape (the on-device cache).
  Map<String, dynamic> toRow() => <String, dynamic>{
    'event_type': eventType,
    'event_at': eventAt.toUtc().toIso8601String(),
    'entity_kind': entityKind,
    'entity_id': entityId,
    'actor_profile_id': actorProfileId,
    'city': city,
    'title': title,
    'actor_display_name': actorName,
    'actor_avatar_url': actorAvatarUrl,
    'detail': detail,
    'start_at': startAt?.toUtc().toIso8601String(),
    'end_at': endAt?.toUtc().toIso8601String(),
    'is_live': isLive,
    'sport_names_en': sportsEn,
    'sport_names_ar': sportsAr,
    'participant_count': participantCount,
    'capacity': capacity,
    'space_count': spaceCount,
    'metric_kind': metricKind,
    'metric_value': metricValue,
    'period_start': periodStart?.toUtc().toIso8601String(),
    'stats': <Map<String, dynamic>>[
      for (final st in stats)
        <String, dynamic>{'key': st.key, 'value': st.value},
    ],
    'rating': rating,
    'rating_count': ratingCount,
    'venue_rating_avg': venueRatingAvg,
    'photo_url': photoUrl,
    'quote': quote,
    'rated_game_at': ratedGameAt?.toUtc().toIso8601String(),
    'reasons': <Map<String, dynamic>>[
      for (final r in reasons)
        <String, dynamic>{'kind': r.kind, 'value': r.value, 'text': r.text},
    ],
    'distance_km': distanceKm,
  };
}

/// KAN-967: one figure of an award or a featured venue: `games`,
/// `games`, `rating`, `hosted` (players, CEO 2026-11-16), `bookings`.
typedef ActiveStat = ({String key, num value});

/// KAN-967: why a venue is recommended today: `free_from` ([text] the local
/// `HH:mm` the courts are free from), `distance_km` ([value]) or `price_aed`
/// ([value], per court and hour).
typedef ActiveReason = ({String kind, num? value, String? text});

/// KAN-964: a game's or meetup's state on the Active card.
enum ActivePhase { upcoming, live, finished }

/// The Active tab's type chips (`Home Feed.dc.html:293`), each a set of
/// `active_stream` event types. "All" is no type (null).
enum ActiveType {
  games('game', <String>['game_created', 'game_started', 'game_ended']),
  meetups('people', <String>[
    'meetup_created',
    'meetup_started',
    'meetup_completed',
  ]),
  venues('building-4', <String>[
    'venue_added',
    'venue_week',
    'venue_month',
    'venue_rating',
    'venue_day',
  ]),
  players('profile-add', <String>[
    'player_joined',
    'player_week',
    'player_month',
  ]),

  /// KAN-967: trending sports and hashtags.
  trending('trend-up', <String>['trending_sport', 'trending_hashtag']);

  const ActiveType(this.icon, this.eventTypes);

  /// The chip and card glyph (bold).
  final String icon;
  final List<String> eventTypes;

  /// The type an event belongs to.
  static ActiveType? ofEvent(String eventType) {
    for (final t in values) {
      if (t.eventTypes.contains(eventType)) return t;
    }
    return null;
  }
}

/// The Active tab's filters: a city (null is every city) and a type (null is
/// "All"). Lives in a non-autoDispose provider, so it survives tab switches.
@immutable
class ActiveFilter {
  const ActiveFilter({this.city, this.type});

  final String? city;
  final ActiveType? type;

  bool get isActive => city != null || type != null;

  ActiveFilter withCity(String? c) => ActiveFilter(city: c, type: type);
  ActiveFilter withType(ActiveType? t) => ActiveFilter(city: city, type: t);

  @override
  bool operator ==(Object other) =>
      other is ActiveFilter && other.city == city && other.type == type;

  @override
  int get hashCode => Object.hash(city, type);
}
