import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';

import 'package:dabbler/features/error/presentation/pages/error_page.dart';
import 'package:dabbler/features/auth_onboarding/presentation/controllers/onboarding_controller.dart'
    as db_onboarding;
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_state.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';

import 'package:dabbler/utils/constants/route_constants.dart';

import 'routes/home_shell_route.dart';
import 'routes/identity_routes.dart';
import 'routes/notification_routes.dart';
import 'routes/platform_routes.dart';
import 'routes/play_places_routes.dart';
import 'routes/profile_social_routes.dart';

/// The root navigator key. Public because the route modules under `routes/`
/// pass it as `parentNavigatorKey`; it was `AppRouter._rootNavigatorKey` before
/// KAN-124 split those routes out.
final rootNavigatorKey = GlobalKey<NavigatorState>();

// Export GoRouter instance for use in main.dart
final appRouter = AppRouter.router;

class AppRouter {

  // Analytics Observer
  static final _routeObserver = RouteObserver<ModalRoute<void>>();
  static RouteObserver<ModalRoute<void>> get routeObserver => _routeObserver;

  // Router Instance
  // Toggle for verbose route logging (only active in debug mode)
  static const bool _routeLogging =
      true; // set false to silence even debug prints

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    // Show landing immediately after the native splash.
    initialLocation: RoutePaths.landing,
    debugLogDiagnostics: kDebugMode, // Only log navigation diagnostics in debug builds
    observers: [_routeObserver],
    errorBuilder: (context, state) => ErrorPage(message: state.error?.message),
    // Restore redirects for proper navigation flow
    redirect: _handleRedirect,
    // Refresh router when auth state changes
    refreshListenable: routerRefreshNotifier,
    routes: _routes,
  );

  // Auth Redirect Logic
  static FutureOr<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    void logRoute(String message) {
      if (kDebugMode && _routeLogging) {
        debugPrint('[Router] $message');
      }
    }

    try {
      // ─── UNREGISTERED ROUTE GUARD (KAN-110) ───
      // A cold load / direct URL entry / page refresh on a path that
      // matches no route (mistyped, stale, or a bookmarked dead link) must
      // redirect immediately, independent of auth-loading state. Without
      // this, an unmatched cold-load location falls through to the
      // "don't redirect while auth is loading" branch below and sits with
      // no matched route to render and nothing forcing a redirect — a
      // permanent blank screen. In-app navigation to an unknown route
      // doesn't hit this because auth state has already resolved by then,
      // so the unauthenticated/authenticated branches further down redirect
      // it correctly on their own.
      final requestedLocation = state.matchedLocation;
      final hasMatchingRoute =
          router.configuration.findMatch(requestedLocation).matches.isNotEmpty;
      if (!hasMatchingRoute) {
        logRoute('redirect (no matching route for $requestedLocation) -> ${RoutePaths.landing}');
        return RoutePaths.landing;
      }

      // Access Riverpod container to read auth/guest state
      final container = ProviderScope.containerOf(context, listen: false);
      final isAuthenticated = container.read(isAuthenticatedProvider);
      container.read(isGuestProvider);

      // Also read the full auth state for debugging
      final authState = container.read(simpleAuthProvider);

      // Auth paths: Routes that unauthenticated users can access
      // Includes onboarding screens because email users are unauthenticated during onboarding
      // Phone users become authenticated before onboarding, so we handle them separately
      const authPaths = <String>{
        RoutePaths.landing, // Landing page
        RoutePaths.authWelcome,
        RoutePaths.register,
        RoutePaths.enterPassword,
        RoutePaths.forgotPassword,
        RoutePaths.resetPassword,
        RoutePaths.emailInput,
        RoutePaths.otpVerification,
        RoutePaths.createUserInfo,
        RoutePaths.intentSelection,
        RoutePaths.interestsSelection,
        RoutePaths.setUsername,
        RoutePaths.emailVerification,
        RoutePaths.onboardingWelcome, // Progress screen — must not be gated

        // New DB-authoritative onboarding routes
        RoutePaths.onboardingPersonaSelection,
        RoutePaths.onboardingInterestsSelection,
        RoutePaths.onboardingPrimarySport,
      };

      // Onboarding paths that both authenticated and unauthenticated users can access
      // Phone users: authenticated via OTP, completing profile
      // Email users: unauthenticated, will create account in final step
      const onboardingPaths = <String>{
        RoutePaths.otpVerification,
        RoutePaths.createUserInfo,
        RoutePaths.intentSelection,
        RoutePaths.interestsSelection,
        RoutePaths.setUsername,
        RoutePaths.onboardingWelcome, // Progress screen — must not be gated

        // New DB-authoritative onboarding routes
        RoutePaths.onboardingPersonaSelection,
        RoutePaths.onboardingInterestsSelection,
        RoutePaths.onboardingPrimarySport,
      };

      final loc = state.matchedLocation;
      final isOnAuthPage = authPaths.contains(loc);
      final isOnboardingPage = onboardingPaths.contains(loc);

      logRoute(
        'loc=$loc auth=$isAuthenticated authPage=$isOnAuthPage onboardingPage=$isOnboardingPage loading=${authState.isLoading}',
      );

      // Don't redirect while auth state is loading
      if (authState.isLoading) {
        logRoute('allow (auth loading)');
        return null;
      }

      // ─── DEEP LINK RETENTION ───
      // A shared game link (https://app.dabbler.pro/game/<id> or
      // dabbler://app/game/<id>) tapped while logged out gets bounced through
      // auth → onboarding. Remember the canonical target here — BEFORE the
      // auth redirects below — and replay it once the user reaches home, so
      // signup/login ends on the game details screen.
      final gateBlocked = !isAuthenticated;
      if (gateBlocked) {
        String? deepLinkTarget;
        if (loc.startsWith('/sports/games/')) {
          deepLinkTarget = loc;
        } else if (loc.startsWith('/game/')) {
          final id = loc.substring('/game/'.length);
          if (id.isNotEmpty) deepLinkTarget = '/sports/games/$id';
        }
        if (deepLinkTarget != null) {
          routerRefreshNotifier.setPendingDeepLink(deepLinkTarget);
          logRoute('stashed pending deep link: $deepLinkTarget');
        }
      }

      // PRIORITY CHECK: Check Supabase auth state directly (may be updated before provider)
      // This catches OAuth callbacks where auth state might not be reflected in provider yet
      // Also ensures ALL authenticated users have a profile before accessing protected routes
      try {
        final supabase = Supabase.instance.client;
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          // Check if profile exists for this user
          final profileResponse = await supabase
              .from(SupabaseConfig.usersTable)
              .select('id')
              .eq('user_id', currentUser.id)
              .limit(1)
              .maybeSingle();

          final hasProfile = profileResponse != null;

          if (!hasProfile) {
            // User is authenticated but has no profile - redirect to onboarding
            // Allow them to stay on any onboarding screen OR welcome screen
            if (!isOnboardingPage && loc != RoutePaths.welcome) {
              logRoute('redirect (no profile) -> ${RoutePaths.createUserInfo}');
              return RoutePaths.createUserInfo;
            }
            // Already on onboarding or welcome, allow it
            logRoute('allow (onboarding/welcome - no profile)');
            return null;
          }
        }
      } catch (e) {
        logRoute('profile check failed: $e');
        // Continue with normal flow if check fails
      }

      // ─── POST-LOGIN WELCOME (runs BEFORE onboarding enforcement) ───
      // After each explicit login, force a welcome screen once per session.
      // Must run before onboarding step enforcement to prevent the async
      // checkResumeState() from short-circuiting returning users into
      // createUserInfo.
      if (isAuthenticated &&
          routerRefreshNotifier.needsPostLoginWelcome &&
          loc != RoutePaths.welcome &&
          loc != RoutePaths.authWelcome &&
          loc != RoutePaths.emailVerification &&
          !isOnboardingPage) {
        logRoute('redirect (post-login welcome) -> ${RoutePaths.welcome}');
        return RoutePaths.welcome;
      }

      // DB-authoritative onboarding routing for authenticated users.
      // This is the single place that decides which onboarding step screen is next.
      // Skip enforcement when navigating to welcome screen (handles returning users)
      if (isAuthenticated && loc != RoutePaths.welcome) {
        final onboardingNotifier = container.read(
          db_onboarding.onboardingControllerProvider.notifier,
        );
        var onboardingState = container.read(
          db_onboarding.onboardingControllerProvider,
        );

        // Only hit the DB when we haven't resolved resume state yet.
        if (onboardingState.step == OnboardingStep.checking &&
            !onboardingState.isLoading) {
          // Important: don't await network/DB work inside redirect.
          // Kicking this off asynchronously avoids the app appearing to “freeze”
          // on routes like OTP when the network is slow.
          unawaited(onboardingNotifier.checkResumeState());
        }

        String? desired;
        switch (onboardingState.step) {
          case OnboardingStep.collectingBasicInfo:
            desired = RoutePaths.createUserInfo;
            break;

          case OnboardingStep.selectingPersona:
            // If persona already chosen (in-memory), proceed to the next data-collection screen.
            desired = onboardingState.data.personaType == null
                ? RoutePaths.onboardingPersonaSelection
                : RoutePaths.createUserInfo;
            break;

          case OnboardingStep.selectingPrimarySport:
            desired = RoutePaths.onboardingInterestsSelection;
            break;

          case OnboardingStep.completed:
          case OnboardingStep.creatingProfile:
          case OnboardingStep.creatingPersonaExtension:
          case OnboardingStep.creatingSportProfile:
          case OnboardingStep.finalizing:
          case OnboardingStep.checking:
          case OnboardingStep.error:
            desired = null;
            break;
        }

        // If onboarding needs a specific route, enforce it.
        // Exception: never redirect away from the progress screen — it is
        // actively creating the profile and will navigate itself when done.
        if (desired != null && loc != desired && loc != RoutePaths.onboardingWelcome) {
          logRoute('redirect (onboarding step) -> $desired');
          return desired;
        }
      }

      // If not authenticated, always stay on onboarding/auth screens
      if (!isAuthenticated) {
        // Public pre-auth pages that must NOT be bounced to landing — the
        // legal docs, reachable pre-auth via direct navigation.
        const publicPreAuthPaths = <String>{
          RoutePaths.aboutTerms,
          RoutePaths.aboutPrivacy,
        };
        // If not on an auth page, redirect to landing page first
        if (!isOnAuthPage && !publicPreAuthPaths.contains(loc)) {
          logRoute('redirect (unauth) -> ${RoutePaths.landing}');
          return RoutePaths.landing;
        }
        // Stay on auth page
        logRoute('allow (unauth on auth page)');
        return null;
      }

      // NOTE: Legacy onboard redirects removed.
      // Authenticated onboarding gating is handled above via OnboardingController DB state.
      // Post-login welcome is handled above (before onboarding enforcement).

      // If authenticated and on an auth page (except welcome, email verification, and onboarding), check profile
      // Allow authenticated users to access onboarding (for phone users completing profile)
      // Allow authenticated users to access email verification (to complete profile creation)
      if (isAuthenticated &&
          isOnAuthPage &&
          loc != RoutePaths.welcome &&
          loc != RoutePaths.authWelcome &&
          loc != RoutePaths.emailVerification &&
          !isOnboardingPage) {
        // User has completed onboarding - redirect to home
        logRoute('redirect (authed on auth page) -> ${RoutePaths.home}');
        return RoutePaths.home;
      }

      // Check if authenticated user without completed onboarding is trying to access protected routes
      // This handles cases where users land on home or other routes after OAuth/OTP
      if (isAuthenticated &&
          !isOnAuthPage &&
          !isOnboardingPage &&
          loc != RoutePaths.welcome &&
          loc != RoutePaths.authWelcome) {
        // Protected-route gating handled via onboarding step enforcement above.
      }

      // ─── DEEP LINK REPLAY ───
      // All post-auth flows (login, signup + onboarding, post-login welcome)
      // terminate on home. If a deep link was stashed on the way in, finish
      // the journey on its target instead. Runs after every gate above, so
      // it can't interrupt onboarding/welcome.
      if (isAuthenticated && loc == RoutePaths.home) {
        final pending = routerRefreshNotifier.consumePendingDeepLink();
        if (pending != null) {
          logRoute('redirect (pending deep link) -> $pending');
          return pending;
        }
      }
      // Reaching the deep-link target directly (already signed in) — drop
      // any stale stash so it can't replay later.
      if (isAuthenticated &&
          routerRefreshNotifier.pendingDeepLink == loc) {
        routerRefreshNotifier.consumePendingDeepLink();
      }

      logRoute('allow');
      return null;
    } catch (e) {
      logRoute('redirect handler failed: $e');
      return null;
    }
  }

  // Route Definitions - Minimal working set
  // Route Definitions — an ordered composition of the six route modules,
  // reproducing the pre-KAN-124 declaration order entry for entry. GoRouter
  // matches in declaration order, so this order is behaviour; it is frozen by
  // test/app/route_inventory.golden.txt. Do not sort or regroup.
  static List<RouteBase> get _routes => [
    rootRoute,
    landingRoute,
    authWelcomeRoute,
    emailInputRoute,
    otpVerificationRoute,
    enterPasswordRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
    registerRoute,
    createUserInfoRoute,
    languageSelectionRoute,
    interestsSelectionRoute,
    intentSelectionRoute,
    onboardingPersonaSelectionRoute,
    setUsernameRoute,
    welcomeRoute,
    emailVerificationRoute,
    onboardingWelcomeRoute,
    onboardingInterestsSelectionRoute,
    onboardingPrimarySportRoute,
    homeShellRoute,
    sportsGamesGameIdRoute,
    newsNewsIdRoute,
    sportsVenuesVenueIdRoute,
    gameGameIdRoute,
    socialRoute,
    sportsExploreRoute,
    activitiesRoute,
    rewardsRoute,
    profileRoute,
    sportProfileRoute,
    myVenueSubmissionsRoute,
    notificationsRoute,
    profileEditRoute,
    profileSportsPreferencesRoute,
    settingsRoute,
    addPersonaInterestsRoute,
    addPersonaPrimarySportRoute,
    addPersonaUsernameRoute,
    addPersonaWelcomeRoute,
    transactionsRoute,
    createGameRoute,
    createGameBasicInfoRoute,
    editGameRoute,
    settingsAccountRoute,
    settingsPrivacyRoute,
    settingsNotificationsRoute,
    settingsThemeRoute,
    settingsLanguageRoute,
    preferencesGamesRoute,
    helpCenterRoute,
    helpContactRoute,
    helpBugReportRoute,
    aboutTermsRoute,
    aboutPrivacyRoute,
    aboutLicensesRoute,
    socialCreatePostRoute,
    postComposerRoute,
    socialFeedRoute,
    socialSearchRoute,
    hashtagFeedSlugRoute,
    socialPostDetailPostIdRoute,
    userProfileUserIdRoute,
    socialOnboardingWelcomeRoute,
    socialOnboardingFriendsRoute,
    socialOnboardingPrivacyRoute,
    socialOnboardingNotificationsRoute,
    socialOnboardingCompleteRoute,
    socialFriendsRoute,
    followingProfileIdRoute,
    followersProfileIdRoute,
    socialChatListRoute,
    socialNotificationsRoute,
    socialMessagesRoute,
    socialChatConversationIdRoute,
    socialEditPostRoute,
    socialAnalyticsRoute,
    adminModerationQueueRoute,
    adminSafetyOverviewRoute,
    errorMessageRoute,
  ];
}
