import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';

import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';

import 'package:dabbler/services/notifications/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dabbler/features/home/presentation/widgets/notification_permission_drawer.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';

/// Modern home screen for Dabbler
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  final AuthService _authService = AuthService();
  final ScrollController _feedScrollController = ScrollController();
  Map<String, dynamic>? _userProfile;
  String _selectedFilter = 'Most Recent';
  static const List<String> _filterLabels = [
    'Most Recent',
    'Feed',
    'News',
    'Making Waves',
  ];

  @override
  void initState() {
    super.initState();
    _feedScrollController.addListener(_onFeedScroll);
    _loadUserProfile();
    _checkNotificationPermission();
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
    _feedScrollController
      ..removeListener(_onFeedScroll)
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
    final didTakeAction = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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

  Future<void> _handleRefresh() async {
    await _loadUserProfile();
    ref.invalidate(profileControllerProvider);
    await ref.read(feedNotifierProvider.notifier).load();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _onFeedScroll() {
    if (!_feedScrollController.hasClients) return;
    final feedState = ref.read(feedNotifierProvider);
    if (feedState.isLoading || feedState.isLoadingMore || !feedState.hasMore) {
      return;
    }
    final position = _feedScrollController.position;
    if (position.extentAfter <= 500) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Public Feed',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () => context.push(RoutePaths.socialSearch),
            icon: const Icon(Icons.search_rounded),
            style: IconButton.styleFrom(foregroundColor: colorScheme.onSurface),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => context.push(RoutePaths.notifications),
                icon: const Icon(Iconsax.notification_copy),
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                ),
              ),
              const Positioned(top: 4, right: 4, child: NotificationBadge()),
            ],
          ),

          IconButton(
            onPressed: () => context.push(RoutePaths.socialFriends),
            icon: const Icon(Iconsax.people_copy),
            style: IconButton.styleFrom(foregroundColor: colorScheme.onSurface),
          ),
          const SizedBox(width: AppSpacing.xl),
          GestureDetector(
            onTap: () => context.push(RoutePaths.profile),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              padding: const EdgeInsets.all(2),
              child: DSAvatar.small(
                imageUrl: resolveAvatarUrl(
                  _userProfile?['avatar_url'] as String?,
                ),
                displayName: _resolveDisplayName(_userProfile),
                context: AvatarContext.main,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _filterLabels[index];
          final isSelected = label == _selectedFilter;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = label);
              // TODO: wire filter to feed query
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final feedState = ref.watch(feedNotifierProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              controller: _feedScrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Safe-area top spacing
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.top + 8,
                  ),
                ),

                // ── Header: "Public Feed" + icons + avatar ──
                SliverToBoxAdapter(child: _buildHeader()),

                // ── Filter chips ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 12),
                    child: _buildFilterChips(),
                  ),
                ),

                // ── Feed content ──
                _buildFeedSliver(feedState),
              ],
            ),
          ),

          // ── New-posts indicator ──────────────────────────────────────────
          if (feedState.hasNewPosts)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(feedNotifierProvider.notifier)
                        .clearNewPostsBadge();
                    _feedScrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  },
                  child: AnimatedOpacity(
                    opacity: feedState.hasNewPosts ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(24),
                      color: colorScheme.primary,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'New posts',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the feed as a sliver for seamless scroll integration.
  Widget _buildFeedSliver(FeedState feedState) {
    final colorScheme = Theme.of(context).colorScheme;

    if (feedState.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (feedState.error != null && feedState.posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load feed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(feedNotifierProvider.notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (feedState.posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/document-text.svg',
                width: 48,
                height: 48,
                colorFilter: ColorFilter.mode(
                  colorScheme.outline,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share moments, dabs, and kick-ins with your community.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    // Posts + optional loading indicator at the bottom.
    final posts = feedState.posts;
    final itemCount = posts.length + (feedState.isLoadingMore ? 1 : 0);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      sliver: SliverList.separated(
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return FeedPostCard(post: posts[index]);
        },
      ),
    );
  }
}
