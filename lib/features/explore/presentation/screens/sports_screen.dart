import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/design_system/ds.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/games/presentation/controllers/venues_controller.dart'
    as vc;
import 'package:dabbler/features/explore/presentation/widgets/sport_specific_filters.dart';
import 'package:dabbler/core/config/sport_filters_config.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/utils/helpers/date_formatter.dart';
import 'package:dabbler/core/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dabbler/features/explore/presentation/widgets/location_permission_drawer.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/venues/providers.dart' as venues_providers;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/core/utils/sport_id_mapping.dart';

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

String _sportEmojiFor(String sport) {
  switch (sport.toLowerCase()) {
    case 'football':
    case 'soccer':
      return '⚽';
    case 'cricket':
      return '🏏';
    case 'padel':
      return '🎾';
    case 'tennis':
      return '🎾';
    case 'basketball':
      return '🏀';
    case 'badminton':
      return '🏸';
    case 'futsal':
      return '⚽';
    case 'running':
      return '🏃';
    case 'swimming':
      return '🏊';
    case 'equestrian':
      return '🐎';
    case 'shooting':
      return '🎯';
    case 'volleyball':
      return '🏐';
    default:
      return '🏃';
  }
}

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
      return _buildSkeletonCard(context);
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

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('sports');

    return Card.filled(
      color: sportsScheme.primary.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with status badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isClosed)
                          Badge.count(
                            count: 0,
                            backgroundColor: colorScheme.errorContainer,
                            textColor: colorScheme.onErrorContainer,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: Text(
                                'Closed',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        Icon(
                          Iconsax.location_copy,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            area,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Distance, Sports and rating
                    Row(
                      children: [
                        // Distance
                        if (distance.isNotEmpty) ...[
                          Icon(
                            Iconsax.routing_copy,
                            size: 14,
                            color: colorScheme.categorySports,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.categorySports,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '•',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],

                        // Sports
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ...visibleSports.map(
                                (sport) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _sportEmojiFor(sport),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      sport,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (sport != visibleSports.last)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          '•',
                                          style: textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (overflowCount > 0)
                                Text(
                                  '+$overflowCount',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Rating
                        if (showRating) ...[
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.star_copy,
                                size: 14,
                                color: colorScheme.categorySports,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.categorySports,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Iconsax.arrow_right_3_copy,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    final sportsScheme = context.getCategoryTheme('sports');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: sportsScheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Skeleton icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: sportsScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(width: 16),

              // Skeleton content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Skeleton title
                    DS.skeleton(height: 18, width: 150),
                    const SizedBox(height: 8),

                    // Skeleton location
                    DS.skeleton(height: 14, width: 120),
                    const SizedBox(height: 10),

                    // Skeleton chips
                    Row(
                      children: [
                        DS.skeleton(height: 24, width: 60),
                        const SizedBox(width: 6),
                        DS.skeleton(height: 24, width: 50),
                      ],
                    ),
                  ],
                ),
              ),

              // Skeleton arrow
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: sportsScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
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

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  late LocationService _locationService;
  int _selectedSportIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSortAscending = true; // default sort by start date ascending

  // Filter state
  String? _selectedArea;
  RangeValues _selectedPriceRange = const RangeValues(0, 500);
  double _selectedRating = 0;
  final Set<String> _selectedAmenities = {};

  // Sport-specific filters (e.g., ball type for cricket, game type for football)
  final Map<String, dynamic> _sportSpecificFilters = {};

  // Primary sports shown in chips
  final List<Map<String, dynamic>> _sports = [
    {
      'name': 'Football',
      'icon': Iconsax.medal_star_copy,
      'description': 'Find football games near you',
    },
    {
      'name': 'Cricket',
      'icon': Iconsax.game_copy,
      'description': 'Join cricket games and tournaments',
    },
    {
      'name': 'Padel',
      'icon': Iconsax.game_copy,
      'description': 'Discover padel courts and players',
    },
    {
      'name': 'Basketball',
      'icon': _sportIconFor('basketball'),
      'description': 'Find basketball courts and games',
    },
    {
      'name': 'Tennis',
      'icon': _sportIconFor('tennis'),
      'description': 'Discover tennis courts and games',
    },
    {
      'name': 'Badminton',
      'icon': _sportIconFor('badminton'),
      'description': 'Find badminton venues and matches',
    },
    {
      'name': 'Running',
      'icon': _sportIconFor('running'),
      'description': 'Explore running routes and events',
    },
    {
      'name': 'Swimming',
      'icon': _sportIconFor('swimming'),
      'description': 'Find swimming pools and sessions',
    },
    {
      'name': 'Equestrian',
      'icon': _sportIconFor('equestrian'),
      'description': 'Discover equestrian venues and activities',
    },
    {
      'name': 'Shooting',
      'icon': _sportIconFor('shooting'),
      'description': 'Find shooting ranges and sessions',
    },
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
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (_mainTabController.indexIsChanging) {
        setState(() {});
      }
    });
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
    final colorScheme = Theme.of(context).colorScheme;
    final sportsScheme = context.getCategoryTheme('sports');

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: sportsScheme),
          child: LocationPermissionDrawer(
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
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationChanged);
    _mainTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _handleSortTap() {
    if (_mainTabController.index == 0) {
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
    if (_mainTabController.index == 0) {
      return _isSortAscending ? 'Sort: Soonest first' : 'Sort: Latest first';
    }

    final venuesState = ref.watch(venuesControllerProvider);
    final ascending = venuesState.sortBy == vc.VenueSortBy.distance
        ? venuesState.ascending
        : true;
    return ascending ? 'Sort: Closest first' : 'Sort: Farthest first';
  }

  void _showFilterModal() {
    final colorScheme = Theme.of(context).colorScheme;
    final sportsScheme = context.getCategoryTheme('sports');

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(colorScheme: sportsScheme),
        child: _buildFiltersBottomSheetContent(),
      ),
    );
  }

  Widget _buildFiltersBottomSheetContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final sportsScheme = context.getCategoryTheme('sports');
    final sports = _sportsForChips();
    final selectedIndex = _safeSelectedSportIndex(sports.length);

    return StatefulBuilder(
      builder: (context, setModalState) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Results',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Sport-Specific Filters
              if (SportFiltersConfig.hasSportSpecificFilters(
                sports[selectedIndex]['name'],
              ))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (SportSpecificFiltersFactory.create(
                          sport: sports[selectedIndex]['name'],
                          selectedFilters: _sportSpecificFilters,
                          onFilterChanged: (key, value) {
                            setModalState(() {
                              if (value == null || value == 'All') {
                                _sportSpecificFilters.remove(key);
                              } else {
                                _sportSpecificFilters[key] = value;
                              }
                            });
                          },
                        ) !=
                        null)
                      SportSpecificFiltersFactory.create(
                        sport: sports[selectedIndex]['name'],
                        selectedFilters: _sportSpecificFilters,
                        onFilterChanged: (key, value) {
                          setModalState(() {
                            if (value == null || value == 'All') {
                              _sportSpecificFilters.remove(key);
                            } else {
                              _sportSpecificFilters[key] = value;
                            }
                          });
                        },
                      )!,
                    const SizedBox(height: 20),
                  ],
                ),
              // Area
              Text(
                'Area',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedArea,
                hint: const Text('Select Area'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: sportsScheme.primary.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.14
                        : 0.12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: sportsScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: sportsScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items:
                    const [
                      'Downtown',
                      'Jumeirah',
                      'Marina',
                      'Business Bay',
                      'Other',
                    ].map((area) {
                      return DropdownMenuItem(value: area, child: Text(area));
                    }).toList(),
                onChanged: (value) =>
                    setModalState(() => _selectedArea = value),
              ),
              const SizedBox(height: 20),
              // Price Range
              Text(
                'Price Range (AED)',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              RangeSlider(
                values: _selectedPriceRange,
                min: 0,
                max: 500,
                divisions: 10,
                activeColor: sportsScheme.primary,
                inactiveColor: sportsScheme.primary.withValues(alpha: 0.18),
                labels: RangeLabels(
                  _selectedPriceRange.start.round().toString(),
                  _selectedPriceRange.end.round().toString(),
                ),
                onChanged: (values) =>
                    setModalState(() => _selectedPriceRange = values),
              ),
              Text(
                'AED ${_selectedPriceRange.start.round()} - AED ${_selectedPriceRange.end.round()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              // Rating
              Text(
                'Minimum Rating',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _selectedRating,
                min: 0,
                max: 5,
                divisions: 5,
                activeColor: sportsScheme.primary,
                inactiveColor: sportsScheme.primary.withValues(alpha: 0.18),
                label: _selectedRating == 0
                    ? 'Any'
                    : _selectedRating.toStringAsFixed(1),
                onChanged: (value) =>
                    setModalState(() => _selectedRating = value),
              ),
              Text(
                _selectedRating == 0
                    ? 'Any rating'
                    : '${_selectedRating.toStringAsFixed(1)}+ stars',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              // Amenities
              Text(
                'Amenities',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    const [
                      'Parking',
                      'Showers',
                      'Indoor',
                      'Outdoor',
                      'Cafeteria',
                    ].map((amenity) {
                      final selected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: selected,
                        backgroundColor: sportsScheme.surfaceContainerHighest,
                        selectedColor: sportsScheme.primaryContainer,
                        checkmarkColor: sportsScheme.onPrimaryContainer,
                        labelStyle: TextStyle(
                          color: selected
                              ? sportsScheme.onPrimaryContainer
                              : sportsScheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selected
                                ? Colors.transparent
                                : sportsScheme.outlineVariant.withValues(
                                    alpha: 0.55,
                                  ),
                          ),
                        ),
                        onSelected: (selectedNow) {
                          setModalState(() {
                            if (selectedNow) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedArea = null;
                          _selectedPriceRange = const RangeValues(0, 500);
                          _selectedRating = 0;
                          _selectedAmenities.clear();
                          _sportSpecificFilters.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: sportsScheme.primary,
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          // Apply filters
                        });
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: sportsScheme.primary,
                        foregroundColor: sportsScheme.onPrimary,
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    if (_mainTabController.index == 0) {
      final _ = await ref.refresh(publicGamesProvider.future);
    } else {
      await ref.read(venuesControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Safe-area top spacing
            SliverToBoxAdapter(
              child: SizedBox(
                height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
              ),
            ),

            // ── Header ──
            SliverToBoxAdapter(child: _buildHeader()),

            // ── Tab switcher ──
            SliverToBoxAdapter(child: _buildTabSwitcher()),

            // ── Search row ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: _buildSearchRow(),
              ),
            ),

            // ── Sports chips ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 9, bottom: 12),
                child: _buildSportsChips(),
              ),
            ),

            // ── Tab content (games / venues) ──
            SliverToBoxAdapter(
              child: _mainTabController.index == 0
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
      padding: const EdgeInsets.all(16),
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.game_copy,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${sports[selectedIndex]['name']} games found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to create one!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: searchFilteredGames.length,
                itemBuilder: (context, index) {
                  final game = searchFilteredGames[index];
                  return _buildGameCard(game);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.danger_copy,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load games',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.refresh(publicGamesAsync),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameCard(game) {
    final sportsScheme = context.getCategoryTheme('sports');

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
          color: sportsScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 0.50,
              strokeAlign: BorderSide.strokeAlignCenter,
              color: sportsScheme.outline.withValues(alpha: 0.1),
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
                    Icon(
                      _sportIconFor(game.sport),
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      game.sport,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      game.skillLevel,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: Theme.of(context).colorScheme.onSurface,
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
                    Icon(
                      Iconsax.clock_copy,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormatter.formatDate(game.scheduledDate)} • ${game.startTime} - ${game.endTime}',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.9),
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
                    Icon(
                      Iconsax.location_copy,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        game.venueName ?? 'Venue TBD',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.9),
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
                      Icon(
                        Iconsax.profile_2user_copy,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${game.currentPlayers}/${game.maxPlayers}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  // Only show Join button for players with permission
                  if (_shouldShowJoinButton())
                    GestureDetector(
                      onTap: () {
                        // Navigate to game detail to join
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                GameDetailScreen(gameId: game.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: ShapeDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.categorySports.withValues(alpha: 0.9),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.12),
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.add_copy,
                              size: 18,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Join',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                height: 1.43,
                              ),
                            ),
                          ],
                        ),
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
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      child: _buildVenuesTab(
        sports[selectedIndex]['name'],
        _searchQuery,
        sportSpecificFilters: _sportSpecificFilters,
        filterArea: _selectedArea,
        priceRange: _selectedPriceRange,
        rating: _selectedRating,
        amenities: _selectedAmenities,
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('sports');

    final profileState = ref.watch(profileControllerProvider);
    final profileType = profileState.profile?.profileType;
    final isOrganiser = profileType == 'organiser';
    final isVenuesTab = _mainTabController.index == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sports',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: sportsScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Iconsax.location_copy,
                      size: 14,
                      color: sportsScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _locationService.currentArea ??
                            'Location not available',
                        style: textTheme.bodySmall?.copyWith(
                          color: sportsScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final colorScheme = Theme.of(context).colorScheme;
                        final sportsScheme = context.getCategoryTheme('sports');

                        showModalBottomSheet<void>(
                          context: context,
                          useSafeArea: true,
                          isScrollControlled: true,
                          isDismissible: true,
                          enableDrag: true,
                          showDragHandle: true,
                          backgroundColor: colorScheme.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          builder: (context) => Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(colorScheme: sportsScheme),
                            child: const ManualLocationDrawer(),
                          ),
                        );
                      },
                      child: Icon(
                        Iconsax.refresh_copy,
                        size: 14,
                        color: sportsScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isOrganiser && isVenuesTab) ...[
            IconButton.filledTonal(
              onPressed: () => context.push(RoutePaths.createVenueSubmission),
              icon: const Icon(Iconsax.add_copy),
              tooltip: 'Add venue',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.categorySports.withValues(
                  alpha: 0.0,
                ),
                foregroundColor: colorScheme.onSurface,
                minimumSize: const Size(48, 48),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton.filledTonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const SportsLibraryScreen(initialTabIndex: 1),
                ),
              );
            },
            icon: const Icon(Iconsax.archive_copy),
            tooltip: 'Library',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.categorySports.withValues(
                alpha: 0.0,
              ),
              foregroundColor: colorScheme.categorySports,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('sports');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.game_copy, size: 18),
                  SizedBox(width: 8, height: 30),
                  Text('Games'),
                ],
              ),
            ),
            ButtonSegment(
              value: 1,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.building_copy, size: 18),
                  SizedBox(width: 8),
                  Text('Venues'),
                ],
              ),
            ),
          ],
          selected: <int>{_mainTabController.index},
          onSelectionChanged: (Set<int> newSelection) {
            final newIndex = newSelection.first;
            if (_mainTabController.index != newIndex) {
              setState(() {
                _mainTabController.index = newIndex;
              });
            }
          },
          style: ButtonStyle(
            side: WidgetStateProperty.all(
              const BorderSide(color: Colors.transparent),
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return sportsScheme.primary.withValues(alpha: 1);
              }
              return sportsScheme.primary.withValues(alpha: 0.1);
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          showSelectedIcon: false,
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    final colorScheme = Theme.of(context).colorScheme;
    final sportsScheme = context.getCategoryTheme('sports');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: sportsScheme.primary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: sportsScheme.primary.withValues(alpha: 0.12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: sportsScheme.primary,
                      width: 2,
                    ),
                  ),
                  hintText: 'Search games and venues',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Iconsax.search_normal_copy,
                      color: sportsScheme.primary,
                      size: 24,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filledTonal(
              onPressed: _showFilterModal,
              icon: const Icon(Iconsax.setting_4_copy),
              style: IconButton.styleFrom(
                backgroundColor: sportsScheme.primary.withValues(alpha: 0.0),
                foregroundColor: sportsScheme.primary,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filledTonal(
              onPressed: _handleSortTap,
              tooltip: _sortTooltip(ref),
              icon: const Icon(Iconsax.sort_copy),
              style: IconButton.styleFrom(
                backgroundColor: sportsScheme.primary.withValues(alpha: 0.0),
                foregroundColor: sportsScheme.primary,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsChips() {
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('sports');
    final isVenuesTab = _mainTabController.index == 1;
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

    final selectedSportKey = sports.isEmpty
        ? 'football'
        : (sports[selectedIndex]['name'] as String).trim().toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 24),
            ...List.generate(sports.length, (index) {
              final sport = sports[index];
              final isSelected = selectedIndex == index;
              final chipBackground = isSelected
                  ? sportsScheme.primary
                  : sportsScheme.primary.withValues(alpha: 0.12);
              final chipForeground = isSelected
                  ? sportsScheme.onPrimary
                  : sportsScheme.primary;

              // Get the actual venue count from the new provider when selected
              int venueCount = 0;
              if (isSelected && isVenuesTab) {
                final sportName = (sport['name'] as String).trim();
                final sportId = SportIdMapping.getSportId(
                  sportName.toLowerCase(),
                );

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

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSportIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sportEmojiFor((sport['name'] as String?) ?? ''),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sport['name'] as String,
                        style: textTheme.labelMedium?.copyWith(
                          color: chipForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isSelected && isVenuesTab) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: sportsScheme.onPrimary.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$venueCount',
                            style: textTheme.labelSmall?.copyWith(
                              color: sportsScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVenuesTab(
    String selectedSport,
    String searchQuery, {
    Map<String, dynamic>? sportSpecificFilters,
    String? filterArea,
    RangeValues? priceRange,
    double? rating,
    Set<String>? amenities,
  }) {
    return _VenuesTabContent(
      key: ValueKey('venues_$selectedSport'),
      selectedSport: selectedSport,
      searchQuery: searchQuery,
      sportSpecificFilters: sportSpecificFilters,
      filterArea: filterArea,
      priceRange: priceRange,
      rating: rating,
      amenities: amenities,
    );
  }
}

class FavoriteVenuesScreen extends ConsumerWidget {
  const FavoriteVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('sports');

    final favoritesAsync = ref.watch(
      venues_providers.favoriteVenuesForCurrentUserProvider,
    );
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
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
                  Icon(Iconsax.star_1_copy, size: 20, color: sportsScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Favorite venues',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: sportsScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: favoritesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: sportsScheme.primary),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.danger_copy, size: 48, color: sportsScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Couldn\'t load saved venues',
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
                      Iconsax.heart_copy,
                      size: 64,
                      color: sportsScheme.primary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved venues yet',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: venues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final venue = venues[index];
              final venueMap = {
                'id': venue.id,
                'name': venue.name,
                'location': venue.state.isNotEmpty
                    ? '${venue.state}, ${venue.city}'
                    : '${venue.city}, ${venue.country}',
                'sports': venue.supportedSports,
                'images': [],
                'rating': venue.rating,
                'isOpen': venue.isOpenAt(DateTime.now()),
                'slots': [],
                'reviews': List.generate(
                  venue.totalRatings >= 3 ? 3 : venue.totalRatings,
                  (_) => <String, dynamic>{},
                ),
                'distance': '',
                'price': venue.pricePerHour > 0
                    ? '${venue.currency} ${venue.pricePerHour.toStringAsFixed(0)}/hr'
                    : 'Free',
                'amenities': venue.amenities,
              };

              return VenueCard(
                venue: venueMap,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          VenueDetailScreen(venueId: venue.id),
                    ),
                  );
                },
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

class _VenuesTabContent extends ConsumerStatefulWidget {
  final String selectedSport;
  final String searchQuery;
  final Map<String, dynamic>? sportSpecificFilters;
  final String? filterArea;
  final RangeValues? priceRange;
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll can be implemented if needed
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
      padding: const EdgeInsets.only(bottom: 24),
      child: venuesAsync.when(
        loading: () => _buildLoadingState(),
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredVenues.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final venue = filteredVenues[index];

                    final venueMap = {
                      'id': venue.id,
                      'name': venue.nameEn,
                      'location': venue.area != null
                          ? '${venue.area}, ${venue.city}'
                          : venue.city,
                      'sports': <String>[selectedSportName],
                      'images': [],
                      'rating': venue.compositeScore ?? 0.0,
                      'isOpen': true,
                      'slots': [],
                      'reviews': [],
                      'distance': '', // Can add distance calculation
                      'price': venue.pricePerHour != null
                          ? 'AED ${venue.pricePerHour!.toStringAsFixed(0)}/hr'
                          : 'Price N/A',
                      'amenities': venue.amenities,
                    };

                    return VenueCard(
                      venue: venueMap,
                      onTap: () => _onVenueTap(venue.id),
                      isLoading: false,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 4 ? 0 : 12),
            child: const VenueCard(venue: {}, isLoading: true),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final sportsScheme = context.getCategoryTheme('sports');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sportsScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Iconsax.wifi_square_copy,
                size: 48,
                color: sportsScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Couldn\'t load venues',
              style: DS.headline.copyWith(
                fontWeight: FontWeight.w700,
                color: sportsScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: DS.body.copyWith(color: sportsScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _refreshVenues,
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
    );
  }

  Widget _buildEmptyState() {
    final sportsScheme = context.getCategoryTheme('sports');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/undraw/walking-outside.svg',
              height: 200,
              width: 200,
              colorFilter: ColorFilter.mode(
                sportsScheme.primary,
                BlendMode.srcIn,
              ),
              placeholderBuilder: (context) => SizedBox(
                height: 200,
                width: 200,
                child: Center(
                  child: CircularProgressIndicator(color: sportsScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No ${widget.selectedSport} venues found around you',
              style: DS.headline.copyWith(
                fontWeight: FontWeight.w700,
                color: sportsScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a nearby location or add a new venue',
              style: DS.body.copyWith(color: sportsScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // TODO: Navigate to add venue screen
              },
              icon: const Icon(Iconsax.add_circle_copy),
              label: const Text('Add Venue'),
              style: FilledButton.styleFrom(
                backgroundColor: sportsScheme.primary,
                foregroundColor: sportsScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
