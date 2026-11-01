import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/models/contributor_profile_data.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_sport_picker.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Contributor bento as another user sees it (`Profiles.dc.html`
/// `contributorVisitor`, bento at lines 580-598).
///
/// Every figure comes from the KAN-686 read model. A tile whose source is a
/// declared gap (Show-up rate, Minutes played, Partners) is omitted, never
/// drawn as 0; a failed games read turns the hero into a retry and drops
/// Played and Organised. Zeros from a clean read are real and are shown.
class ContributorVisitorBento extends StatelessWidget {
  const ContributorVisitorBento({
    super.key,
    required this.games,
    required this.scope,
    required this.selected,
    required this.sportsCount,
    required this.onRetry,
    this.onOpenSport,
  });

  /// The games source; [SourceFailed] makes the hero a retry.
  final SourceState<List<ContributorEntity>> games;

  /// The scoped view; null when no events source could be read.
  final ContributorScope? scope;

  /// The chosen practicing sport, or null for All sports.
  final Sport? selected;

  /// Practicing sport profiles; null when that source is unknown.
  final int? sportsCount;

  final VoidCallback onRetry;

  /// Opens the chosen sport's profile; null leaves the hero inert.
  final VoidCallback? onOpenSport;

  static const ValueKey<String> heroKey = ValueKey<String>(
    'visitor-bento-hero',
  );
  static const ValueKey<String> playedKey = ValueKey<String>(
    'visitor-bento-played',
  );
  static const ValueKey<String> organisedKey = ValueKey<String>(
    'visitor-bento-organised',
  );
  static const ValueKey<String> sportsKey = ValueKey<String>(
    'visitor-bento-sports',
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ContributorScope? s = scope;
    final bool failed = games.isFailed || s == null;
    final Sport? sport = selected;
    final DabblerSportAccent accent = DabblerSportAccent.of(
      sport == null ? null : OwnProfileSportPicker.sportKeyOf(sport),
    );
    final int? gamesTotal = failed || games.valueOrNull == null
        ? null
        : s.activity.where((e) => e.kind == ContributorEntityKind.game).length;
    final int? sports = sportsCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerStatGrid(
        children: <DabblerStatTile>[
          if (failed || gamesTotal == null)
            DabblerStatTile(
              key: heroKey,
              size: DabblerStatTileSize.hero,
              tone: DabblerStatTileTone.brand,
              accent: accent,
              value: '—',
              label: l10n.feed_retry,
              sub: l10n.listing_load_games_failed,
              fitValue: true,
              link: true,
              onTap: onRetry,
            )
          else
            DabblerStatTile(
              key: heroKey,
              size: DabblerStatTileSize.hero,
              tone: DabblerStatTileTone.brand,
              accent: accent,
              value: '$gamesTotal',
              label: sport == null
                  ? l10n.profile_stat_games_visitor
                  : l10n.profile_stat_sport_games(sport.nameEn),
              sub: l10n.profile_stat_as_player_or_organiser,
              fitValue: true,
              link: onOpenSport != null,
              onTap: onOpenSport,
              trailing: onOpenSport != null ? const DabblerChevron() : null,
            ),
          if (!failed && gamesTotal != null) ...<DabblerStatTile>[
            DabblerStatTile(
              key: playedKey,
              value: '${s.counts.played}',
              label: l10n.profile_stat_played,
              tone: DabblerStatTileTone.amber,
              fitValue: true,
            ),
            DabblerStatTile(
              key: organisedKey,
              value: '${s.counts.organised}',
              label: l10n.profile_stat_organised,
              tone: DabblerStatTileTone.brand,
              accent: DabblerSportAccent.mainRamp,
              fitValue: true,
            ),
          ],
          // Show-up rate, Minutes played and (per sport) Partners have no
          // proven source (ContributorGaps) and are omitted, not zeroed.
          if (sport == null && sports != null)
            DabblerStatTile(
              key: sportsKey,
              value: '$sports',
              label: l10n.profile_stat_sport_profiles,
              tone: DabblerStatTileTone.accent,
              fitValue: true,
            ),
        ],
      ),
    );
  }
}
