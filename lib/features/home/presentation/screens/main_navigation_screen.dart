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
import 'package:dabbler/features/social/presentation/screens/real_friends_screen.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';
import 'package:dabbler/features/rewards/controllers/check_in_controller.dart';
import 'package:dabbler/features/rewards/presentation/widgets/early_bird_check_in_modal.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/core/constants/adaptive_destinations.dart';

/// Tracks the active sub-tab inside ExploreScreen (0=Games, 1=Venues).
/// Shared between MainNavigationScreen (nav bar) and ExploreScreen (tab controller).
final sportsSubTabProvider = StateProvider<int>((ref) => 1); // default Venues

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

  bool _isCompactNavWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 390;

  double _navLabelHorizontalPadding(BuildContext context) =>
      _isCompactNavWidth(context) ? 12 : 16;

  double _navLabelVerticalPadding(BuildContext context) =>
      _isCompactNavWidth(context) ? 8 : 9;

  double _navLabelFontSize(BuildContext context) =>
      _isCompactNavWidth(context) ? 14 : 16;

  double _navIconSize(BuildContext context) =>
      _isCompactNavWidth(context) ? 24 : 26;

  double _navItemGap(BuildContext context) =>
      _isCompactNavWidth(context) ? 2 : 4;

  // Screens matching PageView pages: 0=Home, 1=Community, 2=Sports
  // Nav indices: 0=Feeds, 1=Community, 2=Sports, 3=Create(action)
  final List<Widget> _swipeableScreens = [
    const HomeScreen(),
    const RealFriendsScreen(), // Community
    const ExploreScreen(), // Sports/Venues screen
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

  /// Whether the Sports/Explore page is currently visible.
  bool get _isOnSportsPage => _currentIndex == 2;

  void _onItemTapped(int index) {
    if (_isOnSportsPage) {
      // Sports-mode nav: [Home(0), Venues(1), Games(2), Create(3)]
      switch (index) {
        case 0: // Home icon → go back to feeds
          setState(() => _currentIndex = 0);
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        case 1: // Venues text → switch ExploreScreen to Venues tab
          ref.read(sportsSubTabProvider.notifier).state = 1;
          return;
        case 2: // Games text → switch ExploreScreen to Games tab
          ref.read(sportsSubTabProvider.notifier).state = 0;
          return;
        case 3: // Create
          _showCreatePostModal();
          return;
      }
    } else {
      // Home-mode nav: [Feeds(0), Community(1), Games icon(2), Create(3)]
      switch (index) {
        case 0: // Feeds → go to home page
          setState(() => _currentIndex = 0);
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        case 1: // Community → go to community page
          setState(() => _currentIndex = 1);
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        case 2: // Games icon → switch to Sports page (Venues by default)
          ref.read(sportsSubTabProvider.notifier).state = 1;
          setState(() => _currentIndex = 2);
          _pageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        case 3: // Create
          _showCreatePostModal();
          return;
      }
    }
  }

  void _onPageChanged(int pageIndex) {
    // Map page index to nav state: page 0→Home(0), page 1→Community(1), page 2→Sports(2)
    setState(() {
      _currentIndex = pageIndex;
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
      targetPrimaryColor = colorScheme.categoryMain;
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

    // Map _currentIndex (0=Home, 1=Community, 2=Sports) → sequential destination index.
    // Destinations: 0 Home, 1 Create, 2 Sports, 3 Search, 4 Notifications, 5 Profile
    int destIndex;
    switch (_currentIndex) {
      case 0:
        destIndex = 0;
        break;
      case 1:
        destIndex = 4; // Community maps to Community destination
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
      destinations: kAdaptiveDestinations,
      headerWidget: SvgPicture.asset(
        'assets/images/dabbler_text_logo.svg',
        width: 100,
        height: 18,
        colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
      ),
      body: IndexedStack(
        index: _currentIndex < _swipeableScreens.length ? _currentIndex : 0,
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
      case 4: // Community
        _onItemTapped(1); // navigate to community page
        break;
      case 5: // Notifications
        context.push(RoutePaths.notifications);
        break;
      case 6: // Profile
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
            final foregroundColor = Theme.of(
              context,
            ).colorScheme.onPrimaryContainer;
            final foregroundColorInactive = foregroundColor.withValues(
              alpha: 0.8,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final isCompactNav = constraints.maxWidth < 390;
                final targetWidth =
                    (constraints.maxWidth * (isCompactNav ? 0.97 : 0.92))
                        .clamp(0.0, 420.0)
                        .toDouble();

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: targetWidth),
                    child: Material(
                      color: Colors.transparent,
                      elevation: 0,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _isOnSportsPage
                                ? _buildSportsNavItems(
                                    foregroundColor,
                                    foregroundColorInactive,
                                  )
                                : _buildHomeNavItems(
                                    foregroundColor,
                                    foregroundColorInactive,
                                  ),
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

  /// Home-mode nav items: [Feeds (pill)] [Community (text)]  ...  [🎮 icon] [⊕ icon]
  List<Widget> _buildHomeNavItems(
    Color foregroundColor,
    Color foregroundColorInactive,
  ) {
    return [
      _buildSegmentedNavGroup(
        foregroundColor: foregroundColor,
        children: [
          _buildTextNavItem(
            index: 0,
            label: 'Feeds',
            foregroundColor: foregroundColor,
            foregroundColorInactive: foregroundColorInactive,
            inSegmentedGroup: true,
          ),
          _buildTextNavItem(
            index: 1,
            label: 'Community',
            foregroundColor: foregroundColor,
            foregroundColorInactive: foregroundColorInactive,
            inSegmentedGroup: true,
          ),
        ],
      ),
      SizedBox(width: _navItemGap(context) * 2),
      _buildIconNavItem(
        index: 2,
        outlineIcon: Iconsax.game_copy,
        bulkIcon: Iconsax.game,
        foregroundColor: foregroundColor,
        foregroundColorInactive: foregroundColorInactive,
      ),
      SizedBox(width: _navItemGap(context) * 2),
      _buildIconNavItem(
        index: 3,
        outlineIcon: Iconsax.add_circle_copy,
        bulkIcon: Iconsax.add_circle,
        foregroundColor: foregroundColor,
        foregroundColorInactive: foregroundColorInactive,
      ),
    ];
  }

  /// Sports-mode nav items: [🏠 icon] [Venues (pill)]  ...  [Games (text)] [⊕ icon]
  List<Widget> _buildSportsNavItems(
    Color foregroundColor,
    Color foregroundColorInactive,
  ) {
    final sportsSubTab = ref.watch(sportsSubTabProvider);

    return [
      _buildIconNavItem(
        index: 0,
        outlineIcon: Iconsax.home_2_copy,
        bulkIcon: Iconsax.home_2,
        foregroundColor: foregroundColor,
        foregroundColorInactive: foregroundColorInactive,
        forceUnselected: true,
      ),
      SizedBox(width: _navItemGap(context) * 2),
      _buildSegmentedNavGroup(
        foregroundColor: foregroundColor,
        children: [
          _buildSportsTextNavItem(
            index: 1,
            label: 'Venues',
            isSelected: sportsSubTab == 1,
            foregroundColor: foregroundColor,
            foregroundColorInactive: foregroundColorInactive,
            inSegmentedGroup: true,
          ),
          _buildSportsTextNavItem(
            index: 2,
            label: 'Games',
            isSelected: sportsSubTab == 0,
            foregroundColor: foregroundColor,
            foregroundColorInactive: foregroundColorInactive,
            inSegmentedGroup: true,
          ),
        ],
      ),

      SizedBox(width: _navItemGap(context) * 2),
      _buildIconNavItem(
        index: 3,
        outlineIcon: Iconsax.add_circle_copy,
        bulkIcon: Iconsax.add_circle,
        foregroundColor: foregroundColor,
        foregroundColorInactive: foregroundColorInactive,
      ),
    ];
  }

  /// Text nav item for sports mode — uses explicit [isSelected] instead of _currentIndex.
  Widget _buildSportsTextNavItem({
    required int index,
    required String label,
    required bool isSelected,
    required Color foregroundColor,
    required Color foregroundColorInactive,
    bool inSegmentedGroup = false,
  }) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: _navLabelHorizontalPadding(context),
          vertical: _navLabelVerticalPadding(context),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(inSegmentedGroup ? 22 : 28),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : foregroundColor,
            fontSize: _navLabelFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Text-based nav item with pill background when selected (Feeds, Community)
  Widget _buildTextNavItem({
    required int index,
    required String label,
    required Color foregroundColor,
    required Color foregroundColorInactive,
    bool inSegmentedGroup = false,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: _navLabelHorizontalPadding(context),
          vertical: _navLabelVerticalPadding(context),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(inSegmentedGroup ? 22 : 28),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : foregroundColor,
            fontSize: _navLabelFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Icon-only nav item (Games, Create, Home)
  Widget _buildIconNavItem({
    required int index,
    required IconData outlineIcon,
    required IconData bulkIcon,
    required Color foregroundColor,
    required Color foregroundColorInactive,
    bool forceUnselected = false,
  }) {
    final isSelected = forceUnselected ? false : _currentIndex == index;
    final buttonSize = _isCompactNavWidth(context) ? 48.0 : 52.0;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.10),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          isSelected ? bulkIcon : outlineIcon,
          color: foregroundColor,
          size: _navIconSize(context),
        ),
      ),
    );
  }

  Widget _buildSegmentedNavGroup({
    required Color foregroundColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
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
