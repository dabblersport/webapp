import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/themes/material3_extensions.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
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
  const MainNavigationScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  bool _hasShownModalThisSession = false;
  bool _checkInModalInFlight = false;

  DateTime? _lastBackPressAt;
  bool _exitDialogShowing = false;
  bool _createMenuOpen = false;

  // Convenience getter — the shell tracks which branch is active.
  int get _currentIndex => widget.navigationShell.currentIndex;

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

  // Branches: 0=Home, 1=Community, 2=Venues, 3=Games
  bool get _isOnSportsPage => _currentIndex == 2 || _currentIndex == 3;

  void _onItemTapped(int index) {
    if (_isOnSportsPage) {
      // Sports-mode nav: [Home(0), Venues(1), Games(2), Create(3)]
      switch (index) {
        case 0: // Home icon → go back to feeds
          widget.navigationShell.goBranch(0);
          return;
        case 1: // Venues → branch 2
          widget.navigationShell.goBranch(2);
          return;
        case 2: // Games → branch 3
          widget.navigationShell.goBranch(3);
          return;
        case 3: // Create
          _showCreateMenu();
          return;
      }
    } else {
      // Home-mode nav: [Feeds(0), Community(1), Sports icon(2), Create(3)]
      switch (index) {
        case 0: // Feeds → branch 0
          widget.navigationShell.goBranch(0);
          return;
        case 1: // Community → branch 1
          widget.navigationShell.goBranch(1);
          return;
        case 2: // Sports icon → Venues by default (branch 2)
          widget.navigationShell.goBranch(2);
          return;
        case 3: // Create
          _showCreateMenu();
          return;
      }
    }
  }

  Future<void> _showCreateMenu() async {
    setState(() => _createMenuOpen = true);

    // Capture router BEFORE the modal opens to avoid stale context after
    // useRootNavigator:true dismisses the sheet on the root navigator.
    final router = GoRouter.of(context);
    final feedNotifier = ref.read(feedNotifierProvider.notifier);

    final action = await showModalBottomSheet<_CreateAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      useRootNavigator: true,
      builder: (ctx) => const _CreateActionSheet(),
    );

    if (!mounted) return;
    setState(() => _createMenuOpen = false);

    switch (action) {
      case _CreateAction.post:
        final result = await router.push<bool>(RoutePaths.socialCreatePost);
        if (result == true && mounted) {
          feedNotifier.clearNewPostsBadge();
        }
      case _CreateAction.game:
        router.push(RoutePaths.createGame);
      case _CreateAction.meetup:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meetups coming soon!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      case null:
        break;
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
    // Move side-effect out of build: use ref.listen to bootstrap profile data
    ref.listen(initializeProfileDataProvider, (previous, next) {
      next.whenData((success) {
        if (success && !ref.read(profileBootstrapCompletedProvider)) {
          ref.read(profileBootstrapCompletedProvider.notifier).state = true;
        }
      });
    });

    final bootstrapCompleted = ref.watch(profileBootstrapCompletedProvider);
    final isProfileInitialized = ref.watch(initializeProfileDataProvider);

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

    // Map branch index (0=Home,1=Community,2=Venues,3=Games) → side-nav destination index.
    int destIndex;
    switch (_currentIndex) {
      case 0:
        destIndex = 0; // Home
        break;
      case 1:
        destIndex = 4; // Community
        break;
      case 2:
      case 3:
        destIndex = 2; // Sports (Venues or Games)
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
      body: widget.navigationShell,
      rightPanel: const _DesktopRightPanel(),
    );
  }

  void _onDesktopDestinationSelected(int destIndex) {
    switch (destIndex) {
      case 0: // Home
        _onItemTapped(0);
        break;
      case 1: // Create
        _showCreateMenu();
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

  // ── Mobile layout (bottom nav + shell body) ──
  Widget _buildMobileLayout(BuildContext context, Color targetPrimaryColor) {
    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactNav = constraints.maxWidth < 390;
            final targetWidth =
                (constraints.maxWidth * (isCompactNav ? 0.97 : 0.92))
                    .clamp(0.0, 420.0)
                    .toDouble();
            final cs = Theme.of(context).colorScheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final foregroundColor = cs.onPrimaryContainer;
            final foregroundColorInactive = foregroundColor.withValues(alpha: 0.65);

            // Primary-tinted liquid glass colors
            final glassColor = isDark
                ? cs.primary.withValues(alpha: 0.18)
                : cs.primaryContainer.withValues(alpha: 0.55);
            final glassBorderColor = isDark
                ? cs.primary.withValues(alpha: 0.32)
                : cs.primary.withValues(alpha: 0.22);
            final glowColor = isDark
                ? cs.primary.withValues(alpha: 0.22)
                : cs.primary.withValues(alpha: 0.14);

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: targetWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: kIsWeb
                        ? ImageFilter.blur(sigmaX: 0, sigmaY: 0) // No-op on web to be safe
                        : ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactNav ? 8 : 10,
                        vertical: isCompactNav ? 7 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: glassColor,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: glassBorderColor, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 28,
                            spreadRadius: -2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
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
              ),
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
        isMenuOpen: _createMenuOpen,
      ),
    ];
  }

  /// Sports-mode nav items: [🏠 icon] [Venues (pill)]  ...  [Games (text)] [⊕ icon]
  List<Widget> _buildSportsNavItems(
    Color foregroundColor,
    Color foregroundColorInactive,
  ) {
    final isGamesSelected = _currentIndex == 3;
    final isVenuesSelected = _currentIndex == 2;

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
            isSelected: isVenuesSelected,
            foregroundColor: foregroundColor,
            foregroundColorInactive: foregroundColorInactive,
            inSegmentedGroup: true,
          ),
          _buildSportsTextNavItem(
            index: 2,
            label: 'Games',
            isSelected: isGamesSelected,
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
        isMenuOpen: _createMenuOpen,
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: _navLabelHorizontalPadding(context),
          vertical: _navLabelVerticalPadding(context),
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(inSegmentedGroup ? 22 : 28),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : foregroundColorInactive,
            fontSize: _navLabelFontSize(context),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: isSelected ? -0.2 : 0,
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: _navLabelHorizontalPadding(context),
          vertical: _navLabelVerticalPadding(context),
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(inSegmentedGroup ? 22 : 28),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : foregroundColorInactive,
            fontSize: _navLabelFontSize(context),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: isSelected ? -0.2 : 0,
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
    bool isMenuOpen = false,
  }) {
    final isSelected = forceUnselected ? false : _currentIndex == index;
    final buttonSize = _isCompactNavWidth(context) ? 44.0 : 48.0;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleBg = isDark
        ? cs.primary.withValues(alpha: 0.22)
        : cs.primaryContainer.withValues(alpha: 0.50);
    final circleBorder = isDark
        ? cs.primary.withValues(alpha: 0.40)
        : cs.primary.withValues(alpha: 0.28);

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: circleBg,
          shape: BoxShape.circle,
          border: Border.all(color: circleBorder, width: 0.9),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 14,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: isMenuOpen ? 0.125 : 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Icon(
            isSelected ? bulkIcon : outlineIcon,
            color: isSelected ? foregroundColor : foregroundColorInactive,
            size: _navIconSize(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedNavGroup({
    required Color foregroundColor,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark
        ? cs.primary.withValues(alpha: 0.16)
        : cs.primaryContainer.withValues(alpha: 0.38);
    final pillBorder = isDark
        ? cs.primary.withValues(alpha: 0.28)
        : cs.primary.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: pillBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: isDark ? 0.20 : 0.10),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
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

enum _CreateAction { post, game, meetup }

class _CreateActionSheet extends StatefulWidget {
  const _CreateActionSheet();

  @override
  State<_CreateActionSheet> createState() => _CreateActionSheetState();
}

class _CreateActionSheetState extends State<_CreateActionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;

  static const _actions = [
    (
      icon: Iconsax.edit_2_copy,
      label: 'Create Post',
      action: _CreateAction.post,
    ),
    (icon: Iconsax.game_copy, label: 'Create Game', action: _CreateAction.game),
    (
      icon: Iconsax.people_copy,
      label: 'Create Meetup',
      action: _CreateAction.meetup,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(_CreateAction action) {
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBase = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.72);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.80);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).padding.bottom + 100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: kIsWeb
                ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                : ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: glassBase,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: glassBorder, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 32,
                    spreadRadius: -4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_actions.length, (i) {
                  final item = _actions[i];
                  final delay = i * 0.12;
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _controller,
                            curve: Interval(
                              delay,
                              1.0,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        ),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: Interval(delay, 1.0, curve: Curves.easeOut),
                      ),
                      child: _ActionTile(
                        icon: item.icon,
                        label: item.label,
                        onTap: () => _select(item.action),
                        showDivider: i < _actions.length - 1,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.showDivider,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.20)
                        : colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}
