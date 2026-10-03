import 'package:dabbler_design_system/dabbler_design_system.dart';
// Material is imported for one non-visual symbol only: the
// `MaterialPageRoute` route type the existing pushes use (no behaviour change).
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/config/sport_filters_config.dart';
import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/core/utils/sport_id_mapping.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/explore/presentation/widgets/location_permission_drawer.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/explore/presentation/widgets/sport_specific_filters.dart';
import 'package:dabbler/features/games/presentation/controllers/venues_controller.dart'
    as vc;
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart'
    show sportsSubTabProvider;
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/helpers/date_formatter.dart';

/// No design frame exists for this screen (route `/sports-explore`): it is
/// rebuilt with design-system defaults in the same structure.

TextStyle _type(
  BuildContext context,
  DabblerTypeStyle style,
  Color color, {
  FontWeight? weight,
}) => style
    .resolveForDirection(Directionality.of(context))
    .copyWith(color: color, fontWeight: weight);

const EdgeInsetsDirectional _gutter = EdgeInsetsDirectional.symmetric(
  horizontal: DabblerSpacing.space6,
);

/// A sport's DS icon from its display name ('Football' -> `football`).
Widget _sportIcon(String sport, {double size = 16, Color? color}) =>
    DabblerSportIcon.fromKey(sport.toLowerCase(), size: size, color: color);

/// A venue card. Public API (map + onTap + isLoading) is unchanged; it renders
/// the canonical DS event card row ([DabblerCardEventMedium]).
class VenueCard extends StatelessWidget {
  final Map<String, dynamic> venue;
  final VoidCallback? onTap;
  final bool isLoading;

  const VenueCard({
    super.key,
    required this.venue,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const DabblerSkeleton.card();
    }

    final name = venue['name'] as String? ?? 'Unknown Venue';
    final area = venue['location'] as String? ?? 'Location not available';
    final sports = (venue['sports'] as List<dynamic>?)?.cast<String>() ?? [];
    final visibleSports = sports.take(2).toList();
    final overflowCount = sports.length > visibleSports.length
        ? sports.length - visibleSports.length
        : 0;
    final rating = (venue['rating'] as num?)?.toDouble() ?? 0.0;
    final isClosed = venue['isOpen'] == false;
    final distance = venue['distance'] as String? ?? '';
    final reviews =
        (venue['reviews'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    final showRating = reviews.length >= 3 && rating >= 3.0;

    // The design system's venue card: closed state, sports (+overflow) and
    // rating as tags, distance beside the area.
    return DabblerCardVenue(
      name: name,
      area: area,
      distance: distance.isEmpty ? null : distance,
      tags: <Widget>[
        if (isClosed)
          DabblerBadge(
            label: 'Closed',
            status: DabblerColors.of(context).status(DabblerStatusTone.error),
          ),
        if (showRating)
          DabblerCardVenue.rating(rating: rating.toStringAsFixed(1)),
        for (final sport in visibleSports)
          DabblerBadge(label: sport, tone: DabblerBadgeTone.warning),
        if (overflowCount > 0)
          DabblerBadge(
            label: '+$overflowCount',
            tone: DabblerBadgeTone.warning,
          ),
      ],
      onTap: onTap,
      semanticLabel: name,
    );
  }
}

class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  final Map<String, dynamic>? initialFilters;

  const ExploreScreen({super.key, this.initialTab, this.initialFilters});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  // Tab index kept in a plain int (was a Material TabController with no
  // TabBar attached: it only stored the index and synced the provider).
  int _mainTabIndex = 0;
  late LocationService _locationService;
  final ScrollController _mainScrollController = ScrollController();
  int _selectedSportIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSortAscending = true; // default sort by start date ascending

  // Filter state
  String? _selectedArea;
  DabblerSliderRange _selectedPriceRange = const DabblerSliderRange(0, 500);
  double _selectedRating = 0;
  final Set<String> _selectedAmenities = {};

  // Sport-specific filters (e.g., ball type for cricket, game type for football)
  final Map<String, dynamic> _sportSpecificFilters = {};

  // Primary sports shown in chips
  final List<Map<String, dynamic>> _sports = [
    {'name': 'Football', 'description': 'Find football games near you'},
    {'name': 'Cricket', 'description': 'Join cricket games and tournaments'},
    {'name': 'Padel', 'description': 'Discover padel courts and players'},
    {'name': 'Basketball', 'description': 'Find basketball courts and games'},
    {'name': 'Tennis', 'description': 'Discover tennis courts and games'},
    {'name': 'Badminton', 'description': 'Find badminton venues and matches'},
    {'name': 'Running', 'description': 'Explore running routes and events'},
    {'name': 'Swimming', 'description': 'Find swimming pools and sessions'},
    {
      'name': 'Equestrian',
      'description': 'Discover equestrian venues and activities',
    },
    {'name': 'Shooting', 'description': 'Find shooting ranges and sessions'},
  ];

  List<Map<String, dynamic>> _sportsForChips() {
    // Always show all available sports from the catalog
    return _sports;
  }

  int _safeSelectedSportIndex(int sportsLength) {
    if (sportsLength <= 0) return 0;
    if (_selectedSportIndex < 0 || _selectedSportIndex >= sportsLength) {
      return 0;
    }
    return _selectedSportIndex;
  }

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _locationService.addListener(_onLocationChanged);
    // If games are hidden, default to venues tab
    if (!FeatureFlags.enableGameBrowsing) {
      _mainTabIndex = 1;
    }
    _initLocation();
  }

  void _onLocationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initLocation() async {
    // Initialize location service (loads cache and fetches if permitted)
    await _locationService.init();
    // Check if we should show permission prompt
    await _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final shouldShow = await _locationService.shouldShowLocationPrompt();

    if (!shouldShow || !mounted) return;

    final permission = await _locationService.checkPermissionStatus();

    // Only show drawer if permission is not already granted
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Wait for first frame to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showLocationDrawer();
        }
      });
    }
  }

  void _showLocationDrawer() {
    showDabblerSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      builder: (context) {
        return LocationPermissionDrawer(
          onAllowLocation: () async {
            Navigator.pop(context);
            await _locationService.saveLocationPreference('allow');
            await _locationService.fetchLocation();
          },
          onRemindLater: () async {
            Navigator.pop(context);
            await _locationService.saveLocationPreference('remind_later');
          },
          onNoThanks: () async {
            Navigator.pop(context);
            await _locationService.saveLocationPreference('never');
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationChanged);
    _mainScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _handleSortTap() {
    if (_mainTabIndex == 0 && FeatureFlags.enableGameBrowsing) {
      setState(() {
        _isSortAscending = !_isSortAscending;
      });
    } else {
      final venuesState = ref.read(venuesControllerProvider);
      final notifier = ref.read(venuesControllerProvider.notifier);
      final nextAscending = venuesState.sortBy == vc.VenueSortBy.distance
          ? !venuesState.ascending
          : true;
      notifier.updateSorting(vc.VenueSortBy.distance, ascending: nextAscending);
    }
  }

  bool _shouldShowJoinButton() {
    final profileState = ref.watch(profileControllerProvider);
    final profileType = profileState.profile?.profileType;

    if (profileType == 'player') {
      return FeatureFlags.enablePlayerGameJoining;
    } else if (profileType == 'organiser') {
      return FeatureFlags.enableOrganiserGameJoining;
    }
    return false;
  }

  String _sortTooltip(WidgetRef ref) {
    if (_mainTabIndex == 0 && FeatureFlags.enableGameBrowsing) {
      return _isSortAscending ? 'Sort: Soonest first' : 'Sort: Latest first';
    }

    final venuesState = ref.watch(venuesControllerProvider);
    final ascending = venuesState.sortBy == vc.VenueSortBy.distance
        ? venuesState.ascending
        : true;
    return ascending ? 'Sort: Closest first' : 'Sort: Farthest first';
  }

  void _showFilterModal() {
    showDabblerSheet<void>(
      context: context,
      title: 'Filter Results',
      detent: DabblerSheetDetent.content,
      builder: (context) => _buildFiltersBottomSheetContent(),
    );
  }

  List<DabblerSelectOption<String>> _areaOptions() {
    final allAreas = ref.watch(activeAreasProvider).valueOrNull ?? [];

    // Determine the user's country from the nearest area.
    final position = _locationService.currentPosition;
    String? userCountry;
    if (position != null) {
      userCountry = ref
          .watch(
            nearestAreaProvider((
              lat: position.latitude,
              lng: position.longitude,
            )),
          )
          .valueOrNull
          ?.country;
    }

    // Filter by country when known; otherwise show all.
    final filtered = userCountry != null
        ? allAreas.where((a) => a.country == userCountry).toList()
        : allAreas;

    return [
      for (final area in filtered)
        DabblerSelectOption<String>(value: area.name, label: area.name),
    ];
  }

  Widget _buildFiltersBottomSheetContent() {
    final sports = _sportsForChips();
    final selectedIndex = _safeSelectedSportIndex(sports.length);

    return StatefulBuilder(
      builder: (context, setModalState) {
        final colors = DabblerColors.of(context);
        Widget label(String text) => Text(
          text,
          style: _type(
            context,
            DabblerType.subheadline,
            colors.textPrimary,
            weight: FontWeight.w600,
          ),
        );
        Widget caption(String text) => Text(
          text,
          style: _type(context, DabblerType.footnote, colors.textSecondary),
        );

        void onSportFilter(String key, dynamic value) {
          setModalState(() {
            if (value == null || value == 'All') {
              _sportSpecificFilters.remove(key);
            } else {
              _sportSpecificFilters[key] = value;
            }
          });
        }

        final sportFilters =
            SportFiltersConfig.hasSportSpecificFilters(
              sports[selectedIndex]['name'],
            )
            ? SportSpecificFiltersFactory.create(
                sport: sports[selectedIndex]['name'],
                selectedFilters: _sportSpecificFilters,
                onFilterChanged: onSportFilter,
              )
            : null;

        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.only(
            start: DabblerSpacing.space5,
            end: DabblerSpacing.space5,
            top: DabblerSpacing.space2,
            bottom:
                DabblerSpacing.space4 +
                MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sport-Specific Filters
              if (sportFilters != null) ...[
                sportFilters,
                const SizedBox(height: DabblerSpacing.space5),
              ],
              // Area
              DabblerSelect<String>(
                label: 'Area',
                placeholder: 'Select Area',
                value: _selectedArea,
                options: _areaOptions(),
                onChanged: (value) =>
                    setModalState(() => _selectedArea = value),
              ),
              const SizedBox(height: DabblerSpacing.space5),
              // Price Range
              label('Price Range (AED)'),
              DabblerSlider.range(
                values: _selectedPriceRange,
                min: 0,
                max: 500,
                step: 50,
                onChanged: (values) =>
                    setModalState(() => _selectedPriceRange = values),
              ),
              caption(
                'AED ${_selectedPriceRange.low.round()} - AED ${_selectedPriceRange.high.round()}',
              ),
              const SizedBox(height: DabblerSpacing.space5),
              // Rating
              label('Minimum Rating'),
              DabblerSlider(
                value: _selectedRating,
                min: 0,
                max: 5,
                step: 1,
                onChanged: (value) =>
                    setModalState(() => _selectedRating = value),
              ),
              caption(
                _selectedRating == 0
                    ? 'Any rating'
                    : '${_selectedRating.toStringAsFixed(1)}+ stars',
              ),
              const SizedBox(height: DabblerSpacing.space5),
              // Amenities
              label('Amenities'),
              const SizedBox(height: DabblerSpacing.space2),
              Wrap(
                spacing: DabblerSpacing.space2,
                runSpacing: DabblerSpacing.space2,
                children: [
                  for (final amenity in const [
                    'Parking',
                    'Showers',
                    'Indoor',
                    'Outdoor',
                    'Cafeteria',
                  ])
                    DabblerChip(
                      label: amenity,
                      selected: _selectedAmenities.contains(amenity),
                      onTap: () {
                        setModalState(() {
                          if (!_selectedAmenities.remove(amenity)) {
                            _selectedAmenities.add(amenity);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: DabblerSpacing.space8),
              Row(
                children: [
                  Expanded(
                    child: DabblerButton(
                      label: 'Clear All',
                      tone: DabblerButtonTone.text,
                      fullWidth: true,
                      onPressed: () {
                        setModalState(() {
                          _selectedArea = null;
                          _selectedPriceRange = const DabblerSliderRange(
                            0,
                            500,
                          );
                          _selectedRating = 0;
                          _selectedAmenities.clear();
                          _sportSpecificFilters.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: DabblerSpacing.space3),
                  Expanded(
                    child: DabblerButton(
                      label: 'Apply Filters',
                      fullWidth: true,
                      onPressed: () {
                        setState(() {
                          // Apply filters
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DabblerSpacing.space4),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    if (_mainTabIndex == 0 && FeatureFlags.enableGameBrowsing) {
      final _ = await ref.refresh(publicGamesProvider.future);
    } else {
      await ref.read(venuesControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync shared sub-tab provider → local tab index (driven by nav bar)
    final externalSubTab = ref.watch(sportsSubTabProvider);
    if (_mainTabIndex != externalSubTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mainTabIndex != externalSubTab) {
          setState(() {
            _mainTabIndex = externalSubTab;
          });
        }
      });
    }

    // One layout at every width (the Material AdaptiveScaffold rail wrapper
    // is not a DS component; the app shell owns wide navigation).
    return DabblerPage(
      body: DabblerRefresh(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          controller: _mainScrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: DabblerSpacing.space2),
            ),
            // ── Header ──
            SliverToBoxAdapter(child: _buildHeader()),
            // ── Search row ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: DabblerSpacing.space3,
                ),
                child: _buildSearchRow(),
              ),
            ),
            // ── Sports chips ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: DabblerSpacing.space3,
                  bottom: DabblerSpacing.space3,
                ),
                child: _buildSportsChips(),
              ),
            ),
            SliverToBoxAdapter(
              child: (_mainTabIndex == 0 && FeatureFlags.enableGameBrowsing)
                  ? _buildGamesTabContent()
                  : _buildVenuesTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesTabContent() {
    final publicGamesAsync = publicGamesProvider;
    final sports = _sportsForChips();
    final selectedIndex = _safeSelectedSportIndex(sports.length);

    return Padding(
      padding: _gutter,
      child: Consumer(
        builder: (context, ref, child) {
          final gamesAsync = ref.watch(publicGamesAsync);

          return gamesAsync.when(
            data: (allGames) {
              // Filter by sport (or show all when 'All' is selected)
              final selectedSportName =
                  (sports[selectedIndex]['name'] as String).toLowerCase();
              final sportFilteredGames = selectedSportName == 'all'
                  ? allGames
                  : allGames
                        .where(
                          (game) =>
                              game.sport.toLowerCase() == selectedSportName,
                        )
                        .toList();

              // Filter out past games - only show upcoming games
              final now = DateTime.now();
              final upcomingGames = sportFilteredGames.where((game) {
                final gameStartTime = game.getScheduledStartDateTime();
                return gameStartTime.isAfter(now);
              }).toList();

              // Filter by search query if any
              final searchFilteredGames = _searchQuery.isEmpty
                  ? upcomingGames
                  : upcomingGames.where((game) {
                      return game.title.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          game.description.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          );
                    }).toList();

              // Sort by scheduled start date by default; toggle via sort icon
              searchFilteredGames.sort(
                (a, b) => _isSortAscending
                    ? a.scheduledDate.compareTo(b.scheduledDate)
                    : b.scheduledDate.compareTo(a.scheduledDate),
              );

              if (searchFilteredGames.isEmpty) {
                return DabblerEmptyState(
                  icon: 'game',
                  title: 'No ${sports[selectedIndex]['name']} games found',
                  text: 'Be the first to create one!',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final game in searchFilteredGames) _buildGameCard(game),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsetsDirectional.all(DabblerSpacing.space6),
              child: Center(child: DabblerSpinner()),
            ),
            error: (error, stack) => DabblerEmptyState.error(
              title: 'Failed to load games',
              text: error.toString(),
              size: DabblerEmptyStateSize.inline,
              retryLabel: 'Retry',
              onRetry: () => ref.refresh(publicGamesAsync),
            ),
          );
        },
      ),
    );
  }

  void _openGame(String gameId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GameDetailScreen(gameId: gameId)),
    );
  }

  Widget _buildGameCard(game) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerCardEventMedium(
            title: game.title as String,
            sport: DabblerSport.fromKey((game.sport as String).toLowerCase()),
            dateTime:
                '${DateFormatter.formatDate(game.scheduledDate)} • ${game.startTime} - ${game.endTime}',
            location: game.venueName ?? 'Venue TBD',
            onTap: () => _openGame(game.id as String),
            // The card's listing slots (DS gaps 6): players with the sport,
            // skill and time-from-now line under the bar, and Join.
            progress: DabblerCardEventPlayers(
              label: '${game.currentPlayers}/${game.maxPlayers}',
              joined: game.currentPlayers as int,
              capacity: game.maxPlayers as int,
              note:
                  '${game.sport} · ${game.skillLevel} · ${_getTimeFromNow(game.scheduledDate)}',
            ),
            // Only show Join button for players with permission; it opens
            // the game detail to join.
            action: _shouldShowJoinButton()
                ? DabblerCardEventListing.joinButton(
                    label: 'Join',
                    onPressed: () => _openGame(game.id as String),
                  )
                : null,
          ),
        ],
      ),
    );
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

  Widget _buildVenuesTabContent() {
    final sports = _sportsForChips();
    final selectedIndex = _safeSelectedSportIndex(sports.length);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space8),
      child: _VenuesTabContent(
        key: ValueKey('venues_${sports[selectedIndex]['name']}'),
        selectedSport: sports[selectedIndex]['name'],
        searchQuery: _searchQuery,
        sportSpecificFilters: _sportSpecificFilters,
        filterArea: _selectedArea,
        priceRange: _selectedPriceRange,
        rating: _selectedRating,
        amenities: _selectedAmenities,
      ),
    );
  }

  Widget _buildHeader() {
    final colors = DabblerColors.of(context);

    final profileState = ref.watch(profileControllerProvider);
    final profileType = profileState.profile?.profileType;
    final isOrganiser = profileType == 'organiser';
    final isVenuesTab = _mainTabIndex == 1;

    // Prefer GPS-reverse-geocoded area; fall back to the nearest area from the
    // DB when that is unavailable (e.g. web where geocoding is unsupported).
    final position = _locationService.currentPosition;
    String? areaLabel = _locationService.currentArea;
    if (areaLabel == null && position != null) {
      final nearest = ref.watch(
        nearestAreaProvider((lat: position.latitude, lng: position.longitude)),
      );
      areaLabel = nearest.valueOrNull?.name;
    }

    return Padding(
      padding: _gutter,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sports',
                  style: _type(
                    context,
                    DabblerType.title1,
                    colors.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space1),
                Row(
                  children: [
                    DabblerIcon(
                      'location',
                      size: 14,
                      color: colors.brandPrimary,
                    ),
                    const SizedBox(width: DabblerSpacing.space1),
                    Flexible(
                      child: Text(
                        areaLabel ?? 'Location not available',
                        style: _type(
                          context,
                          DabblerType.footnote,
                          colors.brandPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: DabblerSpacing.space1),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        showDabblerSheet<void>(
                          context: context,
                          detent: DabblerSheetDetent.content,
                          builder: (context) => const ManualLocationDrawer(),
                        );
                      },
                      child: DabblerIcon(
                        'refresh',
                        size: 14,
                        color: colors.brandPrimary,
                        semanticLabel: 'Change location',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: DabblerSpacing.space3),
          if (isOrganiser && isVenuesTab) ...[
            DabblerButton.icon(
              icon: 'add',
              semanticLabel: 'Add venue',
              onPressed: () => context.push(RoutePaths.createVenueSubmission),
            ),
            const SizedBox(width: DabblerSpacing.space2),
          ],
          DabblerButton.icon(
            icon: 'archive',
            semanticLabel: 'Library',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const SportsLibraryScreen(initialTabIndex: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: _gutter,
      child: Row(
        children: [
          Expanded(
            child: DabblerSearchField(
              controller: _searchController,
              placeholder: FeatureFlags.enableGameBrowsing
                  ? 'Search games and venues'
                  : 'Search venues',
              onChanged: _onSearchChanged,
              onCleared: () => _onSearchChanged(''),
            ),
          ),
          const SizedBox(width: DabblerSpacing.space2),
          DabblerButton.icon(
            icon: 'setting-4',
            semanticLabel: 'Filters',
            onPressed: _showFilterModal,
          ),
          DabblerButton.icon(
            icon: 'sort',
            semanticLabel: _sortTooltip(ref),
            onPressed: _handleSortTap,
          ),
        ],
      ),
    );
  }

  Widget _buildSportsChips() {
    final isVenuesTab = _mainTabIndex == 1;
    final sports = _sportsForChips();
    final selectedIndex = _safeSelectedSportIndex(sports.length);

    if (_selectedSportIndex != selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedSportIndex = selectedIndex;
        });
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: _gutter,
      child: Row(
        children: [
          for (var index = 0; index < sports.length; index++)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: DabblerSpacing.space2,
              ),
              child: _buildSportChip(
                sports[index]['name'] as String,
                selected: selectedIndex == index,
                showCount: selectedIndex == index && isVenuesTab,
                onTap: () => setState(() => _selectedSportIndex = index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSportChip(
    String name, {
    required bool selected,
    required bool showCount,
    required VoidCallback onTap,
  }) {
    // Get the actual venue count from the new provider when selected
    int venueCount = 0;
    if (showCount) {
      final sportId = SportIdMapping.getSportId(name.trim().toLowerCase());
      if (sportId != null) {
        final filters = VenuesBySportFilters(
          sportId: sportId,
          city: _selectedArea,
          isActive: true,
        );
        final venuesAsync = ref.watch(
          venuesBySportWithFiltersProvider(filters),
        );
        venueCount = venuesAsync.maybeWhen(
          data: (venues) => venues.length,
          orElse: () => 0,
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DabblerChip(
          label: name,
          selected: selected,
          leadingIcon: _sportIcon(name),
          onTap: onTap,
        ),
        if (showCount) ...[
          const SizedBox(width: DabblerSpacing.space1),
          DabblerBadge(label: '$venueCount'),
        ],
      ],
    );
  }
}

class _VenuesTabContent extends ConsumerStatefulWidget {
  final String selectedSport;
  final String searchQuery;
  final Map<String, dynamic>? sportSpecificFilters;
  final String? filterArea;
  final DabblerSliderRange? priceRange;
  final double? rating;
  final Set<String>? amenities;

  const _VenuesTabContent({
    super.key,
    required this.selectedSport,
    required this.searchQuery,
    this.sportSpecificFilters,
    this.filterArea,
    this.priceRange,
    this.rating,
    this.amenities,
  });

  @override
  ConsumerState<_VenuesTabContent> createState() => _VenuesTabContentState();
}

class _VenuesTabContentState extends ConsumerState<_VenuesTabContent> {
  @override
  void initState() {
    super.initState();
    // Load venues with sport filter on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilter();
    });
  }

  @override
  void didUpdateWidget(_VenuesTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSport != widget.selectedSport ||
        oldWidget.filterArea != widget.filterArea) {
      // Delay provider update to avoid modifying during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    // Invalidate the provider to trigger a refetch with new filters
    final selectedSportName = widget.selectedSport.trim();
    final sportId = SportIdMapping.getSportId(selectedSportName.toLowerCase());

    if (sportId == null) {
      // If sport ID not found, do nothing
      return;
    }

    final filters = VenuesBySportFilters(
      sportId: sportId,
      city: widget.filterArea,
      isActive: true,
    );

    // Invalidate to force refetch
    ref.invalidate(venuesBySportWithFiltersProvider(filters));
  }

  Future<void> _refreshVenues() async {
    await ref.read(venuesControllerProvider.notifier).refresh();
  }

  void _onVenueTap(String venueId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VenueDetailScreen(venueId: venueId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSportName = widget.selectedSport.trim();
    final sportId = SportIdMapping.getSportId(selectedSportName.toLowerCase());

    // If sport ID not found, show empty state
    if (sportId == null) {
      return _buildEmptyState();
    }

    // Use the new v_venues_with_sports view provider
    final filters = VenuesBySportFilters(
      sportId: sportId,
      city: widget.filterArea,
      isActive: true,
    );

    final venuesAsync = ref.watch(venuesBySportWithFiltersProvider(filters));

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space6),
      child: venuesAsync.when(
        loading: _buildLoadingState,
        error: (error, stack) => _buildErrorState(),
        data: (venues) {
          // Apply search query filter
          final query = widget.searchQuery.toLowerCase();
          final filteredVenues = query.isEmpty
              ? venues
              : venues.where((venue) {
                  final name = venue.nameEn.toLowerCase();
                  final city = venue.city.toLowerCase();
                  return name.contains(query) || city.contains(query);
                }).toList();

          if (filteredVenues.isEmpty) {
            return _buildEmptyState();
          }

          return Padding(
            padding: _gutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < filteredVenues.length; i++) ...[
                  if (i > 0) const SizedBox(height: DabblerSpacing.space3),
                  VenueCard(
                    venue: {
                      'id': filteredVenues[i].id,
                      'name': filteredVenues[i].nameEn,
                      'location': filteredVenues[i].area != null
                          ? '${filteredVenues[i].area}, ${filteredVenues[i].city}'
                          : filteredVenues[i].city,
                      'sports': <String>[selectedSportName],
                      'images': [],
                      'rating': filteredVenues[i].compositeScore ?? 0.0,
                      'isOpen': true,
                      'slots': [],
                      'reviews': [],
                      'distance': '', // Can add distance calculation
                      'price': filteredVenues[i].pricePerHour != null
                          ? 'AED ${filteredVenues[i].pricePerHour!.toStringAsFixed(0)}/hr'
                          : 'Price N/A',
                      'amenities': filteredVenues[i].amenities,
                    },
                    onTap: () => _onVenueTap(filteredVenues[i].id),
                    isLoading: false,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: _gutter,
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: EdgeInsetsDirectional.only(
              bottom: index == 4 ? 0 : DabblerSpacing.space3,
            ),
            child: const VenueCard(venue: {}, isLoading: true),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: _gutter,
      child: DabblerEmptyState.error(
        icon: 'wifi-square',
        title: 'Couldn\'t load venues',
        text: 'Check your connection and try again',
        size: DabblerEmptyStateSize.inline,
        retryLabel: 'Retry',
        onRetry: _refreshVenues,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: _gutter,
      child: DabblerEmptyState(
        icon: 'location',
        title: 'No ${widget.selectedSport} venues found around you',
        text: 'Try a nearby location or add a new venue',
        action: DabblerButton(
          label: 'Add Venue',
          icon: 'add-circle',
          onPressed: () {
            // TODO: Navigate to add venue screen
          },
        ),
      ),
    );
  }
}
