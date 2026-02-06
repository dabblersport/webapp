import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/utils/helpers/date_formatter.dart';
import 'package:dabbler/themes/material3_extensions.dart';
import 'package:dabbler/core/design_system/layouts/single_section_layout.dart';

/// Provider for past games (games that have already ended)
final pastGamesProvider = FutureProvider.autoDispose<List>((ref) async {
  final repository = ref.watch(gamesRepositoryProvider);
  final result = await repository.getGames(
    filters: {'is_public': true},
    limit: 100,
  );

  return result.fold(
    (failure) {
      throw Exception(failure.message);
    },
    (games) {
      final now = DateTime.now();
      // Filter games that have ended
      final pastGames = games.where((game) {
        final gameEndTime = game.getScheduledEndDateTime();
        return gameEndTime.isBefore(now);
      }).toList();

      // Sort by date (most recent first)
      pastGames.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      return pastGames;
    },
  );
});

IconData _sportIconFor(String sport) {
  switch (sport.toLowerCase()) {
    case 'football':
    case 'soccer':
      return Iconsax.medal_star_copy;
    case 'cricket':
      return Iconsax.game_copy;
    case 'padel':
    case 'tennis':
      return Iconsax.game_copy;
    case 'basketball':
      return Iconsax.game_copy;
    case 'volleyball':
      return Iconsax.game_copy;
    default:
      return Iconsax.game_copy;
  }
}

class SportsHistoryScreen extends ConsumerStatefulWidget {
  const SportsHistoryScreen({super.key});

  @override
  ConsumerState<SportsHistoryScreen> createState() =>
      _SportsHistoryScreenState();
}

class _SportsHistoryScreenState extends ConsumerState<SportsHistoryScreen> {
  String? _selectedSport;

  final List<String> _sports = [
    'All',
    'Football',
    'Cricket',
    'Padel',
    'Basketball',
    'Volleyball',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pastGamesAsync = ref.watch(pastGamesProvider);

    return SingleSectionLayout(
      category: 'sports',
      scrollable: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Iconsax.arrow_left_copy),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.categorySports.withValues(
                      alpha: 0.0,
                    ),
                    foregroundColor: colorScheme.onSurface,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Game History',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sport filter chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _sports.length,
              itemBuilder: (context, index) {
                final sport = _sports[index];
                final isSelected =
                    _selectedSport == sport ||
                    (_selectedSport == null && sport == 'All');
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(sport),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSport = sport == 'All' ? null : sport;
                      });
                    },
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    selectedColor: colorScheme.categorySports.withValues(
                      alpha: 0.2,
                    ),
                    checkmarkColor: colorScheme.categorySports,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.categorySports
                          : colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),

          // Games list
          Expanded(
            child: pastGamesAsync.when(
              data: (allGames) {
                // Filter by sport if selected
                final filteredGames = _selectedSport == null
                    ? allGames
                    : allGames
                          .where(
                            (game) =>
                                game.sport.toLowerCase() ==
                                _selectedSport!.toLowerCase(),
                          )
                          .toList();

                if (filteredGames.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.clock_copy,
                          size: 64,
                          color: colorScheme.categorySports.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No past games',
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your game history will appear here',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredGames.length,
                  itemBuilder: (context, index) {
                    final game = filteredGames[index];
                    return _buildPastGameCard(context, game);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.danger_copy,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load game history',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.refresh(pastGamesProvider),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.categorySports,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastGameCard(BuildContext context, game) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(gameId: game.id),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Sport, completed badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.categorySports.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _sportIconFor(game.sport),
                          size: 18,
                          color: colorScheme.categorySports,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        game.sport,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.categorySports.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Completed',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.categorySports,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                game.title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Date and location
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Iconsax.calendar_copy,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormatter.formatDate(game.scheduledDate)} • ${game.startTime} - ${game.endTime}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Iconsax.location_copy,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          game.venueName ?? 'Venue TBD',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.9),
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

              // Players count
              Row(
                children: [
                  Icon(
                    Iconsax.people_copy,
                    size: 18,
                    color: colorScheme.categorySports,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${game.currentPlayers}/${game.maxPlayers} players',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
