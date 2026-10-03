import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show PastGame;
import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart'
    show listingSportFor;
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/games/providers/game_history_providers.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/widgets/sport_profile_section_widgets.dart';
import 'package:dabbler/utils/helpers/date_formatter.dart';

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
      title: 'Game History',
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
          const SizedBox(height: DabblerSpacing.space2),
          ..._buildTiles(context, history.upcoming),
        ],
        if (history.upcoming.isNotEmpty && history.past.isNotEmpty)
          const SizedBox(height: DabblerSpacing.space5),
        if (history.past.isNotEmpty) ...[
          _buildGroupHeader(context, 'Past'),
          const SizedBox(height: DabblerSpacing.space2),
          ..._buildTiles(context, history.past),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, String label) {
    final colors = DabblerColors.of(context);
    return Text(
      label,
      style: sportProfileText(
        context,
        DabblerType.subheadline,
        colors.textSecondary,
        weight: FontWeight.w600,
      ),
    );
  }

  List<Widget> _buildTiles(BuildContext context, List<PastGame> games) {
    return games
        .take(_maxPerGroup)
        .map(
          (game) => Padding(
            padding: const EdgeInsets.only(bottom: DabblerSpacing.space3),
            child: _GameHistoryTile(game: game),
          ),
        )
        .toList();
  }
}

class _GameHistoryTile extends StatelessWidget {
  const _GameHistoryTile({required this.game});

  final PastGame game;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerCardEventMedium(
          title: game.title,
          sport: listingSportFor(game.sport),
          dateTime:
              '${DateFormatter.formatDate(game.scheduledDate)} • ${game.startTime}',
          location: game.venueName ?? 'Venue TBD',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => GameDetailScreen(gameId: game.id),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: DabblerSpacing.space2,
            top: DabblerSpacing.space1,
          ),
          child: Row(
            children: [
              DabblerIcon('people', size: 16, color: colors.brandPrimary),
              const SizedBox(width: DabblerSpacing.space1),
              Text(
                '${game.currentPlayers}/${game.maxPlayers}',
                style: sportProfileText(
                  context,
                  DabblerType.footnote,
                  colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
