import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The Contributor profile's game lists: Upcoming (joined or organised) and
/// Games I organise, each row opening the real game detail. Nothing is drawn
/// for a list with no games; [onOpenGame] is for tests.
class ContributorGamesSections extends StatelessWidget {
  const ContributorGamesSections({
    super.key,
    required this.counts,
    this.showOrganised = true,
    this.onOpenGame,
  });

  final GameCounts counts;

  /// The "Games I organise" list is the owner's; a visitor sees Upcoming only.
  final bool showOrganised;
  final ValueChanged<String>? onOpenGame;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<GameCountRow> upcoming = counts.upcomingGames;
    final List<GameCountRow> organised = counts.organisedGames;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (upcoming.isNotEmpty)
          _section(context, l10n.listing_upcoming, upcoming),
        if (showOrganised && organised.isNotEmpty)
          _section(context, l10n.profile_section_games_organised, organised),
      ],
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
