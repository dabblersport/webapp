import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';

import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/core/widgets/shimmer_loading.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/widgets/dynamic_background.dart';
import 'package:dabbler/core/feed/post_layout_resolver.dart';
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/services/notifications/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dabbler/features/home/presentation/widgets/notification_permission_drawer.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:dabbler/app/app_router.dart';

/// Modern home screen for Dabbler
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with RouteAware, TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;

  // ── Tab controller ──────────────────────────────────────────────────────────
  late final TabController _tabController;
  static const List<FeedTab> _tabs = FeedTab.values;

  // One scroll controller per tab for independent pagination.
  late final List<ScrollController> _scrollControllers;

  FeedTab get _activeTab => _tabs[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _scrollControllers = List.generate(_tabs.length, (_) => ScrollController());

    // Attach pagination listeners to each scroll controller.
    for (var i = 0; i < _tabs.length; i++) {
      final tab = _tabs[i];
      final sc = _scrollControllers[i];
      sc.addListener(() => _onScroll(tab, sc));
    }

    // Tab switch → ensure the newly visible tab is loaded (lazy load).
    _tabController.addListener(_onTabChanged);

    _loadUserProfile();
    _checkNotificationPermission();

    // For You is the default tab — pre-load it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedNotifierProvider.notifier).load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      AppRouter.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    AppRouter.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to home screen from another screen
    // Reload user profile to sync any changes (e.g., avatar updates from profile edit)
    _loadUserProfile();
  }

  Future<void> _checkNotificationPermission() async {
    // Only check on mobile platforms
    if (!defaultTargetPlatform.toString().contains('android') &&
        !defaultTargetPlatform.toString().contains('iOS')) {
      return;
    }

    final notificationService = PushNotificationService.instance;
    final shouldShow = await notificationService.shouldShowNotificationPrompt();

    if (!shouldShow || !mounted) return;

    final status = await notificationService.checkPermissionStatus();

    // Only show drawer if permission is not already granted
    if (status != AuthorizationStatus.authorized &&
        status != AuthorizationStatus.provisional) {
      // Wait for first frame to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNotificationDrawer();
        }
      });
    }
  }

  Future<void> _showNotificationDrawer() async {
    final didTakeAction = await showAdaptiveSheet<bool>(
      context: context,
      builder: (context) {
        return NotificationPermissionDrawer(
          onEnableNotifications: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            final granted = await notificationService
                .requestNotificationPermission();

            if (!mounted) return;

            if (granted) {
              await notificationService.saveNotificationPreference('allow');
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications enabled!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              // Don't mark as "allow" unless permission is actually granted.
              // Also avoid re-prompting immediately.
              await notificationService.saveNotificationPreference(
                'remind_later',
              );
            }
          },
          onRemindLater: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            await notificationService.saveNotificationPreference(
              'remind_later',
            );
          },
          onNoThanks: () async {
            Navigator.pop(context, true);
            final notificationService = PushNotificationService.instance;
            await notificationService.saveNotificationPreference('never');
          },
        );
      },
    );

    // If the user dismissed the sheet (tap outside / swipe down) without
    // choosing any explicit action, apply the remind-later cooldown to avoid
    // showing it again immediately when they return to Home.
    if (!mounted) return;
    if (didTakeAction != true) {
      await PushNotificationService.instance.saveNotificationPreference(
        'remind_later',
      );
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      // Pass the active persona type so the avatar matches the currently
      // selected persona (player vs organiser) in multi-profile scenarios.
      final activeType = ref.read(activeProfileTypeProvider);
      final profile = await _authService.getUserProfile(
        personaType: activeType,
      );
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {}
  }

  /// Resolves display name from raw profile map with fallback chain:
  /// display_name → username → email prefix → 'User'
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

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = _activeTab;
    // Lazily load each tab the first time it is shown.
    switch (tab) {
      case FeedTab.forYou:
        // Already loaded in initState; re-load only if empty.
        final s = ref.read(feedNotifierProvider);
        if (s.posts.isEmpty && !s.isLoading) {
          ref.read(feedNotifierProvider.notifier).load();
        }
      case FeedTab.following:
        ref.read(followingFeedProvider.notifier).ensureLoaded();
      case FeedTab.nearby:
        ref.read(nearbyFeedProvider.notifier).ensureLoaded();
      case FeedTab.active:
        ref.read(activeFeedProvider.notifier).ensureLoaded();
      case FeedTab.news:
        ref.read(newsFeedProvider.notifier).ensureLoaded();
    }
  }

  void _onScroll(FeedTab tab, ScrollController sc) {
    if (!sc.hasClients) return;
    if (sc.position.extentAfter > 500) return;

    switch (tab) {
      case FeedTab.forYou:
        final s = ref.read(feedNotifierProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(feedNotifierProvider.notifier).loadMore();
        }
      case FeedTab.following:
        final s = ref.read(followingFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(followingFeedProvider.notifier).loadMore();
        }
      case FeedTab.nearby:
        final s = ref.read(nearbyFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(nearbyFeedProvider.notifier).loadMore();
        }
      case FeedTab.active:
        final s = ref.read(activeFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(activeFeedProvider.notifier).loadMore();
        }
      case FeedTab.news:
        final s = ref.read(newsFeedProvider);
        if (!s.isLoading && !s.isLoadingMore && s.hasMore) {
          ref.read(newsFeedProvider.notifier).loadMore();
        }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUserProfile();
    ref.invalidate(profileControllerProvider);
    switch (_activeTab) {
      case FeedTab.forYou:
        await ref.read(feedNotifierProvider.notifier).load();
      case FeedTab.following:
        await ref.read(followingFeedProvider.notifier).load();
      case FeedTab.nearby:
        await ref.read(nearbyFeedProvider.notifier).load();
      case FeedTab.active:
        await ref.read(activeFeedProvider.notifier).load();
      case FeedTab.news:
        await ref.read(newsFeedProvider.notifier).load();
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + 12;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: wordmark + location row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/dabbler_text_logo.svg',
                  width: 100,
                  height: 18,
                  colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
                ),
                const SizedBox(height: 4),
                // Location row — inline Consumer, tappable to open picker
                Consumer(
                  builder: (context, ref, _) {
                    final locAsync = ref.watch(activeLocationProvider);
                    final locState = locAsync.valueOrNull;
                    final locationName = locState is ActiveLocationReady
                        ? locState.location.area.name
                        : 'Set location';
                    return GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (_) => DraggableScrollableSheet(
                          initialChildSize: 0.85,
                          minChildSize: 0.5,
                          maxChildSize: 1.0,
                          expand: false,
                          builder: (ctx, sc) =>
                              HomeLocationPickerSheet(scrollController: sc),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.location_copy,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locationName,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Iconsax.arrow_down_1_copy,
                            size: 10,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Right: action buttons + avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search button
              GestureDetector(
                onTap: () => context.push(RoutePaths.socialSearch),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.search_normal_1_copy,
                    color: cs.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Notification button with badge
              GestureDetector(
                onTap: () => context.push(RoutePaths.notifications),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.notification_copy,
                        color: cs.primary,
                        size: 18,
                      ),
                    ),
                    const Positioned(
                      top: -2,
                      right: -2,
                      child: NotificationBadge(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Avatar
              GestureDetector(
                onTap: () => context.push(RoutePaths.profile),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
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
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final tab = _tabs[index];
              final isSelected = _tabController.index == index;

              return GestureDetector(
                onTap: () => _tabController.animateTo(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary
                        : cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tab.label,
                    style: textTheme.labelLarge?.copyWith(
                      color: isSelected ? cs.onPrimary : cs.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w700
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


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final forYouState = ref.watch(feedNotifierProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DynamicBackground(
            tabController: _tabController,
            scrollControllers: _scrollControllers,
          ),
          NestedScrollView(
            // Each tab has its own controller; NestedScrollView uses the header
            // region for the app-bar + tab bar.
            headerSliverBuilder: (_, innerBoxIsScrolled) => [
              if (!isWide) SliverToBoxAdapter(child: _buildHeader()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(tabBar: _buildTabBar(), cs: cs),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _ForYouTabBody(
                  state: forYouState,
                  scrollController: _scrollControllers[0],
                  onRefresh: _handleRefresh,
                  onRetry: () => ref.read(feedNotifierProvider.notifier).load(),
                  onClearBadge: () => ref
                      .read(feedNotifierProvider.notifier)
                      .clearNewPostsBadge(),
                ),
                _PostFeedTabBody(
                  state: ref.watch(followingFeedProvider),
                  scrollController: _scrollControllers[1],
                  onRefresh: _handleRefresh,
                  onRetry: () =>
                      ref.read(followingFeedProvider.notifier).load(),
                  emptyMessage: 'No posts from people you follow yet.',
                  emptyHint: 'Follow more people to see their posts here.',
                ),
                _NearbyFeedTabBody(
                  state: ref.watch(nearbyFeedProvider),
                  scrollController: _scrollControllers[2],
                  onRefresh: _handleRefresh,
                  onRetry: () => ref.read(nearbyFeedProvider.notifier).load(),
                ),
                _ActiveFeedTabBody(
                  state: ref.watch(activeFeedProvider),
                  scrollController: _scrollControllers[3],
                  onRefresh: _handleRefresh,
                  onRetry: () => ref.read(activeFeedProvider.notifier).load(),
                ),
                _PostFeedTabBody(
                  state: ref.watch(newsFeedProvider),
                  scrollController: _scrollControllers[4],
                  onRefresh: _handleRefresh,
                  onRetry: () => ref.read(newsFeedProvider.notifier).load(),
                  emptyMessage: 'No news right now.',
                  emptyHint:
                      'Check back later for updates from the Dabbler team.',
                ),
              ],
            ),
          ),
        ],
      ),
      // New-posts indicator floats over the For You tab.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      floatingActionButton: forYouState.hasNewPosts && _tabController.index == 0
          ? SafeArea(
              child: GestureDetector(
                onTap: () {
                  ref.read(feedNotifierProvider.notifier).clearNewPostsBadge();
                  _scrollControllers[0].animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                },
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(24),
                  color: cs.primary,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.arrow_up_1_copy,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'New posts',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
} // end _HomeScreenState

// ────────────────────────────────────────────────────────────────────────────
// SliverPersistentHeaderDelegate for the sticky TabBar
// ────────────────────────────────────────────────────────────────────────────
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
    final lavender = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.04),
      cs.surface,
    );
    return ColoredBox(
      color: Colors.transparent,
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
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.cs != cs || oldDelegate.tabBar != tabBar;
}

// ────────────────────────────────────────────────────────────────────────────
// For You tab — wraps existing FeedState (PostFeed + badge)
// ────────────────────────────────────────────────────────────────────────────
class _ForYouTabBody extends StatelessWidget {
  const _ForYouTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    required this.onClearBadge,
  });

  final FeedState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onClearBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (state.isLoading && state.posts.isEmpty) {
      return const _FeedSkeletonList();
    }

    if (state.error != null && state.posts.isEmpty) {
      return _ErrorView(message: 'Could not load feed', onRetry: onRetry);
    }

    if (state.posts.isEmpty) {
      return _EmptyView(
        iconAsset: 'assets/icons/document-text.svg',
        message: 'No posts yet',
        hint: 'Share moments, dabs, and kick-ins with your community.',
      );
    }

    final posts = state.posts;
    final itemCount = posts.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: itemCount,
        separatorBuilder: (_, index) {
          if (index < posts.length && _nativeSeparator(posts[index])) {
            return const SizedBox.shrink();
          }
          return Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          );
        },
        itemBuilder: (_, index) {
          if (index == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return resolvePostLayout(posts[index]);
        },
      ),
    );
  }

  static bool _nativeSeparator(dynamic post) => false;
}

// ────────────────────────────────────────────────────────────────────────────
// Generic post-list tab (Following / Nearby / News)
// ────────────────────────────────────────────────────────────────────────────
class _PostFeedTabBody extends StatelessWidget {
  const _PostFeedTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    required this.emptyMessage,
    required this.emptyHint,
  });

  final TabFeedState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final String emptyMessage;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (state.isLoading && state.posts.isEmpty) {
      return const _FeedSkeletonList();
    }

    if (state.error != null && state.posts.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    if (state.posts.isEmpty) {
      return _EmptyView(
        iconAsset: 'assets/icons/document-text.svg',
        message: emptyMessage,
        hint: emptyHint,
      );
    }

    final posts = state.posts;
    final itemCount = posts.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: itemCount,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
        itemBuilder: (_, index) {
          if (index == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return resolvePostLayout(posts[index]);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Active feed tab — event-type-routed cards
// ────────────────────────────────────────────────────────────────────────────
class _ActiveFeedTabBody extends StatelessWidget {
  const _ActiveFeedTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final ActiveFeedState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.events.isEmpty) {
      return const _FeedSkeletonList();
    }

    if (state.error != null && state.events.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    if (state.events.isEmpty) {
      return const _EmptyView(
        iconAsset: 'assets/icons/document-text.svg',
        message: 'Nothing active right now.',
        hint: 'Check back when games or events kick off near you.',
      );
    }

    final cs = Theme.of(context).colorScheme;
    final events = state.events;
    final itemCount = events.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: itemCount,
        separatorBuilder: (_, index) {
          if (index < events.length &&
              events[index].eventType == 'post_created') {
            return Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            );
          }
          return const SizedBox(height: 6);
        },
        itemBuilder: (_, index) {
          if (index == events.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ActiveEventCard(event: events[index]);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Nearby feed tab — original post cards with "Near you" chip
// ────────────────────────────────────────────────────────────────────────────
class _NearbyFeedTabBody extends StatelessWidget {
  const _NearbyFeedTabBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  final TabFeedState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (state.isLoading && state.posts.isEmpty) {
      return const _FeedSkeletonList();
    }

    if (state.error != null && state.posts.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    if (state.posts.isEmpty) {
      return const _EmptyView(
        iconAsset: 'assets/icons/document-text.svg',
        message: 'Nothing nearby yet.',
        hint: 'Check back when more activity pops up near you.',
      );
    }

    final posts = state.posts;
    final itemCount = posts.length + (state.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: itemCount,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
        itemBuilder: (_, index) {
          if (index == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return resolvePostLayout(posts[index], showNearbyChipInHeader: true);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared empty / error helpers
// ────────────────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.iconAsset,
    required this.message,
    required this.hint,
  });

  final String iconAsset;
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(cs.outline, BlendMode.srcIn),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.outline),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
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

// ────────────────────────────────────────────────────────────────────────────
// Skeleton loader — shown while the initial feed page is fetching
// ────────────────────────────────────────────────────────────────────────────

/// Single shimmer card that matches the approximate layout of a [FeedPostCard].
class _PostCardSkeleton extends StatelessWidget {
  const _PostCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ShimmerLoading(
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name + time
                Row(
                  children: [
                    const ShimmerLoading(width: 120, height: 13),
                    const Spacer(),
                    const ShimmerLoading(width: 48, height: 11),
                  ],
                ),
                const SizedBox(height: 10),
                // Body text lines
                const ShimmerLoading(height: 13),
                const SizedBox(height: 6),
                const ShimmerLoading(height: 13),
                const SizedBox(height: 6),
                const ShimmerLoading(width: 160, height: 13),
                const SizedBox(height: 14),
                // Action bar placeholder
                Row(
                  children: [
                    ShimmerLoading(
                      width: 52,
                      height: 22,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    const SizedBox(width: 16),
                    ShimmerLoading(
                      width: 52,
                      height: 22,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    const SizedBox(width: 16),
                    ShimmerLoading(
                      width: 52,
                      height: 22,
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a fixed list of [_PostCardSkeleton] items separated by dividers.
/// Used as the initial loading state for all feed tabs.
class _FeedSkeletonList extends StatelessWidget {
  const _FeedSkeletonList();

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
      itemBuilder: (_, __) => const _PostCardSkeleton(),
    );
  }
}
