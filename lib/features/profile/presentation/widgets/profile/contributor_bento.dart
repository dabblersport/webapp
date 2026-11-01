import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The Contributor's own bento (`Profiles.dc.html` `bento()`, key
/// `contributor`, lines 584-598): Games & meetups hero (As player or
/// organiser), Played, Organised, Show-up rate, Minutes played, then Sport
/// profiles (All). Partners and the per-sport Organised, Show-up rate and
/// Minutes have no source in the app: with a sport chosen each renders as a
/// dash tile, never zero (approved exclusion; follow-up need "Per-sport
/// contributor metrics source"). The hero value is a dash until a distinct
/// games-and-meetups total exists (temporary, PO ruling 2026-11-01).
class ContributorBento extends StatelessWidget {
  const ContributorBento({
    super.key,
    required this.accent,
    this.sportName,
    this.eventsTotal,
    this.played,
    this.organised,
    this.showUpPercent,
    this.minutesPlayed,
    this.sportProfiles,
    this.onOpenGames,
  });

  final DabblerSportAccent accent;

  /// The chosen sport's name; null while All sports is chosen.
  final String? sportName;

  /// Distinct games and meetups as player or organiser; null when unknown.
  final int? eventsTotal;
  final int? played;
  final int? organised;
  final int? showUpPercent;
  final int? minutesPlayed;

  /// Shown under All sports.
  final int? sportProfiles;

  /// Hero tap: the games list (the design's hero is a link).
  final VoidCallback? onOpenGames;

  /// An approved exclusion (KAN-687 PO ruling): the per-sport source does not
  /// exist yet, so the tile says so instead of showing zero or vanishing.
  DabblerStatTile _unavailable(
    AppLocalizations l10n,
    String label,
    DabblerStatTileTone tone,
  ) => DabblerStatTile(
    value: '—',
    label: label,
    sub: l10n.profile_stat_not_available_yet,
    tone: tone,
    fitValue: true,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final NumberFormat fmt = NumberFormat.decimalPattern(locale);
    final bool all = sportName == null;
    final int? minutes = minutesPlayed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerStatGrid(
        children: <DabblerStatTile>[
          DabblerStatTile(
            size: DabblerStatTileSize.hero,
            tone: DabblerStatTileTone.brand,
            accent: accent,
            value: eventsTotal == null ? '—' : fmt.format(eventsTotal),
            label: all
                ? l10n.profile_stat_games_meetups
                : l10n.profile_stat_sport_games_meetups(sportName!),
            sub: l10n.profile_stat_as_player_or_organiser,
            fitValue: true,
            link: onOpenGames != null,
            onTap: onOpenGames,
            trailing: onOpenGames != null ? const DabblerChevron() : null,
          ),
          if (played != null)
            DabblerStatTile(
              value: fmt.format(played),
              label: l10n.profile_stat_played,
              tone: DabblerStatTileTone.amber,
              fitValue: true,
            ),
          if (organised != null)
            DabblerStatTile(
              value: fmt.format(organised),
              label: l10n.profile_stat_organised,
              tone: DabblerStatTileTone.accent,
              fitValue: true,
            )
          else if (!all)
            _unavailable(
              l10n,
              l10n.profile_stat_organised,
              DabblerStatTileTone.accent,
            ),
          if (showUpPercent != null)
            DabblerStatTile(
              value: '$showUpPercent%',
              label: l10n.profile_stat_show_up_rate,
              tone: DabblerStatTileTone.info,
              fitValue: true,
            )
          else if (!all)
            _unavailable(
              l10n,
              l10n.profile_stat_show_up_rate,
              DabblerStatTileTone.info,
            ),
          if (minutes != null && minutes > 0)
            DabblerStatTile(
              value: fmt.format(minutes),
              label: l10n.profile_stat_minutes_played,
              tone: DabblerStatTileTone.card,
              fitValue: true,
            )
          else if (!all)
            _unavailable(
              l10n,
              l10n.profile_stat_minutes_played,
              DabblerStatTileTone.card,
            ),
          if (!all)
            _unavailable(
              l10n,
              l10n.profile_stat_partners,
              DabblerStatTileTone.card,
            ),
          if (all && sportProfiles != null)
            DabblerStatTile(
              value: fmt.format(sportProfiles),
              label: l10n.profile_stat_sport_profiles,
              tone: DabblerStatTileTone.accent,
              fitValue: true,
            ),
        ],
      ),
    );
  }
}
