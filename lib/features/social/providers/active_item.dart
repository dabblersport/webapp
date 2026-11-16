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
  };
}

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
  venues('building-4', <String>['venue_added']),
  players('profile-add', <String>['player_joined']);

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
