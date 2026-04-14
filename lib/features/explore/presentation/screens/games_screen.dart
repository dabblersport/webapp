import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/core/utils/sport_id_mapping.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_library_screen.dart';
import 'package:dabbler/features/games/presentation/screens/games_nearby_screen.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/themes/app_theme.dart';

// ─── helpers ─────────────────────────────────────────────────────────────────

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

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  late LocationService _locationService;
  int _selectedSportIndex = 0;

  static const List<Map<String, dynamic>> _sports = [
    {'name': 'Football'},
    {'name': 'Cricket'},
    {'name': 'Padel'},
    {'name': 'Basketball'},
    {'name': 'Tennis'},
    {'name': 'Badminton'},
    {'name': 'Running'},
    {'name': 'Swimming'},
    {'name': 'Equestrian'},
    {'name': 'Shooting'},
  ];

  int get _safeIndex => _selectedSportIndex.clamp(0, _sports.length - 1);

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _locationService.addListener(_onLocationChanged);
    _locationService.init();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationChanged);
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 12),
              child: _buildSportsChips(),
            ),
          ),
          SliverToBoxAdapter(
            child: GamesNearbyScreen(
              key: ValueKey('nearby_games_${_sports[_safeIndex]['name']}'),
              sportId: SportIdMapping.getSportId(
                (_sports[_safeIndex]['name'] as String).toLowerCase(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Games',
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
                            style: tt.bodySmall
                                ?.copyWith(color: sportsScheme.primary),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const SportsLibraryScreen(initialTabIndex: 0),
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
                      style: tt.labelMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
