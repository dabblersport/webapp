import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/themes/material3_extensions.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/home/presentation/widgets/inline_post_composer.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_screen.dart'
    show ExploreScreen;
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
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
    if (!mounted || _hasShownModalThisSession) return;

    try {
      final controller = ref.read(checkInControllerProvider.notifier);
      final shouldShow = await controller.shouldShowCheckInModal();

      debugPrint('MainNavigationScreen: shouldShow=$shouldShow');

      if (shouldShow && mounted) {
        _hasShownModalThisSession = true;

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
            Navigator.of(context).pop();

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
    }
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      // Show create post modal
      _showCreatePostModal();
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    // Map nav index to page index (skip middle create button)
    final pageIndex = index == 0 ? 0 : 1;
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int pageIndex) {
    // Map page index back to nav index (0 -> 0, 1 -> 2)
    final navIndex = pageIndex == 0 ? 0 : 2;
    setState(() {
      _currentIndex = navIndex;
    });
  }

  void _showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const InlinePostComposer(),
      ),
    );
  }

  /// Get bottom nav color based on current screen
  Color _getBottomNavColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Map index to category colors
    switch (_currentIndex) {
      case 0: // Home - Main category
        return isDark
            ? const Color(0xFF4A148C).withOpacity(0.50)
            : const Color(0xFFE0C7FF).withOpacity(0.50);
      case 2: // Sports - Sports category
        final colorScheme = Theme.of(context).colorScheme;
        return isDark
            ? colorScheme.categorySports.withOpacity(0.50)
            : colorScheme.categorySports.withOpacity(0.50);
      default: // Default to main
        return isDark
            ? const Color(0xFF4A148C).withOpacity(0.50)
            : const Color(0xFFE0C7FF).withOpacity(0.50);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : Colors.black87;
    final foregroundColorInactive = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.3)
        : Colors.black.withOpacity(0.2);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _swipeableScreens,
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(color: _getBottomNavColor(context)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // What's New (Home)
                _buildNavItem(
                  index: 0,
                  outlineIcon: Iconsax.home_2_copy,
                  bulkIcon: Iconsax.home_2,
                  label: "What's New",
                  foregroundColor: foregroundColor,
                  foregroundColorInactive: foregroundColorInactive,
                ),

                // Create Post (Small CTA Button)
                GestureDetector(
                  onTap: () => _onItemTapped(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 1.5),
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

                // Sports
                _buildNavItem(
                  index: 2,
                  outlineIcon: Iconsax.search_status_copy,
                  bulkIcon: Iconsax.search_status,
                  label: 'Sports',
                  foregroundColor: foregroundColor,
                  foregroundColorInactive: foregroundColorInactive,
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
