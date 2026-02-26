import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      child: Scaffold(
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
                                // What's New (Home)
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

                                // Create Post (Small CTA Button)
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

                                // Sports
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
