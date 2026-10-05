import 'package:dabbler_design_system/dabbler_design_system.dart';
// Material is imported for one non-visual symbol only: the
// `MaterialPageRoute` route type the existing pushes use (no behaviour change).
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show pastGamesProvider;
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/features/venues/providers.dart' as venues_providers;
import 'package:dabbler/utils/helpers/date_formatter.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// "My Sports" library (History / Bookmarks). Reached from the Explore header
/// and the venues screen. No design frame: design-system defaults in the same
/// structure.
class SportsLibraryScreen extends StatefulWidget {
  const SportsLibraryScreen({super.key, this.initialTabIndex = 0});

  /// 0 = History, 1 = Bookmarks
  final int initialTabIndex;

  @override
  State<SportsLibraryScreen> createState() => _SportsLibraryScreenState();
}

const EdgeInsetsDirectional _gutter = EdgeInsetsDirectional.symmetric(
  horizontal: DabblerSpacing.space6,
);

class _SportsLibraryScreenState extends State<SportsLibraryScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    // One layout at every width (the Material adaptive-scaffold rail wrapper
    // is not a DS component).
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: AppLocalizations.of(context).sports_prefs_my_sports,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: _gutter,
            child: DabblerTabs(
              variant: DabblerTabsVariant.segmented,
              fullWidth: true,
              value: '$_selectedIndex',
              onChanged: (id) {
                final newIndex = int.parse(id);
                if (_selectedIndex != newIndex) {
                  setState(() {
                    _selectedIndex = newIndex;
                  });
                }
              },
              items: const [
                DabblerTabItem(
                  id: '0',
                  label: 'History',
                  icon: DabblerIcon('clock', size: DabblerSizing.iconSm),
                ),
                DabblerTabItem(
                  id: '1',
                  label: 'Bookmarks',
                  icon: DabblerIcon('bookmark', size: DabblerSizing.iconSm),
                ),
              ],
            ),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [_SportsHistoryTab(), _VenueBookmarksTab()],
            ),
          ),
        ],
      ),
    );
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
    final colors = DabblerColors.of(context);
    final pastGamesAsync = ref.watch(pastGamesProvider);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: _gutter,
          child: Row(
            children: [
              for (final sport in _sports)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: DabblerSpacing.space2,
                  ),
                  child: DabblerChip(
                    label: sport,
                    selected:
                        _selectedSport == sport ||
                        (_selectedSport == null && sport == 'All'),
                    leadingIcon: sport == 'All'
                        ? null
                        : DabblerSportIcon.fromKey(
                            sport.toLowerCase(),
                            size: DabblerSizing.iconInline,
                          ),
                    onTap: () {
                      setState(() {
                        _selectedSport = sport == 'All' ? null : sport;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        Expanded(
          child: pastGamesAsync.when(
            loading: () => const Center(child: DabblerSpinner()),
            error: (error, _) => DabblerEmptyState.error(
              title: 'Failed to load history',
              text: error.toString(),
              retryLabel: 'Retry',
              onRetry: () => ref.refresh(pastGamesProvider),
            ),
            data: (allGames) {
              final filteredGames = _selectedSport == null
                  ? allGames
                  : allGames
                        .where(
                          (g) =>
                              g.sport.toLowerCase() ==
                              _selectedSport!.toLowerCase(),
                        )
                        .toList();

              if (filteredGames.isEmpty) {
                return const DabblerEmptyState(
                  icon: 'clock',
                  title: 'No history yet',
                  text: 'Completed games will appear here',
                  size: DabblerEmptyStateSize.page,
                );
              }

              return ListView.separated(
                padding: _gutter,
                itemCount: filteredGames.length,
                separatorBuilder: (_, __) =>
                    const DabblerGap.v(DabblerSpacing.space3),
                itemBuilder: (context, index) {
                  final game = filteredGames[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DabblerCardEventMedium(
                        title: game.title,
                        sport: DabblerSport.fromKey(game.sport.toLowerCase()),
                        dateTime:
                            '${DateFormatter.formatDate(game.scheduledDate)} • ${game.startTime} - ${game.endTime}',
                        location: game.venueName ?? 'Venue TBD',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GameDetailScreen(gameId: game.id),
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
                            DabblerIcon(
                              'people',
                              size: DabblerSizing.iconInline,
                              color: colors.brandPrimary,
                            ),
                            const DabblerGap.h(DabblerSpacing.space1),
                            DabblerText(
                              '${game.sport} · ${game.currentPlayers}/${game.maxPlayers} players',
                              style: DabblerType.caption1,
                              tone: DabblerTextTone.secondary,
                            ),
                          ],
                        ),
                      ),
                    ],
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
    final favoritesAsync = ref.watch(
      venues_providers.favoriteVenuesForCurrentUserProvider,
    );

    return favoritesAsync.when(
      loading: () => const Center(child: DabblerSpinner()),
      error: (error, _) => DabblerEmptyState.error(
        title: 'Couldn\'t load bookmarks',
        text: error.toString(),
        retryLabel: 'Retry',
        onRetry: () => ref.invalidate(
          venues_providers.favoriteVenuesForCurrentUserProvider,
        ),
      ),
      data: (venues) {
        if (venues.isEmpty) {
          return const DabblerEmptyState(
            icon: 'bookmark',
            title: 'No bookmarks yet',
            text: 'Tap the bookmark on a venue to save it here',
            size: DabblerEmptyStateSize.page,
          );
        }

        return ListView.separated(
          padding: _gutter,
          itemCount: venues.length,
          separatorBuilder: (_, __) =>
              const DabblerGap.v(DabblerSpacing.space3),
          itemBuilder: (context, index) {
            final venue = venues[index];

            final location = venue.state.isNotEmpty
                ? '${venue.state}, ${venue.city}'
                : '${venue.city}, ${venue.country}';

            return DabblerCardEventMedium(
              title: venue.name,
              location: location,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VenueDetailScreen(venueId: venue.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
