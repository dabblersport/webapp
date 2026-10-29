import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

/// The Contributor profile's game lists: Upcoming (joined or organised) and
/// Games I organise, each row opening the real game detail. A visitor sees
/// nothing for an empty list; the owner with no games at all sees the
/// calendar empty answer and a Find a game link into the Games tab
/// (`Profiles.dc.html` `contributorNew`, lines 740-745). [onOpenGame] and
/// [onFindGame] are for tests.
class ContributorGamesSections extends StatelessWidget {
  const ContributorGamesSections({
    super.key,
    required this.counts,
    this.showOrganised = true,
    this.onOpenGame,
    this.onFindGame,
  });

  final GameCounts counts;

  /// The "Games I organise" list is the owner's; a visitor sees Upcoming only.
  final bool showOrganised;
  final ValueChanged<String>? onOpenGame;

  /// Replaces the push to the Games tab behind Find a game.
  final VoidCallback? onFindGame;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<GameCountRow> upcoming = counts.upcomingGames;
    final List<GameCountRow> organised = counts.organisedGames;
    final bool ownerEmpty =
        showOrganised && upcoming.isEmpty && organised.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (ownerEmpty) _emptyUpcoming(context, l10n),
        if (upcoming.isNotEmpty)
          _section(context, l10n.listing_upcoming, upcoming),
        if (showOrganised && organised.isNotEmpty)
          _section(context, l10n.profile_section_games_organised, organised),
      ],
    );
  }

  Widget _emptyUpcoming(BuildContext context, AppLocalizations l10n) {
    final TextDirection direction = Directionality.of(context);
    return Padding(
      key: const ValueKey<String>('contributor-upcoming-empty'),
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space6,
            ),
            child: DabblerSection(
              title: l10n.listing_upcoming,
              style: DabblerSectionStyle.label,
              action: DabblerTextLink(
                label: l10n.profile_find_a_game,
                underline: false,
                style: DabblerType.footnote
                    .resolveForDirection(direction)
                    .copyWith(fontWeight: DabblerType.semibold),
                onPressed: onFindGame ?? () => context.go(RoutePaths.gamesTab),
              ),
            ),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space6,
            ),
            child: DabblerEmptyState(
              icon: 'calendar',
              text: l10n.profile_upcoming_empty,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<GameCountRow> rows,
  ) {
    final String locale = Localizations.localeOf(context).toString();
    final DateFormat when = DateFormat.MMMEd(locale).add_jm();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space6,
            ),
            child: DabblerSection(
              title: title,
              style: DabblerSectionStyle.label,
            ),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          for (final GameCountRow r in rows)
            DabblerListRow(
              key: ValueKey<String>('contributor-game-${r.id}'),
              title: r.title ?? '',
              subtitle: when.format(r.startAt.toLocal()),
              showChevron: true,
              onTap: () => onOpenGame != null
                  ? onOpenGame!(r.id)
                  : context.push(RoutePaths.gameDetail(r.id)),
            ),
        ],
      ),
    );
  }
}
