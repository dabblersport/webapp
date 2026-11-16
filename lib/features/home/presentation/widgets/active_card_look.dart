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
  meetupFinished('people', 'medal-star');

  const ActiveLook(this.familyIcon, this.mark);

  /// The family glyph in the kicker pill (`ACT_FAMILY_ICON`).
  final String familyIcon;

  /// The large watermark glyph that tells the looks apart (`ACT_LOOK`).
  final String mark;

  /// The look for [event] at [now].
  static ActiveLook of(ActiveItem event, DateTime now) {
    final phase = event.phaseAt(now);
    final meetup = event.entityKind == 'meetup';
    return switch (phase) {
      ActivePhase.live => meetup ? meetupLive : gameLive,
      ActivePhase.finished => meetup ? meetupFinished : gameFinished,
      ActivePhase.upcoming => meetup ? meetupUpcoming : gameUpcoming,
      null => event.isVenue ? venueAdded : playerJoined,
    };
  }

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
  DabblerToneColor get tone => switch (this) {
    playerJoined => DabblerActivityTones.social,
    venueAdded => DabblerActivityTones.bright,
    gameUpcoming => DabblerActivityTones.main,
    gameLive || meetupLive => DabblerActivityTones.sport,
    gameFinished => DabblerActivityTones.ended,
    meetupUpcoming => DabblerActivityTones.active,
    meetupFinished => DabblerActivityTones.accent,
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
      if (seen.add('${e.entityKind}:${e.entityId}')) e,
  ];
}
