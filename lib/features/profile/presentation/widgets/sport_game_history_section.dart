import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show PastGame;
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/games/providers/game_history_providers.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_profile_section_widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// "Game History" card for the sport profile screen: the games the user
/// joined or hosted for this sport, split into Upcoming and Past.
/// Rendered on the user's own sport profile only.
class SportGameHistorySection extends ConsumerWidget {
  const SportGameHistorySection({super.key, required this.args});

  final SportProfileRouteArgs args;

  static const int _maxPerGroup = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      sportGameHistoryProvider((
        userId: args.userId,
        profileId: args.profileId,
        sportId: args.sportId,
      )),
    );

    return SportSectionCard(
      title: AppLocalizations.of(context).priv_t_history,
      child: historyAsync.when(
        data: (history) => _buildContent(context, history),
        loading: () => const SportSectionLoading(),
        error: (error, stack) => const SportEmptySection(
          icon: 'danger',
          message: "Couldn't load game history.",
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SportGameHistory history) {
    if (history.upcoming.isEmpty && history.past.isEmpty) {
      return const SportEmptySection(
        icon: 'clock',
        message: 'No games for this sport yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (history.upcoming.isNotEmpty) ...[
          _buildGroupHeader(context, 'Upcoming'),
          const DabblerGap.v(DabblerSpacing.space2),
          ..._buildTiles(context, history.upcoming, upcoming: true),
        ],
        if (history.upcoming.isNotEmpty && history.past.isNotEmpty)
          const DabblerGap.v(DabblerSpacing.space5),
        if (history.past.isNotEmpty) ...[
          _buildGroupHeader(context, 'Past'),
          const DabblerGap.v(DabblerSpacing.space2),
          ..._buildTiles(context, history.past, upcoming: false),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, String label) {
    return DabblerText(
      label,
      style: DabblerType.subheadline,
      weight: DabblerTextWeight.semibold,
      tone: DabblerTextTone.secondary,
    );
  }

  List<Widget> _buildTiles(
    BuildContext context,
    List<PastGame> games, {
    required bool upcoming,
  }) {
    return games
        .take(_maxPerGroup)
        .map(
          (game) => Padding(
            padding: const EdgeInsets.only(bottom: DabblerSpacing.space3),
            child: _GameHistoryTile(game: game, upcoming: upcoming),
          ),
        )
        .toList();
  }
}

/// One game as the Profiles frame's "Next games" row: weekday over day, the
/// title, and a sub-line with the time, place and headcount.
class _GameHistoryTile extends StatelessWidget {
  const _GameHistoryTile({required this.game, required this.upcoming});

  final PastGame game;
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    return DabblerProfileRow(
      tone: upcoming
          ? DabblerProfileRowTone.info
          : DabblerProfileRowTone.neutral,
      lead: DateFormat.d(locale).format(game.scheduledDate),
      leadCaption: DateFormat.E(locale).format(game.scheduledDate),
      captionFirst: true,
      title: game.title,
      subtitle: [
        game.startTime,
        if (game.venueName != null) game.venueName!,
        '${game.currentPlayers}/${game.maxPlayers}',
      ].join(' · '),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => GameDetailScreen(gameId: game.id),
          ),
        );
      },
    );
  }
}
