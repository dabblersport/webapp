import 'package:dabbler/core/constants/timing/play_timing.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';
import 'package:dabbler/features/rewards/controllers/check_in_controller.dart';
import 'package:dabbler/features/rewards/presentation/widgets/early_bird_check_in_modal.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Tracks the active sub-tab inside ExploreScreen (0=Games, 1=Venues).
/// Shared between MainNavigationScreen (nav bar) and ExploreScreen (tab controller).
final sportsSubTabProvider = StateProvider<int>((ref) => 1); // default Venues

/// The four GoRouter shell branches, in declaration order. [shellIndex] is the
/// index passed to `StatefulNavigationShell.goBranch` — named here so branch
/// numbers aren't scattered as magic integers across the nav logic.
enum NavigationBranch {
  home,
  community,
  venues,
  games,
  meetups;

  int get shellIndex => index;
}

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

  @override
  void initState() {
    super.initState();

    if (FeatureFlags.enableEarlyBirdCheckIn) {
      // Register lifecycle callback
      AppLifecycleManager().onResume(_onAppResume);

      // Check after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(DabblerMotion.delayRetry, () {
          if (mounted) _checkAndShowModal();
        });
      });
    }
  }

  @override
  void dispose() {
    if (FeatureFlags.enableEarlyBirdCheckIn) {
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

              DabblerToastProvider.of(context).show(
                DabblerToastSpec(
                  message: completedDays >= 14
                      ? 'Congratulations! You earned the Early Bird badge!'
                      : 'Checked in! Day $completedDays of 14',
                  tone: DabblerToastTone.success,
                  duration: DabblerMotion.toastLong,
                ),
              );

              if (completedDays >= 14) {
                await Future.delayed(DabblerMotion.delayRetry);
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
              DabblerToastProvider.of(context).show(
                const DabblerToastSpec(
                  message: 'Already checked in today!',
                  duration: DabblerMotion.toastShort,
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

  void _goBranch(NavigationBranch branch) =>
      widget.navigationShell.goBranch(branch.shellIndex);

  /// The bar's item ids, one per shell branch it exposes. Community
  /// (`NavigationBranch.community`) stays out of the bar while
  /// [FeatureFlags.enableCommunityMobileNav] is off.
  static const String _idHome = 'home';
  static const String _idCommunity = 'community';
  static const String _idVenues = 'venues';
  static const String _idGames = 'games';
  static const String _idMeetups = 'meetups';

  static const String _createPost = 'post';
  static const String _createGame = 'game';
  static const String _createMeetup = 'meetup';

  String get _activeId {
    switch (NavigationBranch.values[_currentIndex]) {
      case NavigationBranch.home:
        return _idHome;
      case NavigationBranch.community:
        return FeatureFlags.enableCommunityMobileNav ? _idCommunity : _idHome;
      case NavigationBranch.venues:
        return _idVenues;
      case NavigationBranch.games:
        return _idGames;
      case NavigationBranch.meetups:
        return _idMeetups;
    }
  }

  void _onSelect(String id) {
    switch (id) {
      case _idHome:
        _goBranch(NavigationBranch.home);
      case _idCommunity:
        _goBranch(NavigationBranch.community);
      case _idVenues:
        _goBranch(NavigationBranch.venues);
      case _idGames:
        _goBranch(NavigationBranch.games);
      case _idMeetups:
        _goBranch(NavigationBranch.meetups);
    }
  }

  Future<void> _onCreate(String id) async {
    setState(() => _createMenuOpen = false);

    // Capture the router and notifier before navigating away.
    final router = GoRouter.of(context);
    final feedNotifier = ref.read(feedNotifierProvider.notifier);

    switch (id) {
      case _createPost:
        final result = await router.push<bool>(RoutePaths.socialCreatePost);
        if (result == true && mounted) {
          feedNotifier.clearNewPostsBadge();
        }
      case _createGame:
        router.push(RoutePaths.createGame);
      case _createMeetup:
        router.push(RoutePaths.createMeetup);
    }
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _attemptExitApp() async {
    if (!_isAndroid || !mounted) return;
    if (_exitDialogShowing) return;

    _exitDialogShowing = true;

    try {
      final l = AppLocalizations.of(context);
      final shouldExit = await showDabblerDialog<bool>(
        context: context,
        builder: (ctx) => DabblerDialog(
          title: l.nav_exit_app_title,
          description: l.nav_exit_app_body,
          onClose: () => Navigator.of(ctx).pop(false),
          secondaryAction: DabblerDialogAction(
            label: l.nav_exit_app_cancel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          primaryAction: DabblerDialogAction(
            label: l.nav_exit_app_confirm,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
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
    if (_currentIndex != NavigationBranch.home.shellIndex) {
      _goBranch(NavigationBranch.home);
      return;
    }

    // On Home, require double back then confirm exit (Android only).
    if (!_isAndroid || !mounted) return;

    final now = DateTime.now();
    final last = _lastBackPressAt;
    _lastBackPressAt = now;

    final pressedRecently =
        last != null && now.difference(last) < PlayTiming.backExitWindow;

    if (!pressedRecently) {
      DabblerToastProvider.of(context).show(
        DabblerToastSpec(
          message: AppLocalizations.of(context).nav_press_back_to_exit,
          duration: DabblerMotion.toastShort,
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

    // Watched only to trigger a rebuild when these providers change.
    ref.watch(profileBootstrapCompletedProvider);
    ref.watch(initializeProfileDataProvider);

    final l = AppLocalizations.of(context);
    final canCreateMeetup = ref.watch(canOfferCreateMeetupProvider);

    // One layout at every width: the design has no desktop shell. The page
    // holds the active branch and the bottom bar.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: DabblerPage(
        // The page raises the body's bottom padding by the floating bar's
        // height, so branch pages scroll their last item clear of it. The
        // fade behind the bar washes the content out to the page colour.
        body: widget.navigationShell,
        bottomOverlay: DabblerNavigationBottomBar(
          items: <DabblerNavigationItem>[
            DabblerNavigationItem(
              id: _idHome,
              icon: 'home-2',
              label: l.nav_feeds,
            ),
            if (FeatureFlags.enableCommunityMobileNav)
              DabblerNavigationItem(
                id: _idCommunity,
                icon: 'people',
                label: l.nav_community,
              ),
            DabblerNavigationItem(
              id: _idVenues,
              icon: 'location',
              label: l.nav_venues,
            ),
            DabblerNavigationItem(
              id: _idGames,
              icon: 'game',
              label: l.nav_games,
            ),
            if (FeatureFlags.enableMeetups)
              DabblerNavigationItem(
                id: _idMeetups,
                icon: 'calendar',
                label: l.nav_meetups,
              ),
          ],
          active: _activeId,
          onSelect: _onSelect,
          menuOpen: _createMenuOpen,
          actionIcon: _createMenuOpen ? 'close-circle' : 'add',
          onAction: (open) => setState(() => _createMenuOpen = open),
          createItems: <DabblerNavigationCreateItem>[
            DabblerNavigationCreateItem(
              id: _createPost,
              icon: 'edit',
              label: l.nav_create_post,
            ),
            DabblerNavigationCreateItem(
              id: _createGame,
              icon: 'game',
              label: l.nav_create_game,
            ),
            if (canCreateMeetup)
              DabblerNavigationCreateItem(
                id: _createMeetup,
                icon: 'calendar',
                label: l.nav_create_meetup,
              ),
          ],
          onCreate: _onCreate,
        ),
      ),
    );
  }
}
