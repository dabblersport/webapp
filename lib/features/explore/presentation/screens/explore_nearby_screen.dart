import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/data/models/nearby/nearby.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/explore/providers/nearby_games_providers.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/utils/helpers/number_formatter.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ExploreNearbyScreen extends ConsumerStatefulWidget {
  const ExploreNearbyScreen({super.key});

  @override
  ConsumerState<ExploreNearbyScreen> createState() =>
      _ExploreNearbyScreenState();
}

class _ExploreNearbyScreenState extends ConsumerState<ExploreNearbyScreen> {
  late LocationService _locationService;

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

  NearbyParams _currentParams() {
    final pos = _locationService.currentPosition;
    final lat = pos?.latitude ?? 25.09;
    final lng = pos?.longitude ?? 55.15;
    return NearbyParams(lat: lat, lng: lng);
  }

  void _invalidateActive(NearbyFilter filter, NearbyParams params) {
    switch (filter) {
      case NearbyFilter.games:
        ref.invalidate(nearbyGamesProvider(params));
      case NearbyFilter.venues:
        ref.invalidate(nearbyVenuesProvider(params));
      case NearbyFilter.players:
        ref.invalidate(nearbyProfilesProvider(params));
      case NearbyFilter.posts:
        ref.invalidate(nearbyPostsProvider(params));
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = _currentParams();
    final activeFilter = ref.watch(nearbyFilterProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explore Nearby', style: tt.titleLarge),
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
                    _locationService.currentArea ?? 'Location not available',
                    style: tt.bodySmall?.copyWith(color: sportsScheme.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
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
        toolbarHeight: 72,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _invalidateActive(activeFilter, params),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ─────────────────────────────────────────────
          _FilterChipBar(
            active: activeFilter,
            onSelected: (f) =>
                ref.read(nearbyFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: 4),
          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: switch (activeFilter) {
              NearbyFilter.games => _GamesTab(params: params),
              NearbyFilter.venues => _VenuesTab(params: params),
              NearbyFilter.players => _PlayersTab(params: params),
              NearbyFilter.posts => _PostsTab(params: params),
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Filter chip bar
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({required this.active, required this.onSelected});

  final NearbyFilter active;
  final ValueChanged<NearbyFilter> onSelected;

  static const _labels = {
    NearbyFilter.games: ('Games', Icons.sports_soccer_rounded),
    NearbyFilter.venues: ('Venues', Iconsax.building_copy),
    NearbyFilter.players: ('Players', Icons.people_outline_rounded),
    NearbyFilter.posts: ('Posts', Iconsax.message_text_1),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: NearbyFilter.values.map((filter) {
          final (label, icon) = _labels[filter]!;
          final selected = filter == active;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              showCheckmark: false,
              avatar: Icon(icon, size: 18),
              label: Text(label),
              selectedColor: cs.primaryContainer,
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Per-entity tab bodies
// ═══════════════════════════════════════════════════════════════════════════════

// ── Games ────────────────────────────────────────────────────────────────────

class _GamesTab extends ConsumerWidget {
  const _GamesTab({required this.params});
  final NearbyParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyGamesProvider(params));
    return async.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorView(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(nearbyGamesProvider(params)),
      ),
      data: (games) => games.isEmpty
          ? const _EmptyView(label: 'games')
          : _EntityList(
              itemCount: games.length,
              builder: (i) => _GameTile(game: games[i]),
            ),
    );
  }
}

// ── Venues ───────────────────────────────────────────────────────────────────

class _VenuesTab extends ConsumerWidget {
  const _VenuesTab({required this.params});
  final NearbyParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyVenuesProvider(params));
    return async.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorView(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(nearbyVenuesProvider(params)),
      ),
      data: (venues) => venues.isEmpty
          ? const _EmptyView(label: 'venues')
          : _EntityList(
              itemCount: venues.length,
              builder: (i) => _VenueTile(venue: venues[i]),
            ),
    );
  }
}

// ── Players ──────────────────────────────────────────────────────────────────

class _PlayersTab extends ConsumerWidget {
  const _PlayersTab({required this.params});
  final NearbyParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyProfilesProvider(params));
    return async.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorView(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(nearbyProfilesProvider(params)),
      ),
      data: (profiles) => profiles.isEmpty
          ? const _EmptyView(label: 'players')
          : _EntityList(
              itemCount: profiles.length,
              builder: (i) => _ProfileTile(profile: profiles[i]),
            ),
    );
  }
}

// ── Posts ─────────────────────────────────────────────────────────────────────

class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.params});
  final NearbyParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyPostsProvider(params));
    return async.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorView(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(nearbyPostsProvider(params)),
      ),
      data: (posts) => posts.isEmpty
          ? const _EmptyView(label: 'posts')
          : _EntityList(
              itemCount: posts.length,
              builder: (i) => _PostTile(post: posts[i]),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared list wrapper
// ═══════════════════════════════════════════════════════════════════════════════

class _EntityList extends StatelessWidget {
  const _EntityList({required this.itemCount, required this.builder});

  final int itemCount;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => builder(i),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Entity tiles
// ═══════════════════════════════════════════════════════════════════════════════

// ── Game tile ────────────────────────────────────────────────────────────────

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game});
  final NearbyGame game;

  static final _timeFormat = DateFormat('EEE d MMM · h:mm a');

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      distanceMeters: game.distanceMeters,
      title: game.title,
      lat: game.lat,
      lng: game.lng,
      children: [
        _IconLabel(
          icon: Icons.calendar_today_rounded,
          label: _timeFormat.format(game.startAt.toLocal()),
        ),
        const SizedBox(height: 4),
        _IconLabel(
          icon: Icons.people_outline_rounded,
          label: '${game.capacity} spots',
        ),
      ],
    );
  }
}

// ── Venue tile ───────────────────────────────────────────────────────────────

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.venue});
  final NearbyVenue venue;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      distanceMeters: venue.distanceMeters,
      title: venue.name,
      lat: venue.lat,
      lng: venue.lng,
      children: [
        if (venue.rating != null)
          _IconLabel(
            icon: Icons.star_rounded,
            label: venue.rating!.toStringAsFixed(1),
          ),
        if (venue.price != null) ...[
          const SizedBox(height: 4),
          _IconLabel(
            icon: Iconsax.money_copy,
            label: 'AED ${venue.price!.toStringAsFixed(0)}',
          ),
        ],
      ],
    );
  }
}

// ── Profile tile ─────────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile});
  final NearbyProfile profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: cs.primaryContainer,
              backgroundImage: profile.avatar != null
                  ? NetworkImage(profile.avatar!)
                  : null,
              child: profile.avatar == null
                  ? Icon(Icons.person, color: cs.onPrimaryContainer)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.username,
                    style: tt.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _IconLabel(
                    icon: Iconsax.location_copy,
                    label: NumberFormatter.formatDistance(
                      profile.distanceMeters,
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
}

// ── Post tile ────────────────────────────────────────────────────────────────

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});
  final NearbyPost post;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.content,
              style: tt.bodyMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.media != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.media!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _IconLabel(
                  icon: Iconsax.location_copy,
                  label: NumberFormatter.formatDistance(post.distanceMeters),
                ),
                const Spacer(),
                _IconLabel(
                  icon: Iconsax.location_copy,
                  label:
                      '${post.lat.toStringAsFixed(4)}, ${post.lng.toStringAsFixed(4)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared tile components
// ═══════════════════════════════════════════════════════════════════════════════

/// Standard tile layout: distance badge on the left, content on the right.
class _BaseTile extends StatelessWidget {
  const _BaseTile({
    required this.distanceMeters,
    required this.title,
    required this.lat,
    required this.lng,
    required this.children,
  });

  final double distanceMeters;
  final String title;
  final double lat;
  final double lng;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Distance badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                NumberFormatter.formatDistance(distanceMeters),
                style: tt.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Location coordinates
                  _IconLabel(
                    icon: Iconsax.location_copy,
                    label:
                        '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    size: 16,
                  ),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small icon + text label row used throughout the tiles.
class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label, this.size = 14});

  final IconData icon;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loading / Error / Empty — shared across all tabs
// ═══════════════════════════════════════════════════════════════════════════════

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Shimmer(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Shimmer(
                    child: Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Shimmer(
                    child: Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Shimmer(
                    child: Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
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
}

/// Wraps a child in an animated shimmer effect without external packages.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _anim, child: widget.child);
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Could not load results',
              style: tt.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off_rounded,
              size: 56,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No $label nearby',
              style: tt.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'There are no $label within range of your location.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
