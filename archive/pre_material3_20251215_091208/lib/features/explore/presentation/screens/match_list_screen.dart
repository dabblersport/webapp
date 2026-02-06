import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';

class MatchListScreen extends ConsumerStatefulWidget {
  final String sport;
  final Color sportColor;
  final String searchQuery;

  const MatchListScreen({
    super.key,
    required this.sport,
    required this.sportColor,
    this.searchQuery = '',
  });

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen> {
  @override
  Widget build(BuildContext context) {
    // Watch the public games provider
    final publicGamesAsync = ref.watch(publicGamesProvider);

    return publicGamesAsync.when(
      data: (allGames) {
        // Filter by sport
        final sportFilteredGames = allGames.where((game) {
          return game.sport.toLowerCase() == widget.sport.toLowerCase();
        }).toList();

        // Filter by search query if any
        final searchFilteredGames = widget.searchQuery.isEmpty
            ? sportFilteredGames
            : sportFilteredGames.where((game) {
                return game.title.toLowerCase().contains(
                      widget.searchQuery.toLowerCase(),
                    ) ||
                    game.description.toLowerCase().contains(
                      widget.searchQuery.toLowerCase(),
                    );
              }).toList();

        if (searchFilteredGames.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sports_esports,
                  size: 64,
                  color: context.colors.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${widget.sport} games found',
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to create one!',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildGamesList(searchFilteredGames);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load games', style: context.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(publicGamesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build games list from Game entities (no conversion needed)
  Widget _buildGamesList(List<Game> games) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _buildGameCard(game);
      },
    );
  }

  /// Build a game card from Game entity
  Widget _buildGameCard(Game game) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(gameId: game.id),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(
          top: 18,
          left: 12,
          right: 18,
          bottom: 18,
        ),
        decoration: ShapeDecoration(
          color: context.colors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 0.50,
              strokeAlign: BorderSide.strokeAlignCenter,
              color: context.colors.outline.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Sport, Game Type, Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getSportEmoji(game.sport),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      game.sport,
                      style: TextStyle(
                        color: context.colors.onSurface,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      game.skillLevel,
                      style: TextStyle(
                        color: context.colors.onSurface.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Text(
                  _getTimeFromNow(game.scheduledDate),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.colors.onSurface.withOpacity(0.6),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              game.title,
              style: TextStyle(
                color: context.colors.onSurface,
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Time and Location
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🕓', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '${game.startTime} - ${game.endTime}',
                      style: TextStyle(
                        color: context.colors.onSurface.withOpacity(0.9),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        game.venueName ?? 'Venue TBD',
                        style: TextStyle(
                          color: context.colors.onSurface.withOpacity(0.9),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.36,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Players and Join Button
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Text('👥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${game.currentPlayers}/${game.maxPlayers}',
                        style: TextStyle(
                          color: context.colors.onSurface.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: ShapeDecoration(
                      color: widget.sportColor.withOpacity(0.9),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 1,
                          color: Colors.white.withOpacity(0.12),
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('➕', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 4),
                        Text(
                          'Join',
                          style: TextStyle(
                            color: context.colors.onPrimary,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            height: 1.43,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSportEmoji(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
      case 'soccer':
        return '⚽️';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      case 'cricket':
        return '🏏';
      case 'volleyball':
        return '🏐';
      case 'padel':
        return '🎾';
      default:
        return '⚽️';
    }
  }

  String _getTimeFromNow(DateTime scheduledDate) {
    final now = DateTime.now();
    final difference = scheduledDate.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
