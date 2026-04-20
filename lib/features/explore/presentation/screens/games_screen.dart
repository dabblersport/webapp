import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/core/utils/sport_id_mapping.dart';
import 'package:dabbler/core/widgets/shimmer_loading.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_bar.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

// =============================================================================
// SCREEN
// =============================================================================

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen>
    with TickerProviderStateMixin {
  static const List<String> _tabs = [
    'All',
    'Football',
    'Cricket',
    'Padel',
    'Basketball',
    'Tennis',
    'Badminton',
    'Running',
    'Swimming',
    'Equestrian',
    'Shooting',
  ];

  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;

  late final TabController _tabController;
  late final List<ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _scrollControllers =
        List.generate(_tabs.length, (_) => ScrollController());
    _tabController.addListener(_onTabChanged);
    _loadUserProfile();
  }

  @override
  void dispose() {
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  Future<void> _loadUserProfile() async {
    try {
      final activeType = ref.read(activeProfileTypeProvider);
      final profile =
          await _authService.getUserProfile(personaType: activeType);
      if (mounted) setState(() => _userProfile = profile);
    } catch (_) {}
  }

  String _resolveDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'User';
    final displayName = (profile['display_name'] as String?)?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    final username = (profile['username'] as String?)?.trim() ?? '';
    if (username.isNotEmpty) return username;
    final email = (profile['email'] as String?)?.trim() ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'User';
  }

  String? _sportIdForTab(int index) {
    if (index == 0) return null; // "All"
    return SportIdMapping.getSportId(_tabs[index].toLowerCase());
  }

  Future<void> _handleRefresh() async {
    final sportId = _sportIdForTab(_tabController.index);
    const params = (
      lat: null,
      lng: null,
      radiusMeters: null,
      sportId: null,
      sortOrder: NearbySortOrder.nearest,
    );
    // Invalidate for current tab
    ref.invalidate(nearbyGamesProvider((
      lat: null,
      lng: null,
      radiusMeters: null,
      sportId: sportId,
      sortOrder: NearbySortOrder.nearest,
    )));
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsScheme = context.getCategoryTheme('main');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Games',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: sportsScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.push(RoutePaths.socialSearch),
                icon: const Icon(Iconsax.search_normal_1_copy),
                style: IconButton.styleFrom(
                  foregroundColor: cs.onSurface,
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => context.push(RoutePaths.notifications),
                    icon: const Icon(Iconsax.notification_copy),
                    style: IconButton.styleFrom(
                      foregroundColor: cs.onSurface,
                    ),
                  ),
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: NotificationBadge(),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => context.push(RoutePaths.profile),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: DSAvatar.small(
                    imageUrl: _userProfile?['avatar_url'] as String?,
                    displayName: _resolveDisplayName(_userProfile),
                    context: AvatarContext.main,
                  ),
                ),
              ),
            ],
          ),
        ),
        const HomeLocationBar(),
      ],
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final isSelected = _tabController.index == index;
              final label = index == 0
                  ? 'All'
                  : '${_emojiFor(_tabs[index])} ${_tabs[index]}';

              return GestureDetector(
                onTap: () => _tabController.animateTo(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Text(
                    label,
                    style: tt.labelLarge?.copyWith(
                      color: isSelected
                          ? cs.onPrimary
                          : cs.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: cs.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  isWide ? 16 : MediaQuery.of(context).padding.top + 8,
            ),
          ),
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: _buildTabBar(),
              cs: cs,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: List.generate(
            _tabs.length,
            (i) => _GameTabBody(
              sportId: _sportIdForTab(i),
              scrollController: _scrollControllers[i],
              onRefresh: _handleRefresh,
              onRetry: () => ref.invalidate(nearbyGamesProvider((
                lat: null,
                lng: null,
                radiusMeters: null,
                sportId: _sportIdForTab(i),
                sortOrder: NearbySortOrder.nearest,
              ))),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TAB BAR DELEGATE
// =============================================================================

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabBar, required this.cs});

  final Widget tabBar;
  final ColorScheme cs;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: cs.surface,
      child: Column(
        children: [
          const SizedBox(height: 9),
          Expanded(child: tabBar),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 0,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.cs != cs || old.tabBar != tabBar;
}

// =============================================================================
// GAME TAB BODY
// =============================================================================

class _GameTabBody extends ConsumerWidget {
  const _GameTabBody({
    required this.sportId,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final String? sportId;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final params = (
      lat: null,
      lng: null,
      radiusMeters: null,
      sportId: sportId,
      sortOrder: NearbySortOrder.nearest,
    );

    final gamesAsync = ref.watch(nearbyGamesProvider(params));

    return gamesAsync.when(
      loading: () => const _GameSkeletonList(),
      error: (e, _) => _ErrorView(
        message: "Couldn't load games",
        onRetry: onRetry,
      ),
      data: (games) {
        if (games.isEmpty) {
          return const _EmptyView(
            message: 'No games yet',
            hint: 'Be the first to create a game in your area!',
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: games.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
            itemBuilder: (_, i) => _GameCard(game: games[i]),
          ),
        );
      },
    );
  }
}

// =============================================================================
// GAME CARD
// =============================================================================

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final NearbyGameModel game;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameDetailScreen(gameId: game.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ──────────────────────────────────────────────
            Row(
              children: [
                if (game.sportName != null) ...[
                  Text(
                    _emojiFor(game.sportName ?? ''),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    game.title,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: game.status),
              ],
            ),
            const SizedBox(height: 6),

            // ── Time ───────────────────────────────────────────────────
            if (game.scheduledAt != null)
              Row(
                children: [
                  Icon(Iconsax.clock_copy, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(game.scheduledAt!),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),

            // ── Venue ──────────────────────────────────────────────────
            if (game.venueName?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Iconsax.location_copy,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      game.venueName!,
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // ── Spots remaining ────────────────────────────────────────
            if (game.spotsRemaining != null) ...[
              const SizedBox(height: 8),
              _SmallChip(
                label: game.spotsRemaining! > 0
                    ? '${game.spotsRemaining} spots left'
                    : 'Full',
                highlight: game.spotsRemaining! == 0,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
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
  const _StatusChip({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color bg;
    final Color fg;
    final String label;

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
      case 'cancelled':
        bg = cs.errorContainer.withValues(alpha: 0.5);
        fg = cs.onSurfaceVariant;
        label = 'Cancelled';
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
        style: tt.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// =============================================================================
// SMALL CHIP
// =============================================================================

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? cs.errorContainer : cs.surfaceContainerHigh,
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
// SKELETON
// =============================================================================

class _GameSkeletonList extends StatelessWidget {
  const _GameSkeletonList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: 6,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: cs.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (_, __) => const _GameCardSkeleton(),
    );
  }
}

class _GameCardSkeleton extends StatelessWidget {
  const _GameCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerLoading(
                width: 24,
                height: 24,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 8),
              const Expanded(child: ShimmerLoading(height: 14)),
              const SizedBox(width: 8),
              ShimmerLoading(
                width: 64,
                height: 22,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const ShimmerLoading(width: 120, height: 12),
          const SizedBox(height: 6),
          const ShimmerLoading(width: 100, height: 12),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY / ERROR VIEWS
// =============================================================================

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.game_copy,
              size: 48,
              color: cs.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: tt.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================

String _emojiFor(String sport) {
  switch (sport.toLowerCase()) {
    case 'football':
    case 'soccer':
    case 'futsal':
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
