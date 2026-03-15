import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show pastGamesProvider;
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/features/venues/providers.dart' as venues_providers;
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/utils/helpers/date_formatter.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/core/constants/adaptive_destinations.dart';

class SportsLibraryScreen extends StatefulWidget {
  const SportsLibraryScreen({super.key, this.initialTabIndex = 0});

  /// 0 = History, 1 = Bookmarks
  final int initialTabIndex;

  @override
  State<SportsLibraryScreen> createState() => _SportsLibraryScreenState();
}

class _SportsLibraryScreenState extends State<SportsLibraryScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');

    final logoWidget = SvgPicture.asset(
      'assets/images/dabbler_text_logo.svg',
      width: 100,
      height: 18,
      colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
    );

    final content = Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Iconsax.arrow_left_copy),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.categoryMain.withValues(
                        alpha: 0.0,
                      ),
                      foregroundColor: colorScheme.onSurface,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'My Sports',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.clock_copy, size: 18),
                          SizedBox(width: 8, height: 30),
                          Text('History'),
                        ],
                      ),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.bookmark_copy, size: 18),
                          SizedBox(width: 8, height: 30),
                          Text('Bookmarks'),
                        ],
                      ),
                    ),
                  ],
                  selected: <int>{_selectedIndex},
                  onSelectionChanged: (Set<int> newSelection) {
                    final newIndex = newSelection.first;
                    if (_selectedIndex != newIndex) {
                      setState(() {
                        _selectedIndex = newIndex;
                      });
                    }
                  },
                  style: ButtonStyle(
                    side: WidgetStateProperty.all(
                      const BorderSide(color: Colors.transparent),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return sportsScheme.primary.withValues(alpha: 1);
                      }
                      return sportsScheme.primary.withValues(alpha: 0.1);
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return sportsScheme.onPrimary;
                      }
                      return sportsScheme.onSurface;
                    }),
                    textStyle: WidgetStateProperty.all(
                      textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  showSelectedIcon: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [_SportsHistoryTab(), _VenueBookmarksTab()],
              ),
            ),
          ],
        ),
      ),
    );

    final width = MediaQuery.of(context).size.width;
    if (width >= AdaptiveBreakpoints.compact) {
      return AdaptiveScaffold(
        currentIndex: 2,
        destinations: kAdaptiveDestinations,
        onDestinationSelected: (i) =>
            onAdaptiveDestinationSelected(context, i, activeIndex: 2),
        headerWidget: logoWidget,
        body: content,
      );
    }
    return content;
  }
}

class _SportsHistoryTab extends ConsumerStatefulWidget {
  const _SportsHistoryTab();

  @override
  ConsumerState<_SportsHistoryTab> createState() => _SportsHistoryTabState();
}

class _SportsHistoryTabState extends ConsumerState<_SportsHistoryTab> {
  String? _selectedSport;

  static const List<String> _sports = [
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

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  onSelected: (_) {
                    setState(() {
                      _selectedSport = sport == 'All' ? null : sport;
                    });
                  },
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  selectedColor: colorScheme.categoryMain.withValues(
                    alpha: 0.2,
                  ),
                  checkmarkColor: colorScheme.categoryMain,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.categoryMain
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: pastGamesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.danger_copy,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load history',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.refresh(pastGamesProvider),
                      icon: const Icon(Iconsax.refresh_copy),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.categoryMain,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (allGames) {
              final filteredGames = _selectedSport == null
                  ? allGames
                  : allGames
                        .where(
                          (g) =>
                              (g.sport as String).toLowerCase() ==
                              _selectedSport!.toLowerCase(),
                        )
                        .toList();

              if (filteredGames.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.clock_copy,
                          size: 64,
                          color: colorScheme.categoryMain.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No history yet',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed games will appear here',
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

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: filteredGames.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final game = filteredGames[index];

                  return Card.filled(
                    color: colorScheme.categoryMain.withValues(alpha: 0.08),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GameDetailScreen(gameId: game.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    game.title,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.categoryMain
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    (game.sport as String),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.categoryMain,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Iconsax.calendar_copy,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${DateFormatter.formatDate(game.scheduledDate)} • ${game.startTime} - ${game.endTime}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Iconsax.people_copy,
                                  size: 16,
                                  color: colorScheme.categoryMain,
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
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VenueBookmarksTab extends ConsumerWidget {
  const _VenueBookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');

    final favoritesAsync = ref.watch(
      venues_providers.favoriteVenuesForCurrentUserProvider,
    );

    return favoritesAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: sportsScheme.primary)),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.danger_copy, size: 48, color: sportsScheme.error),
              const SizedBox(height: 12),
              Text(
                'Couldn\'t load bookmarks',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(
                  venues_providers.favoriteVenuesForCurrentUserProvider,
                ),
                icon: const Icon(Iconsax.refresh_copy),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: sportsScheme.primary,
                  foregroundColor: sportsScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (venues) {
        if (venues.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.bookmark_copy,
                    size: 64,
                    color: sportsScheme.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookmarks yet',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the bookmark on a venue to save it here',
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

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: venues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final venue = venues[index];

            final location = venue.state.isNotEmpty
                ? '${venue.state}, ${venue.city}'
                : '${venue.city}, ${venue.country}';

            return Card.filled(
              color: sportsScheme.primary.withValues(alpha: 0.08),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VenueDetailScreen(venueId: venue.id),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: sportsScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Iconsax.bookmark_2_copy,
                          color: sportsScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              venue.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Iconsax.arrow_right_3_copy,
                        color: colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
