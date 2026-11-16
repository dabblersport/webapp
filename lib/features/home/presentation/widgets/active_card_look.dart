import 'package:dabbler_design_system/dabbler_design_system.dart';

import 'package:dabbler/features/social/providers/active_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// What an Active card looks like: one of the eight looks of the design's
/// `ActivityCard` (`Home Feed.dc.html` `ACT_TONE`, `ACT_LOOK`, `ACT_ACTION`),
/// chosen from where the game or meetup stands now (KAN-964), not from the
/// event the row records.
enum ActiveLook {
  playerJoined('profile-add', 'profile-add'),
  venueAdded('building-4', 'building-4'),
  gameUpcoming('game', 'calendar-add'),
  gameLive('game', 'flash'),
  gameFinished('game', 'cup'),
  meetupUpcoming('people', 'people'),
  meetupLive('people', 'flash'),
  meetupFinished('people', 'medal-star'),

  // KAN-967 (`ACT_TYPES` / `ACT_LOOK`; family glyph from `ACT_FAMILY_ICON`).
  trendingSport('trend-up', 'trend-up'),
  trendingHashtag('trend-up', 'hashtag'),
  playerWeek('profile-add', 'medal-star'),
  playerMonth('profile-add', 'crown'),
  venueWeek('building-4', 'award'),
  venueMonth('building-4', 'crown'),
  venueRating('building-4', 'star'),
  venueDay('building-4', 'magic-star');

  const ActiveLook(this.familyIcon, this.mark);

  /// The family glyph in the kicker pill (`ACT_FAMILY_ICON`).
  final String familyIcon;

  /// The large watermark glyph that tells the looks apart (`ACT_LOOK`).
  final String mark;

  /// The look for [event] at [now].
  static ActiveLook of(ActiveItem event, DateTime now) {
    final honour = _byType[event.eventType];
    if (honour != null) return honour;
    final phase = event.phaseAt(now);
    final meetup = event.entityKind == 'meetup';
    return switch (phase) {
      ActivePhase.live => meetup ? meetupLive : gameLive,
      ActivePhase.finished => meetup ? meetupFinished : gameFinished,
      ActivePhase.upcoming => meetup ? meetupUpcoming : gameUpcoming,
      null => event.isVenue ? venueAdded : playerJoined,
    };
  }

  static const Map<String, ActiveLook> _byType = <String, ActiveLook>{
    'trending_sport': trendingSport,
    'trending_hashtag': trendingHashtag,
    'player_week': playerWeek,
    'player_month': playerMonth,
    'venue_week': venueWeek,
    'venue_month': venueMonth,
    'venue_rating': venueRating,
    'venue_day': venueDay,
  };

  /// The trending strip / box (`ACT_TYPES[t].slim`).
  bool get isSlim => this == trendingSport || this == trendingHashtag;

  /// The player spotlight (`isAward`).
  bool get isAward => this == playerWeek || this == playerMonth;

  /// The photo-led venue (`isFeature`).
  bool get isFeature =>
      this == venueWeek || this == venueMonth || this == venueDay;

  /// A week or month honour, with its period badge.
  bool get isPeriod =>
      this == playerWeek ||
      this == venueWeek ||
      this == playerMonth ||
      this == venueMonth;

  bool get isMonth => this == playerMonth || this == venueMonth;

  /// The strip's and box's glyph (`slimIcon`).
  String get slimIcon => this == trendingHashtag ? 'hashtag' : 'trend-up';

  bool get isLive => this == gameLive || this == meetupLive;

  bool get isFinished => this == gameFinished || this == meetupFinished;

  /// The kicker beside the family glyph or the live dot.
  String kicker(AppLocalizations l) => switch (this) {
    playerJoined => l.act_kicker_player_joined,
    venueAdded => l.act_kicker_venue_added,
    gameUpcoming => l.act_kicker_game_created,
    meetupUpcoming => l.act_kicker_meetup_created,
    gameLive || meetupLive => l.act_kicker_live,
    gameFinished => l.act_kicker_game_ended,
    meetupFinished => l.act_kicker_meetup_completed,
    trendingSport => l.act_kicker_trending_sport,
    trendingHashtag => l.act_kicker_trending_hashtag,
    playerWeek => l.act_kicker_player_week,
    playerMonth => l.act_kicker_player_month,
    venueWeek => l.act_kicker_venue_week,
    venueMonth => l.act_kicker_venue_month,
    venueRating => l.act_kicker_venue_rating,
    venueDay => l.act_kicker_venue_day,
  };

  /// The pill action at the end of the card (`ACT_ACTION`).
  String action(AppLocalizations l) => switch (this) {
    playerJoined => l.act_cta_follow,
    venueAdded => l.act_cta_view_venue,
    gameUpcoming => l.act_cta_join_game,
    meetupUpcoming => l.act_cta_join_meetup,
    gameLive || meetupLive => l.act_cta_join_in,
    gameFinished => l.act_cta_see_results,
    meetupFinished => l.act_cta_see_recap,
    trendingSport => l.act_cta_see_games,
    trendingHashtag => l.act_cta_see_posts,
    playerWeek || playerMonth => l.act_cta_view_profile,
    venueWeek || venueMonth => l.act_cta_book_court,
    venueRating => l.act_cta_read_reviews,
    venueDay => l.act_cta_book_now,
  };

  /// The card's pastel ground and its ink (`ACT_TONE`), the package's
  /// [DabblerActivityTones] (KAN-965), one per look:
  ///
  /// | look | design | tone |
  /// |---|---|---|
  /// | player | `--tile-social` | `social` |
  /// | venue | `--tile-bright` | `bright` |
  /// | upcoming game | `--tile-main` | `main` |
  /// | live game or meetup | `--tile-sport` | `sport` |
  /// | finished game | `--surface-sunken` / `--ink-soft` | `ended` |
  /// | upcoming meetup | `--tile-active` | `active` |
  /// | finished meetup | `--tile-accent` | `accent` |
  /// | trending sport | `--tile-info` | `info` |
  /// | trending hashtag | `--tile-main` | `main` |
  /// | player of the week | `--tile-active` | `active` |
  /// | venue of the week | `--tile-sport` | `sport` |
  /// | player / venue of the month | amber 30% over white, `--bright-s-600` | `gold` |
  /// | new venue rating | `--tile-social` | `social` |
  /// | venue of the day | `--tile-bright` | `bright` |
  DabblerToneColor get tone => switch (this) {
    playerJoined => DabblerActivityTones.social,
    venueAdded => DabblerActivityTones.bright,
    gameUpcoming => DabblerActivityTones.main,
    gameLive || meetupLive => DabblerActivityTones.sport,
    gameFinished => DabblerActivityTones.ended,
    meetupUpcoming => DabblerActivityTones.active,
    meetupFinished => DabblerActivityTones.accent,
    trendingSport => DabblerActivityTones.info,
    trendingHashtag => DabblerActivityTones.main,
    playerWeek => DabblerActivityTones.active,
    venueWeek => DabblerActivityTones.sport,
    playerMonth || venueMonth => DabblerActivityTones.gold,
    venueRating => DabblerActivityTones.social,
    venueDay => DabblerActivityTones.bright,
  };
}

/// One card per game, meetup, venue or player: [events] (newest first) with
/// each entity's older rows dropped. `active_stream` returns a row per event,
/// so a game that was created, started and ended is three rows; the list
/// shows it once, at its newest event, in its current state (KAN-964).
List<ActiveItem> latestActivePerEntity(List<ActiveItem> events) {
  final seen = <String>{};
  return <ActiveItem>[
    for (final e in events)
      // KAN-967: only a game's or meetup's lifecycle rows collapse; an honour
      // (a player of the week and of the month) is its own card.
      if (seen.add(e.isEvent ? '${e.entityKind}:${e.entityId}' : e.id)) e,
  ];
}
