import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show PastGame;
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/games/providers/game_history_providers.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final historyAsync = ref.watch(
      sportGameHistoryProvider((
        userId: args.userId,
        profileId: args.profileId,
        sportId: args.sportId,
      )),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game History',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          historyAsync.when(
            data: (history) => _buildContent(context, history),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (error, stack) => _buildEmpty(
              context,
              icon: Iconsax.danger_copy,
              message: "Couldn't load game history.",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SportGameHistory history) {
    if (history.upcoming.isEmpty && history.past.isEmpty) {
      return _buildEmpty(
        context,
        icon: Iconsax.clock_copy,
        message: 'No games for this sport yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (history.upcoming.isNotEmpty) ...[
          _buildGroupHeader(context, 'Upcoming'),
          const SizedBox(height: 8),
          ..._buildTiles(context, history.upcoming),
        ],
        if (history.upcoming.isNotEmpty && history.past.isNotEmpty)
          const SizedBox(height: 16),
        if (history.past.isNotEmpty) ...[
          _buildGroupHeader(context, 'Past'),
          const SizedBox(height: 8),
          ..._buildTiles(context, history.past),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Text(
      label,
      style: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  List<Widget> _buildTiles(BuildContext context, List<PastGame> games) {
    return games
        .take(_maxPerGroup)
        .map(
          (game) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GameHistoryTile(game: game),
          ),
        )
        .toList();
  }

  Widget _buildEmpty(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameHistoryTile extends StatelessWidget {
  const _GameHistoryTile({required this.game});

  final PastGame game;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(gameId: game.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _sportIconFor(game.sport),
                size: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormatter.formatDate(game.scheduledDate)} • ${game.startTime}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    game.venueName ?? 'Venue TBD',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Icon(
                  Iconsax.people_copy,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${game.currentPlayers}/${game.maxPlayers}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _sportIconFor(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
      case 'soccer':
        return Iconsax.medal_star_copy;
      case 'cricket':
      case 'padel':
      case 'tennis':
      case 'basketball':
      case 'volleyball':
      default:
        return Iconsax.game_copy;
    }
  }
}
