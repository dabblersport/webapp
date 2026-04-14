import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/core/utils/sport_id_mapping.dart';
import 'package:dabbler/features/explore/presentation/widgets/location_permission_drawer.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/features/venues/presentation/screens/venues_nearby_screen.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:geolocator/geolocator.dart';

// ─── helpers (local copies) ──────────────────────────────────────────────────

String _sportEmojiFor(String sport) {
  switch (sport.toLowerCase()) {
    case 'football':
    case 'soccer':
      return '⚽';
    case 'cricket':
      return '🏏';
    case 'padel':
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

// =============================================================================
// SCREEN
// =============================================================================

class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({super.key});

  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  late LocationService _locationService;
  int _selectedSportIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, dynamic>> _sports = [
    {'name': 'Football', 'emoji': '⚽'},
    {'name': 'Cricket', 'emoji': '🏏'},
    {'name': 'Padel', 'emoji': '🎾'},
    {'name': 'Basketball', 'emoji': '🏀'},
    {'name': 'Tennis', 'emoji': '🎾'},
    {'name': 'Badminton', 'emoji': '🏸'},
    {'name': 'Running', 'emoji': '🏃'},
    {'name': 'Swimming', 'emoji': '🏊'},
    {'name': 'Equestrian', 'emoji': '🐎'},
    {'name': 'Shooting', 'emoji': '🎯'},
  ];

  int get _safeIndex =>
      _selectedSportIndex.clamp(0, _sports.length - 1);

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _locationService.addListener(_onLocationChanged);
    _initLocation();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initLocation() async {
    await _locationService.init();
    await _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final shouldShow = await _locationService.shouldShowLocationPrompt();
    if (!shouldShow || !mounted) return;
    final permission = await _locationService.checkPermissionStatus();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLocationDrawer();
      });
    }
  }

  void _showLocationDrawer() {
    final cs = Theme.of(context).colorScheme;
    final sportsScheme = context.getCategoryTheme('main');
    showAdaptiveSheet<void>(
      context: context,
      colorSchemeOverride: sportsScheme,
      backgroundColor: cs.surface,
      builder: (context) => LocationPermissionDrawer(
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
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
              ),
            ),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: _buildSearchRow(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 9, bottom: 12),
                child: _buildSportsChips(),
              ),
            ),
            SliverToBoxAdapter(
              child: VenuesNearbyScreen(
                key: ValueKey('nearby_${_sports[_safeIndex]['name']}'),
                sportId: SportIdMapping.getSportId(
                  (_sports[_safeIndex]['name'] as String).toLowerCase(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');
    final profileState = ref.watch(profileControllerProvider);
    final isOrganiser = profileState.profile?.profileType == 'organiser';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Venues',
                  style: tt.headlineSmall?.copyWith(
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
                      child: Builder(
                        builder: (context) {
                          final position = _locationService.currentPosition;
                          String? areaLabel = _locationService.currentArea;
                          if (areaLabel == null && position != null) {
                            final nearest = ref.watch(
                              nearestAreaProvider((
                                lat: position.latitude,
                                lng: position.longitude,
                              )),
                            );
                            areaLabel = nearest.valueOrNull?.name;
                          }
                          return Text(
                            areaLabel ?? 'Location not available',
                            style: tt.bodySmall?.copyWith(
                              color: sportsScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final sportsScheme = context.getCategoryTheme('main');
                        showAdaptiveSheet<void>(
                          context: context,
                          colorSchemeOverride: sportsScheme,
                          backgroundColor: cs.surface,
                          builder: (context) => const ManualLocationDrawer(),
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
          if (isOrganiser) ...[
            IconButton.filledTonal(
              onPressed: () => context.push(RoutePaths.createVenueSubmission),
              icon: const Icon(Iconsax.add_copy),
              tooltip: 'Add venue',
              style: IconButton.styleFrom(
                backgroundColor:
                    cs.categoryMain.withValues(alpha: 0.0),
                foregroundColor: cs.onSurface,
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
              backgroundColor: cs.categoryMain.withValues(alpha: 0.0),
              foregroundColor: cs.categoryMain,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    final cs = Theme.of(context).colorScheme;
    final sportsScheme = context.getCategoryTheme('main');

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
                    borderSide:
                        BorderSide(color: sportsScheme.primary, width: 2),
                  ),
                  hintText: 'Search venues',
                  hintStyle:
                      TextStyle(fontSize: 15, color: cs.onSurface),
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
                onChanged: (_) {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsChips() {
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');
    final safeIndex = _safeIndex;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 24),
          ...List.generate(_sports.length, (index) {
            final sport = _sports[index];
            final isSelected = safeIndex == index;
            final bg = isSelected
                ? sportsScheme.primary
                : sportsScheme.primary.withValues(alpha: 0.12);
            final fg =
                isSelected ? sportsScheme.onPrimary : sportsScheme.primary;

            int venueCount = 0;
            if (isSelected) {
              final sportId = SportIdMapping.getSportId(
                (sport['name'] as String).toLowerCase(),
              );
              if (sportId != null) {
                final filters = VenuesBySportFilters(
                  sportId: sportId,
                  city: null,
                  isActive: true,
                );
                venueCount = ref
                    .watch(venuesBySportWithFiltersProvider(filters))
                    .maybeWhen(data: (v) => v.length, orElse: () => 0);
              }
            }

            return GestureDetector(
              onTap: () => setState(() => _selectedSportIndex = index),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sportEmojiFor(sport['name'] as String),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sport['name'] as String,
                      style: tt.labelMedium
                          ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: sportsScheme.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$venueCount',
                          style: tt.labelSmall?.copyWith(
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
    );
  }

}
