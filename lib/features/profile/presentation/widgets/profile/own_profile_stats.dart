import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The counts when the source answered, null while loading or when it failed.
GameCounts? ownProfileCountsData(AsyncValue<GameCounts>? counts) =>
    switch (counts) {
      AsyncData<GameCounts>(:final value) => value,
      _ => null,
    };

/// The counts source failed (never a zero, never a new contributor).
bool ownProfileCountsFailed(AsyncValue<GameCounts>? counts) =>
    counts is AsyncError<GameCounts>;

/// True only for a real answer of zero played, organised and upcoming.
bool ownProfileIsNewContributor(AsyncValue<GameCounts>? counts) {
  final GameCounts? c = ownProfileCountsData(counts);
  return c != null && c.played == 0 && c.organised == 0 && c.upcoming == 0;
}

/// The Profiles design's bento: a hero tile in the chosen sport's accent and
/// small tiles in a six-column [DabblerStatGrid] (rated, win rate, show-up,
/// sports played, primary sports). Only figures the app holds are drawn; the
/// same composition serves the own profile and another user's.
class OwnProfileStats extends StatelessWidget {
  const OwnProfileStats({
    super.key,
    required this.posts,
    required this.sportsCount,
    this.gamesPlayed,
    this.organised,
    this.upcoming,
    this.postsFailed = false,
    this.countsFailed = false,
    this.onRetryCounts,
    this.rating,
    this.minutesPlayed,
    this.reliability,
    this.primarySports,
    this.heroLabel,
    this.heroSub,
    this.onOpenSport,
    this.accent = DabblerSportAccent.all,
    this.heroTone = DabblerStatTileTone.brand,
    this.sportsLabel,
    this.sportsTone = DabblerStatTileTone.card,
    this.scoped = false,
    this.newContributor = false,
  });

  final int posts;
  final int sportsCount;

  /// Total games across the shown sport profiles; null when the persona has
  /// no sport profiles (the hero then shows posts).
  final int? gamesPlayed;

  /// Distinct games the user created; null draws no tile.
  final int? organised;

  /// Distinct upcoming games the user joined or created; null draws no tile.
  final int? upcoming;

  /// The posts fetch failed: the hero shows a dash, never a zero.
  final bool postsFailed;

  /// The games-count source failed: the hero reads as an error with a retry,
  /// never a zero, and the count tiles are omitted.
  final bool countsFailed;
  final VoidCallback? onRetryCounts;

  /// The mean player rating over the shown sport profiles; null or zero draws
  /// no tile.
  final double? rating;

  /// Total minutes played (the frame's ink tile); null or zero draws no tile.
  final int? minutesPlayed;

  /// The reliability score as a percentage; null draws no tile.
  final int? reliability;

  /// How many sports are marked primary; null draws no tile.
  final int? primarySports;

  /// The hero caption; defaults to "Games played".
  final String? heroLabel;
  final String? heroSub;

  /// Makes the hero a link into the selected sport's profile.
  final VoidCallback? onOpenSport;

  /// The hero's sport colour (the "All sports" accent when none is chosen).
  final DabblerSportAccent accent;

  /// The hero's fill: the brand (re-tinted by [accent]) for a player,
  /// organiser or socialiser, amber for a host.
  final DabblerStatTileTone heroTone;

  /// The sports tile's caption; defaults to "Sports played".
  final String? sportsLabel;

  /// The sports tile's fill.
  final DabblerStatTileTone sportsTone;

  /// A sport is chosen: the bento narrows to that sport's own figures.
  final bool scoped;

  /// A Contributor with no games yet: the design's three-tile bento (hero,
  /// Played, Organised, all zero) with the invitation under the hero
  /// (`Profiles.dc.html` `contributorNew`, lines 573-579).
  final bool newContributor;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? games = gamesPlayed;
    final double? stars = rating;
    final int? minutes = minutesPlayed;
    final int? show = reliability;
    final int? primary = primarySports;
    if (newContributor) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
        child: DabblerStatGrid(
          children: <DabblerStatTile>[
            DabblerStatTile(
              size: DabblerStatTileSize.hero,
              tone: heroTone,
              accent: accent,
              value: '0',
              label: l10n.profile_stat_games_meetups,
              sub: l10n.profile_stat_new_hero_sub,
              fitValue: true,
            ),
            DabblerStatTile(
              value: '0',
              label: l10n.profile_stat_played,
              tone: DabblerStatTileTone.amber,
              fitValue: true,
            ),
            DabblerStatTile(
              value: '0',
              label: l10n.profile_stat_organised,
              tone: DabblerStatTileTone.accent,
              fitValue: true,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerStatGrid(
        children: <DabblerStatTile>[
          DabblerStatTile(
            size: DabblerStatTileSize.hero,
            tone: heroTone,
            accent: accent,
            value: countsFailed
                ? '\u2014'
                : games == null && postsFailed
                ? '\u2014'
                : '${games ?? posts}',
            label: countsFailed
                ? l10n.feed_retry
                : games != null
                ? (heroLabel ?? l10n.user_profile_stat_games)
                : l10n.profile_tab_posts,
            sub: heroSub,
            fitValue: true,
            link: countsFailed || onOpenSport != null,
            onTap: countsFailed ? onRetryCounts : onOpenSport,
            trailing: onOpenSport != null && !countsFailed
                ? const DabblerChevron()
                : null,
          ),
          if (!scoped && organised != null)
            DabblerStatTile(
              value: '$organised',
              label: l10n.profile_stat_games_organised,
              tone: DabblerStatTileTone.card,
              fitValue: true,
            ),
          if (!scoped && upcoming != null)
            DabblerStatTile(
              value: '$upcoming',
              label: l10n.listing_upcoming,
              tone: DabblerStatTileTone.accent,
              fitValue: true,
            ),
          if (stars != null && stars > 0)
            DabblerStatTile(
              value: stars.toStringAsFixed(1),
              label: l10n.profile_stat_rated,
              tone: DabblerStatTileTone.amber,
              fitValue: true,
            ),
          if (!scoped && minutes != null && minutes > 0)
            DabblerStatTile(
              value: NumberFormat.decimalPattern(
                Localizations.localeOf(context).toString(),
              ).format(minutes),
              label: l10n.profile_stat_minutes_played,
              tone: DabblerStatTileTone.ink,
              fitValue: true,
            ),
          if (!scoped && show != null)
            DabblerStatTile(
              value: '$show%',
              label: l10n.user_profile_stat_reliability,
              tone: DabblerStatTileTone.info,
              fitValue: true,
            ),
          if (!scoped)
            DabblerStatTile(
              value: '$sportsCount',
              label: sportsLabel ?? l10n.user_profile_stat_sports,
              tone: sportsTone,
              fitValue: true,
            ),
          if (!scoped && primary != null && primary > 0)
            DabblerStatTile(
              value: '$primary',
              label: l10n.profile_stat_primary_sports,
              tone: DabblerStatTileTone.accent,
              fitValue: true,
            ),
        ],
      ),
    );
  }
}
