import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The Profiles design's bento: a hero tile and small tiles in a six-column
/// [DabblerStatGrid]. Only figures the app holds are drawn.
class OwnProfileStats extends StatelessWidget {
  const OwnProfileStats({
    super.key,
    required this.posts,
    required this.sportsCount,
    this.gamesPlayed,
    this.heroSub,
    this.onOpenSport,
  });

  final int posts;
  final int sportsCount;

  /// Total games across the shown sport profiles; null when the persona has
  /// no sport profiles (the hero then shows posts).
  final int? gamesPlayed;
  final String? heroSub;

  /// Makes the hero a link into the selected sport's profile.
  final VoidCallback? onOpenSport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? games = gamesPlayed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerStatGrid(
        children: <DabblerStatTile>[
          DabblerStatTile(
            size: DabblerStatTileSize.hero,
            tone: DabblerStatTileTone.brand,
            value: '${games ?? posts}',
            label: games != null
                ? l10n.user_profile_stat_games
                : l10n.profile_tab_posts,
            sub: heroSub,
            fitValue: true,
            link: onOpenSport != null,
            onTap: onOpenSport,
            trailing: onOpenSport != null ? const DabblerChevron() : null,
          ),
          DabblerStatTile(
            value: '$sportsCount',
            label: l10n.user_profile_stat_sports,
            tone: DabblerStatTileTone.ink,
            fitValue: true,
          ),
          if (games != null)
            DabblerStatTile(
              value: '$posts',
              label: l10n.profile_tab_posts,
              fitValue: true,
            ),
        ],
      ),
    );
  }
}
