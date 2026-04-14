import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/themes/app_theme.dart';

// =============================================================================
// SCREEN
// =============================================================================

/// Renders the Games Nearby list inside the Sports → Games tab.
///
/// Accepts [sportId] (nullable) forwarded from the sport-chip selection above.
class GamesNearbyScreen extends ConsumerStatefulWidget {
  const GamesNearbyScreen({super.key, this.sportId});

  /// UUID of the selected sport filter, or null for "all sports".
  final String? sportId;

  @override
  ConsumerState<GamesNearbyScreen> createState() => _GamesNearbyScreenState();
}

class _GamesNearbyScreenState extends ConsumerState<GamesNearbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locState = ref.read(activeLocationProvider).valueOrNull;
      if (locState is ActiveLocationReady) {
        ref
            .read(activeLocationProvider.notifier)
            .setRadiusOverride(locState.location.nearbyRadiusMeters);
      }
    });
  }

  @override
  void dispose() {
    ref.read(activeLocationProvider.notifier).clearRadiusOverride();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final result = await NearbyFilterSheet.show(context);
    if (result == null || !mounted) return;
    ref.read(nearbyGameSortProvider.notifier).state = result.sortOrder;
    // Radius update is handled by NearbyRadiusSlider inside the sheet.
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locAsync = ref.watch(activeLocationProvider);

    return locAsync.when(
      loading: () => _buildSkeletons(),
      error: (_, __) => _buildDeniedState(),
      data: (locState) => switch (locState) {
        ActiveLocationLoading() => _buildSkeletons(),
        ActiveLocationDenied() => _buildDeniedState(),
        ActiveLocationError() => _buildDeniedState(),
        ActiveLocationReady(:final location) => _buildReady(location),
      },
    );
  }

  Widget _buildReady(ActiveLocation location) {
    final sortOrder = ref.watch(nearbyGameSortProvider);
    final radiusMeters = location.nearbyRadiusMeters;

    final params = (
      lat: location.lat,
      lng: location.lng,
      radiusMeters: radiusMeters,
      sportId: widget.sportId,
      sortOrder: sortOrder,
    );

    final gamesAsync = ref.watch(nearbyGamesProvider(params));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter bar ───────────────────────────────────────────────────
        _FilterBar(
          areaName: location.area.name,
          radiusMeters: radiusMeters,
          sortOrder: sortOrder,
          onFilterTap: _openFilterSheet,
        ),

        // ── List ─────────────────────────────────────────────────────────
        gamesAsync.when(
          loading: () => _buildSkeletons(),
          error: (e, _) => _buildErrorState(e, params),
          data: (games) => games.isEmpty
              ? _buildEmptyState(radiusMeters)
              : _NearbyGameList(games: games),
        ),
      ],
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildSkeletons() {
    return Column(
      children: List.generate(
        5,
        (i) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _NearbyGameCardSkeleton(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(int radiusMeters) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final km = (radiusMeters / 1000).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.game_copy,
              size: 56,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'No games within $km km',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try expanding your search radius in the filter.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openFilterSheet,
              icon: const Icon(Iconsax.setting_4_copy, size: 18),
              label: const Text('Adjust filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeniedState() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.location_slash_copy,
              size: 56,
              color: cs.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Location unavailable',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable location or set a saved location to see games nearby.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(activeLocationProvider.notifier).useGpsLocation(),
              icon: const Icon(Iconsax.gps_copy, size: 18),
              label: const Text('Enable GPS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, NearbyGamesParams params) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.wifi_square_copy, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              "Couldn't load games",
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ref.invalidate(nearbyGamesProvider(params)),
              icon: const Icon(Iconsax.refresh_copy, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FILTER BAR
// =============================================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.areaName,
    required this.radiusMeters,
    required this.sortOrder,
    required this.onFilterTap,
  });

  final String areaName;
  final int radiusMeters;
  final NearbySortOrder sortOrder;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');
    final km = (radiusMeters / 1000).round();
    final sortLabel =
        sortOrder == NearbySortOrder.nearest ? 'Nearest first' : 'Soonest first';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Iconsax.location_copy, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$areaName  ·  $km km  ·  $sortLabel',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sportsScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.setting_4_copy,
                    size: 14,
                    color: sportsScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: tt.labelSmall?.copyWith(
                      color: sportsScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LIST
// =============================================================================

class _NearbyGameList extends StatelessWidget {
  const _NearbyGameList({required this.games});

  final List<NearbyGameModel> games;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: games.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _NearbyGameCard(game: games[i]),
    );
  }
}

// =============================================================================
// CARD
// =============================================================================

class _NearbyGameCard extends StatelessWidget {
  const _NearbyGameCard({required this.game});

  final NearbyGameModel game;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetailScreen(gameId: game.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');

    return Card.filled(
      color: sportsScheme.primary.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title row with distance badge ──────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DistanceBadge(
                          label: game.distanceLabel,
                          cs: cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // ── Sport + Status row ─────────────────────────────
                    Row(
                      children: [
                        if (game.sportName?.isNotEmpty == true) ...[
                          Text(
                            game.sportName!,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _StatusChip(status: game.status, cs: cs),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Scheduled time ─────────────────────────────────
                    if (game.scheduledAt != null)
                      Row(
                        children: [
                          Icon(
                            Iconsax.clock_copy,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatScheduledTime(game.scheduledAt!),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),

                    // ── Venue ──────────────────────────────────────────
                    if (game.venueName?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Iconsax.location_copy,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              game.venueName!,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Spots remaining ────────────────────────────────
                    if (game.spotsRemaining != null) ...[
                      const SizedBox(height: 8),
                      _SmallChip(
                        label: game.spotsRemaining! > 0
                            ? '${game.spotsRemaining} spots left'
                            : 'Full',
                        cs: cs,
                        highlight: game.spotsRemaining! == 0,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Today 6 PM" / "Tomorrow 10 AM" / "14 Apr  3 PM"
  static String _formatScheduledTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(dt.year, dt.month, dt.day);
    final diff = gameDay.difference(today).inDays;
    final timeStr = DateFormat('h a').format(dt);
    if (diff == 0) return 'Today  $timeStr';
    if (diff == 1) return 'Tomorrow  $timeStr';
    return '${DateFormat('d MMM').format(dt)}  $timeStr';
  }
}

// =============================================================================
// STATUS CHIP
// =============================================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.cs});

  final String? status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    Color bg;
    Color fg;
    String label;

    switch (status?.toLowerCase()) {
      case 'live':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        label = 'Live';
        break;
      case 'ended':
        bg = cs.surfaceContainerHigh;
        fg = cs.onSurfaceVariant;
        label = 'Ended';
        break;
      default:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        label = 'Upcoming';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// DISTANCE BADGE
// =============================================================================

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.routing_copy, size: 12, color: cs.onPrimaryContainer),
          const SizedBox(width: 3),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SMALL CHIP
// =============================================================================

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.cs,
    this.highlight = false,
  });

  final String label;
  final ColorScheme cs;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? cs.errorContainer
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? cs.error.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: highlight ? cs.onErrorContainer : cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// =============================================================================
// SKELETON CARD
// =============================================================================

class _NearbyGameCardSkeleton extends StatelessWidget {
  const _NearbyGameCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: box(180, 16)),
              const SizedBox(width: 8),
              box(56, 22),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              box(60, 12),
              const SizedBox(width: 8),
              box(56, 18),
            ],
          ),
          const SizedBox(height: 8),
          box(140, 12),
          const SizedBox(height: 6),
          box(120, 12),
        ],
      ),
    );
  }
}
