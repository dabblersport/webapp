import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/themes/material3_extensions.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_screen.dart'
    show ExploreScreen;
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';
import 'package:dabbler/features/rewards/controllers/check_in_controller.dart';
import 'package:dabbler/features/rewards/presentation/widgets/early_bird_check_in_modal.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';

/// Main navigation screen with bottom nav bar
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool _hasShownModalThisSession = false;
  bool _checkInModalInFlight = false;

  DateTime? _lastBackPressAt;
  bool _exitDialogShowing = false;

  // Only swipeable screens (Home and Sports, excluding Create)
  final List<Widget> _swipeableScreens = [
    const HomeScreen(),
    const ExploreScreen(), // Sports screen
  ];

  @override
  void initState() {
    super.initState();

    if (FeatureFlags.enableRewards) {
      // Register lifecycle callback
      AppLifecycleManager().onResume(_onAppResume);

      // Check after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _checkAndShowModal();
        });
      });
    }
  }

  @override
  void dispose() {
    if (FeatureFlags.enableRewards) {
      AppLifecycleManager().offResume(_onAppResume);
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onAppResume() {
    _hasShownModalThisSession = false;
    _checkAndShowModal();
  }

  Future<void> _checkAndShowModal() async {
    if (!mounted || _hasShownModalThisSession || _checkInModalInFlight) return;

    _checkInModalInFlight = true;

    try {
      final controller = ref.read(checkInControllerProvider.notifier);
      final shouldShow = await controller.shouldShowCheckInModal();

      if (!mounted) return;
      if (_hasShownModalThisSession) return;

      debugPrint('MainNavigationScreen: shouldShow=$shouldShow');

      if (shouldShow && mounted) {
        _hasShownModalThisSession = true;

        // Avoid showing dialogs while this route is not current (e.g. during redirects).
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (!isCurrentRoute) {
          debugPrint('MainNavigationScreen: skip modal (route not current)');
          return;
        }

        final state = ref.read(checkInControllerProvider);
        final status = state.valueOrNull;

        debugPrint('MainNavigationScreen: status=$status');

        final currentDay = status?.totalDaysCompleted ?? 0;
        final streakCount = status?.streakCount ?? 0;
        final daysRemaining = status?.daysRemaining ?? 14;
        final isCompleted = status?.isCompleted ?? false;

        EarlyBirdCheckInModal.show(
          context,
          currentDay: currentDay,
          streakCount: streakCount,
          daysRemaining: daysRemaining,
          isCompleted: isCompleted,
          onCheckIn: () async {
            debugPrint('=== CHECK-IN BUTTON CLICKED ===');
            debugPrint('User initiated check-in from modal');

            final wasFirstToday = await controller.performCheckIn();

            debugPrint('MainNavigationScreen: wasFirstToday=$wasFirstToday');
            debugPrint('=== CHECK-IN COMPLETED ===');

            if (!mounted) return;

            // Always close the modal after check-in attempt
            Navigator.of(context, rootNavigator: true).pop();

            if (wasFirstToday) {
              final newStatus = ref.read(checkInControllerProvider).valueOrNull;
              final completedDays = newStatus?.totalDaysCompleted ?? 1;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    completedDays >= 14
                        ? '🎉 Congratulations! You earned the Early Bird badge!'
                        : '✅ Checked in! Day $completedDays of 14',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );

              if (completedDays >= 14) {
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted) {
                  final finalStatus = ref
                      .read(checkInControllerProvider)
                      .valueOrNull;
                  EarlyBirdCheckInModal.show(
                    context,
                    currentDay: 14,
                    streakCount: finalStatus?.streakCount ?? 14,
                    daysRemaining: 0,
                    isCompleted: true,
                    onCheckIn: () {},
                  );
                }
              }
            } else {
              // Already checked in today
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Already checked in today!'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        );
      }
    } catch (e, stack) {
      debugPrint('MainNavigationScreen check-in error: $e');
      debugPrint('Stack: $stack');
    } finally {
      _checkInModalInFlight = false;
    }
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      // Show create post modal (index 1 is Create button)
      _showCreatePostModal();
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    // Map nav index to page index: 0->0 (Home), 2->1 (Sports)
    int pageIndex;
    if (index == 0) {
      pageIndex = 0; // Home
    } else {
      pageIndex = 1; // Sports
    }

    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int pageIndex) {
    // Map page index back to nav index: 0->0 (Home), 1->2 (Sports)
    int navIndex;
    if (pageIndex == 0) {
      navIndex = 0; // Home
    } else {
      navIndex = 2; // Sports
    }
    setState(() {
      _currentIndex = navIndex;
    });
  }

  Future<void> _showCreatePostModal() async {
    final result = await context.push<bool>(RoutePaths.socialCreatePost);
    if (result == true && mounted) {
      // Realtime subscription will prepend the new post automatically.
      // Clear the badge so it doesn't flash unnecessarily for own posts.
      ref.read(feedNotifierProvider.notifier).clearNewPostsBadge();
    }
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _attemptExitApp() async {
    if (!_isAndroid || !mounted) return;
    if (_exitDialogShowing) return;

    _exitDialogShowing = true;

    try {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit app?'),
          content: const Text('Are you sure you want to exit Dabbler?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        ),
      );

      if (shouldExit == true && mounted) {
        await SystemNavigator.pop();
      }
    } finally {
      _exitDialogShowing = false;
    }
  }

  void _handleSystemBack() {
    // If we're not on Home, back should return to Home (not exit the app).
    if (_currentIndex != 0) {
      _onItemTapped(0);
      return;
    }

    // On Home, require double back then confirm exit (Android only).
    if (!_isAndroid || !mounted) return;

    final now = DateTime.now();
    final last = _lastBackPressAt;
    _lastBackPressAt = now;

    final pressedRecently =
        last != null && now.difference(last) < const Duration(seconds: 2);

    if (!pressedRecently) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }

    _attemptExitApp();
  }

  /// Get bottom nav color based on current screen
  Color _getBottomNavColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Map index to category colors
    switch (_currentIndex) {
      case 0: // Home - Main category
        return colorScheme.categoryMainContainer;
      case 2: // Sports - Sports category
        return colorScheme.categorySportsContainer;
      default: // Default to main
        return colorScheme.categoryMainContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure profile data is bootstrapped once per session so
    // profileType is available on first visit to Home
    final bootstrapCompleted = ref.watch(profileBootstrapCompletedProvider);
    final isProfileInitialized = ref.watch(initializeProfileDataProvider);

    isProfileInitialized.whenData((success) {
      if (success && !bootstrapCompleted) {
        ref.read(profileBootstrapCompletedProvider.notifier).state = true;
      }
    });

    final colorScheme = Theme.of(context).colorScheme;

    // Get target colors based on current screen
    Color targetPrimaryColor;
    if (_currentIndex == 0) {
      // Home screen - Main category
      targetPrimaryColor = colorScheme.categoryMain;
    } else if (_currentIndex == 2) {
      // Sports screen - Sports category
      targetPrimaryColor = colorScheme.categorySports;
    } else {
      // Default to main
      targetPrimaryColor = colorScheme.categoryMain;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen =
              constraints.maxWidth >= AdaptiveBreakpoints.compact;

          if (isWideScreen) {
            return _buildDesktopLayout(context, targetPrimaryColor);
          }
          return _buildMobileLayout(context, targetPrimaryColor);
        },
      ),
    );
  }

  // ── Desktop adaptive layout (side nav + centre content + right panel) ──
  Widget _buildDesktopLayout(BuildContext context, Color targetPrimaryColor) {
    final colorScheme = Theme.of(context).colorScheme;

    // Map _currentIndex (0=Home, 2=Sports) → sequential destination index.
    // Destinations: 0 Home, 1 Create, 2 Sports, 3 Search, 4 Notifications, 5 Profile
    int destIndex;
    switch (_currentIndex) {
      case 0:
        destIndex = 0;
        break;
      case 2:
        destIndex = 2;
        break;
      default:
        destIndex = 0;
    }

    return AdaptiveScaffold(
      currentIndex: destIndex,
      onDestinationSelected: _onDesktopDestinationSelected,
      destinations: const [
        AdaptiveDestination(
          icon: Iconsax.home_2_copy,
          selectedIcon: Iconsax.home_2,
          label: "What's New",
        ),
        AdaptiveDestination(
          icon: Iconsax.add_circle_copy,
          selectedIcon: Iconsax.add_circle,
          label: 'Create',
          isAction: true,
        ),
        AdaptiveDestination(
          icon: Iconsax.search_status_copy,
          selectedIcon: Iconsax.search_status,
          label: 'Sports',
        ),
        AdaptiveDestination(
          icon: Iconsax.search_normal_1_copy,
          selectedIcon: Iconsax.search_normal_1,
          label: 'Search',
        ),
        AdaptiveDestination(
          icon: Iconsax.notification_copy,
          selectedIcon: Iconsax.notification,
          label: 'Notifications',
        ),
        AdaptiveDestination(
          icon: Iconsax.profile_circle_copy,
          selectedIcon: Iconsax.profile_circle,
          label: 'Profile',
        ),
      ],
      headerWidget: SvgPicture.asset(
        'assets/images/dabbler_text_logo.svg',
        width: 100,
        height: 18,
        colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
      ),
      body: IndexedStack(
        index: _currentIndex == 0 ? 0 : 1,
        children: _swipeableScreens,
      ),
      rightPanel: const _DesktopRightPanel(),
    );
  }

  void _onDesktopDestinationSelected(int destIndex) {
    switch (destIndex) {
      case 0: // Home
        _onItemTapped(0);
        break;
      case 1: // Create
        _showCreatePostModal();
        break;
      case 2: // Sports
        _onItemTapped(2);
        break;
      case 3: // Search
        context.push(RoutePaths.socialSearch);
        break;
      case 4: // Notifications
        context.push(RoutePaths.notifications);
        break;
      case 5: // Profile
        context.push(RoutePaths.profile);
        break;
    }
  }

  // ── Mobile layout (existing bottom nav + PageView) ──
  Widget _buildMobileLayout(BuildContext context, Color targetPrimaryColor) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _swipeableScreens,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 300),
          tween: ColorTween(end: targetPrimaryColor),
          builder: (context, animatedColor, child) {
            final foregroundColor = animatedColor ?? targetPrimaryColor;
            final foregroundColorInactive = foregroundColor.withValues(
              alpha: 0.8,
            );
            final borderColor = foregroundColor;

            return LayoutBuilder(
              builder: (context, constraints) {
                final targetWidth = (constraints.maxWidth * 0.82)
                    .clamp(0.0, 300.0)
                    .toDouble();

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: targetWidth,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: _getBottomNavColor(context),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNavItem(
                                index: 0,
                                outlineIcon: Iconsax.home_2_copy,
                                bulkIcon: Iconsax.home_2,
                                label: "What's New",
                                foregroundColor: foregroundColor,
                                foregroundColorInactive:
                                    foregroundColorInactive,
                              ),
                              const SizedBox(width: 24),
                              GestureDetector(
                                onTap: () => _onItemTapped(1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Iconsax.add_circle_copy,
                                        color: foregroundColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Create',
                                        style: TextStyle(
                                          color: foregroundColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              _buildNavItem(
                                index: 2,
                                outlineIcon: Iconsax.search_status_copy,
                                bulkIcon: Iconsax.search_status,
                                label: 'Sports',
                                foregroundColor: foregroundColor,
                                foregroundColorInactive:
                                    foregroundColorInactive,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData outlineIcon,
    required IconData bulkIcon,
    required String label,
    required Color foregroundColor,
    required Color foregroundColorInactive,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? bulkIcon : outlineIcon,
              color: isSelected ? foregroundColor : foregroundColorInactive,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

/// Right-side panel shown on wide desktop screens (similar to Twitter's
/// "What's happening" / "Who to follow" sidebar).
class _DesktopRightPanel extends StatelessWidget {
  const _DesktopRightPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search Dabbler',
                prefixIcon: Icon(
                  Iconsax.search_normal_1_copy,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  context.push(RoutePaths.socialSearch);
                }
              },
            ),
            const SizedBox(height: 24),

            // Trending / What's happening card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "What's happening",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TrendingItem(
                    category: 'Sports',
                    title: 'New games near you',
                    subtitle: 'Check out the latest games in your area',
                  ),
                  const SizedBox(height: 12),
                  _TrendingItem(
                    category: 'Community',
                    title: 'Growing squads',
                    subtitle: 'Join a squad to play regularly',
                  ),
                  const SizedBox(height: 12),
                  _TrendingItem(
                    category: 'Dabbler',
                    title: 'Share your moments',
                    subtitle: 'Post updates and connect with players',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick actions card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick actions',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionTile(
                    icon: Iconsax.people_copy,
                    label: 'Find friends',
                    onTap: () => context.push(RoutePaths.socialFriends),
                  ),
                  _QuickActionTile(
                    icon: Iconsax.setting_2_copy,
                    label: 'Settings',
                    onTap: () => context.push(RoutePaths.profile),
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

class _TrendingItem extends StatelessWidget {
  const _TrendingItem({
    required this.category,
    required this.title,
    required this.subtitle,
  });

  final String category;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
      title: Text(label),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
