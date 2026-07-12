import 'dart:async';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

// Onboarding screens
import 'package:dabbler/features/auth_onboarding/presentation/screens/landing_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/auth_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_input_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/otp_verification_screen.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/create_user_information.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/intent_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/interests_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/set_username_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_verification_screen.dart';

// Profile Onboarding screens
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_sports_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_preferences_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_privacy_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_completion_screen.dart';

// New Onboarding System screens
import 'package:dabbler/features/auth_onboarding/presentation/screens/primary_sport_selection_screen.dart';

// DB-authoritative onboarding state
import 'package:dabbler/features/auth_onboarding/presentation/controllers/onboarding_controller.dart'
    as db_onboarding;
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_state.dart';

// Authentication screens
import 'package:dabbler/features/auth_onboarding/presentation/screens/forgot_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/reset_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/register_screen.dart';

// Core screens
import 'package:dabbler/features/error/presentation/pages/error_page.dart';
import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:dabbler/features/news/presentation/screens/news_detail_screen.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/social/presentation/screens/real_friends_screen.dart' show RealFriendsScreen;
import 'package:dabbler/features/misc/presentation/screens/activities_screen_v2.dart';
import 'package:dabbler/features/misc/presentation/screens/rewards_screen.dart';

// Profile screens
import 'package:dabbler/features/profile/presentation/screens/profile/profile_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/sport_profile_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/profile_avatar_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/profile_sports_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/account_management_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/privacy_settings_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/notification_settings_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/preferences/game_preferences_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/preferences/availability_preferences_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/theme_settings_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/language_selection_screen.dart';
import 'package:dabbler/features/misc/presentation/screens/help_center_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/support/contact_support_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/support/bug_report_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/about/terms_of_service_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/about/privacy_policy_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/about/licenses_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/about/eula_gate_screen.dart';
import 'package:dabbler/core/services/eula_service.dart';

// Add Persona screens (using consolidated onboarding screens with mode parameter)
// No longer need separate add_persona_* imports - using unified screens

// Organiser venue submissions
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/create_venue_submission_screen.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/my_venue_submissions_screen.dart';
import 'package:dabbler/features/venue_submissions/presentation/screens/venue_submission_detail_screen.dart';

// Transactions screens
import 'package:dabbler/features/misc/presentation/screens/transactions_screen.dart';

// Notifications screens
import 'package:dabbler/features/notifications/presentation/screens/notifications_screen_v2.dart';

// Game screens
import 'package:dabbler/features/misc/presentation/screens/game_composer_screen.dart';

// Social screens
import 'package:dabbler/features/social/presentation/screens/post_detail_screen.dart';
import 'package:dabbler/features/social/presentation/screens/hashtag_feed_screen.dart';
import 'package:dabbler/features/social/presentation/screens/social_search_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/user_profile_screen.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_friends_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_privacy_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_notifications_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_complete_screen.dart';
import 'package:dabbler/features/social/presentation/screens/real_friends_screen.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';

// Admin screens
import 'package:dabbler/features/admin/presentation/screens/moderation_queue_screen.dart';
import 'package:dabbler/features/admin/presentation/screens/safety_overview_screen.dart';

// Utilities
import '../utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import '../utils/transitions/page_transitions.dart';

// Import RegistrationData from the correct location

// Export GoRouter instance for use in main.dart
final appRouter = AppRouter.router;

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  // Analytics Observer
  static final _routeObserver = RouteObserver<ModalRoute<void>>();
  static RouteObserver<ModalRoute<void>> get routeObserver => _routeObserver;

  // Router Instance
  // Toggle for verbose route logging (only active in debug mode)
  static const bool _routeLogging =
      true; // set false to silence even debug prints

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
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

      // ─── EULA / TERMS OF USE GATE (Guideline 1.2) ───
      // Must run before every other check so it blocks all paths into
      // registration/login, including the landing page and OAuth callback
      // handling. Does not touch auth/demo-account logic — it only decides
      // whether to show the acceptance screen first.
      if (FeatureFlags.requireEulaAcceptance &&
          !EulaService.hasAccepted &&
          loc != RoutePaths.eulaGate &&
          loc != RoutePaths.aboutTerms &&
          loc != RoutePaths.aboutPrivacy) {
        logRoute('redirect (eula not accepted) -> ${RoutePaths.eulaGate}');
        return RoutePaths.eulaGate;
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
          loc != RoutePaths.eulaGate &&
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
        // EULA gate and the legal docs it links to. Without this exemption
        // the EULA redirect (landing -> eula-gate) and this landing bounce
        // (eula-gate -> landing) form an infinite redirect loop for any user
        // who hasn't accepted yet (e.g. a fresh install on a real device).
        const publicPreAuthPaths = <String>{
          RoutePaths.eulaGate,
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

      logRoute('allow');
      return null;
    } catch (e) {
      logRoute('redirect handler failed: $e');
      return null;
    }
  }

  // Route Definitions - Minimal working set
  static List<RouteBase> get _routes => [
    // Root route - handles OAuth callbacks with ?code=xxx
    GoRoute(
      path: '/',
      redirect: (context, state) {
        // If there's a code query param, this is an OAuth callback
        // Let the redirect logic handle where to send the user
        final hasCode = state.uri.queryParameters.containsKey('code');
        if (hasCode) {
          // Return landing so redirect logic can properly route authenticated user
          return RoutePaths.landing;
        }
        // Otherwise redirect to landing
        return RoutePaths.landing;
      },
    ),

    // Landing page route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/landing',
      pageBuilder: (context, state) =>
          FadeTransitionPage(key: state.pageKey, child: const LandingPage()),
    ),

    // Auth-choice welcome screen (after landing)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.authWelcome,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const AuthWelcomeScreen(),
      ),
    ),

    // Email input route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.emailInput,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const EmailInputScreen(),
      ),
    ),

    // OTP verification route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.otpVerification,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final identifier = extra is Map
            ? extra['identifier'] as String?
            : extra is Map
            ? extra['phone']
                  as String? // Legacy support
            : extra as String?;
        final identifierTypeStr = extra is Map
            ? extra['identifierType'] as String?
            : null;
        final userExistsBeforeOtp = extra is Map
            ? extra['userExistsBeforeOtp'] as bool?
            : null;

        // Parse identifier type
        IdentifierType? identifierType;
        if (identifierTypeStr == 'email') {
          identifierType = IdentifierType.email;
        } else if (identifierTypeStr == 'phone') {
          identifierType = IdentifierType.phone;
        }
        // If null, OtpVerificationScreen will auto-detect

        return FadeTransitionPage(
          key: state.pageKey,
          child: OtpVerificationScreen(
            identifier: identifier,
            identifierType: identifierType,
            userExistsBeforeOtp: userExistsBeforeOtp,
            phoneNumber: identifier, // Legacy support
          ),
        );
      },
    ),

    // Enter password route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.enterPassword,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final email = extra is Map
            ? extra['email'] as String?
            : extra as String?;
        return FadeTransitionPage(
          key: state.pageKey,
          child: EnterPasswordScreen(email: email ?? ''),
        );
      },
    ),

    // Forgot password route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.forgotPassword,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const ForgotPasswordScreen(),
      ),
    ),

    // Reset password route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.resetPassword,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const ResetPasswordScreen(),
      ),
    ),

    // Register route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.register,
      pageBuilder: (context, state) =>
          FadeTransitionPage(key: state.pageKey, child: const RegisterScreen()),
    ),

    // Create user information route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.createUserInfo,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final email = extra is Map
            ? extra['email'] as String?
            : (extra is String ? extra : null);
        final phone = extra is Map ? extra['phone'] as String? : null;
        final forceNew = extra is Map ? extra['forceNew'] as bool? : false;
        return SlideTransitionPage(
          key: state.pageKey,
          child: CreateUserInformation(
            email: email,
            phone: phone,
            forceNew: forceNew ?? false,
          ),
          direction: SlideDirection.fromLeft,
        );
      },
    ),

    // Language selection route (placeholder)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/language_selection',
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const Scaffold(
          body: Center(child: Text('Language Selection - Coming Soon')),
        ),
      ),
    ),

    // Interests selection route (after intent selection)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.interestsSelection,
      pageBuilder: (context, state) {
        return SlideTransitionPage(
          key: state.pageKey,
          child: const InterestsSelectionScreen(),
          direction: SlideDirection.fromLeft,
        );
      },
    ),

    // Intent selection route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.intentSelection,
      pageBuilder: (context, state) {
        return SlideTransitionPage(
          key: state.pageKey,
          child: const IntentSelectionScreen(),
          direction: SlideDirection.fromLeft,
        );
      },
    ),

    // Set username route (for phone users)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.setUsername,
      pageBuilder: (context, state) {
        return SlideTransitionPage(
          key: state.pageKey,
          child: const SetUsernameScreen(),
          direction: SlideDirection.fromLeft,
        );
      },
    ),

    // Welcome route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.welcome,
      redirect: (context, state) {
        // Prevent returning to welcome after it has been dismissed
        if (!routerRefreshNotifier.needsPostLoginWelcome) {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) {
        final extra = state.extra;
        final displayName = extra is Map
            ? extra['displayName'] as String?
            : 'Player';
        final personaType = extra is Map
            ? extra['personaType'] as String?
            : 'player';
        final isFirstTime = extra is Map ? extra['isFirstTime'] as bool? : true;
        return ScaleTransitionPage(
          key: state.pageKey,
          child: WelcomeScreen(
            displayName: displayName ?? 'Player',
            personaType: personaType ?? 'player',
            isFirstTime: isFirstTime ?? true,
          ),
        );
      },
    ),

    // Email verification pending route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.emailVerification,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final onboardingData = extra is Map<String, dynamic> ? extra : null;
        return FadeTransitionPage(
          key: state.pageKey,
          child: EmailVerificationScreen(onboardingData: onboardingData),
        );
      },
    ),

    // Profile Onboarding Routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.onboardingWelcome,
      name: RouteNames.onboardingWelcome,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const ProfileOnboardingWelcomeScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.onboardingSports,
      name: RouteNames.onboardingSports,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const OnboardingSportsScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.onboardingPreferences,
      name: RouteNames.onboardingPreferences,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const OnboardingPreferencesScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.onboardingPrivacy,
      name: RouteNames.onboardingPrivacy,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const OnboardingPrivacyScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.onboardingCompletion,
      name: RouteNames.onboardingCompletion,
      pageBuilder: (context, state) => ScaleTransitionPage(
        key: state.pageKey,
        child: const OnboardingCompletionScreen(),
      ),
    ),

    // Interests Selection Route
    // Note: This is the sports interests selection during onboarding
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.onboardingInterestsSelection,
      name: RouteNames.onboardingInterestsSelection,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const InterestsSelectionScreen(),
      ),
    ),

    // Primary Sport Selection Route
    // Note: Select ONE sport to represent the user
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.onboardingPrimarySport,
      name: RouteNames.onboardingPrimarySport,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const PrimarySportSelectionScreen(),
      ),
    ),

    // ── Shell route: persistent bottom-nav tabs with per-tab URLs ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigationScreen(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0 — Home / Feeds
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.home,
              name: RouteNames.home,
              pageBuilder: (context, state) => FadeThroughTransitionPage(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
            ),
          ],
        ),

        // Branch 1 — Community
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.community,
              name: RouteNames.community,
              pageBuilder: (context, state) => FadeThroughTransitionPage(
                key: state.pageKey,
                child: const RealFriendsScreen(),
              ),
            ),
          ],
        ),

        // Branch 2 — Venues
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.venuesTab,
              name: RouteNames.venuesTab,
              pageBuilder: (context, state) => FadeThroughTransitionPage(
                key: state.pageKey,
                child: const VenuesScreen(),
              ),
            ),
          ],
        ),

        // Branch 3 — Games
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.gamesTab,
              name: RouteNames.gamesTab,
              pageBuilder: (context, state) => FadeThroughTransitionPage(
                key: state.pageKey,
                child: const GamesScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // ── Deep-link entry routes ─────────────────────────────────────────────
    // These top-level paths let the OS (Android / iOS) hand off
    // dabbler://app/game/:gameId  and  dabbler://app/create-game  directly
    // to the correct screen without needing to know the shell structure.

    // /sports/games/:gameId — game detail (root-level, no shell/bottom-nav)
    GoRoute(
      path: '/sports/games/:gameId',
      name: RouteNames.gameDetail,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final gameId = state.pathParameters['gameId']!;
        // ?focus=requests (join-request notifications) scrolls the detail
        // screen down to the pending-requests card.
        final focus = state.uri.queryParameters['focus'];
        return SharedAxisTransitionPage(
          key: state.pageKey,
          child: GameDetailScreen(
            gameId: gameId,
            focusRequests: focus == 'requests',
          ),
          type: SharedAxisType.horizontal,
        );
      },
    ),

    // /news/:newsId — news article detail (root-level, no shell)
    GoRoute(
      path: '/news/:newsId',
      name: RouteNames.newsDetail,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final item = state.extra as FeedNewsItem;
        return CupertinoPage(
          key: state.pageKey,
          child: NewsDetailScreen(item: item),
        );
      },
    ),

    // /sports/venues/:venueId — venue detail (root-level, no shell/bottom-nav)
    GoRoute(
      path: '/sports/venues/:venueId',
      name: RouteNames.venueDetail,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final venueId = state.pathParameters['venueId']!;
        return SharedAxisTransitionPage(
          key: state.pageKey,
          child: VenueDetailScreen(venueId: venueId),
          type: SharedAxisType.horizontal,
        );
      },
    ),

    // dabbler://app/game/:gameId → /sports/games/:gameId (root-level detail)
    GoRoute(
      path: '/game/:gameId',
      redirect: (context, state) {
        final gameId = state.pathParameters['gameId'];
        if (gameId == null || gameId.isEmpty) return RoutePaths.gamesTab;
        return '/sports/games/$gameId';
      },
    ),

    // dabbler://app/create-game is already a first-class top-level route
    // (/create-game) so no redirect needed — it resolves directly.


    GoRoute(
      path: RoutePaths.social,
      name: RouteNames.social,
      redirect: (context, state) => RoutePaths.community,
    ),

    // Legacy /sports top-level redirect handled inside the shell branch above.
    // Sports explore screen (direct access, feature-flagged)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.sportsExplore,
      name: RouteNames.sports,
      redirect: (context, state) {
        if (!FeatureFlags.enableGameBrowsing) {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const ExploreScreen(),
      ),
    ),

    // Activities route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.activities,
      name: RouteNames.activities,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const ActivitiesScreenV2(),
      ),
    ),

    // Rewards route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.rewards,
      name: RouteNames.rewards,
      redirect: (context, state) {
        if (!FeatureFlags.enableRewards) {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const RewardsScreen(),
      ),
    ),

    // Profile route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.profile,
      name: RouteNames.profile,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const ProfileScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.sportProfile,
      name: RouteNames.sportProfile,
      pageBuilder: (context, state) {
        final args = state.extra;
        if (args is! SportProfileRouteArgs) {
          return SharedAxisTransitionPage(
            key: state.pageKey,
            child: const ErrorPage(message: 'Missing sport profile context.'),
            type: SharedAxisType.horizontal,
          );
        }

        return SharedAxisTransitionPage(
          key: state.pageKey,
          child: SportProfileScreen(args: args),
          type: SharedAxisType.horizontal,
        );
      },
    ),

    // Organiser Venue Submissions
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.myVenueSubmissions,
      name: RouteNames.myVenueSubmissions,
      redirect: (context, state) {
        final container = ProviderScope.containerOf(context, listen: false);
        final profileState = container.read(profileControllerProvider);
        final profileType = profileState.profile?.profileType;
        if (profileType != 'organiser') {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const MyVenueSubmissionsScreen(),
        type: SharedAxisType.horizontal,
      ),
      routes: [
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: 'create',
          name: RouteNames.createVenueSubmission,
          pageBuilder: (context, state) {
            final initial = state.extra is VenueSubmissionModel
                ? state.extra as VenueSubmissionModel
                : null;
            return SharedAxisTransitionPage(
              key: state.pageKey,
              child: CreateVenueSubmissionScreen(initial: initial),
              type: SharedAxisType.horizontal,
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: ':${RouteParams.submissionId}',
          name: RouteNames.venueSubmissionDetail,
          pageBuilder: (context, state) {
            final id = state.pathParameters[RouteParams.submissionId] ?? '';
            return SharedAxisTransitionPage(
              key: state.pageKey,
              child: VenueSubmissionDetailScreen(submissionId: id),
              type: SharedAxisType.horizontal,
            );
          },
        ),
      ],
    ),

    // Notifications route (hidden for MVP)
    // Route kept for deep links/admin access but UI entry points hidden
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.notifications,
      redirect: (context, state) {
        // Notifications hidden for MVP
        if (!FeatureFlags.notifications) {
          return RoutePaths.home;
        }
        return null; // Allow access if enabled
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const NotificationsScreenV2(),
      ),
    ),

    // Profile Edit route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profile/edit',
      pageBuilder: (context, state) => BottomSheetTransitionPage(
        key: state.pageKey,
        child: const ProfileEditScreen(),
      ),
    ),

    // Profile Photo route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profile/photo',
      pageBuilder: (context, state) => ScaleTransitionPage(
        key: state.pageKey,
        child: const ProfileAvatarScreen(),
      ),
    ),

    // Profile Sports Preferences route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profile/sports-preferences',
      pageBuilder: (context, state) {
        final profileType = state.extra is Map<String, dynamic>
            ? (state.extra as Map<String, dynamic>)['profileType'] as String?
            : null;
        return SharedAxisTransitionPage(
          key: state.pageKey,
          child: ProfileSportsScreen(profileType: profileType),
          type: SharedAxisType.horizontal,
        );
      },
    ),

    // Settings route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const SettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Add Persona Flow Routes (from Settings)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.addPersonaInterests,
      name: RouteNames.addPersonaInterests,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const InterestsSelectionScreen(
          mode: InterestsSelectionMode.addPersona,
        ),
        type: SharedAxisType.horizontal,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.addPersonaPrimarySport,
      name: RouteNames.addPersonaPrimarySport,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const PrimarySportSelectionScreen(
          mode: PrimarySportSelectionMode.addPersona,
        ),
        type: SharedAxisType.horizontal,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.addPersonaUsername,
      name: RouteNames.addPersonaUsername,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const SetUsernameScreen(mode: SetUsernameMode.addPersona),
        type: SharedAxisType.horizontal,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.addPersonaWelcome,
      name: RouteNames.addPersonaWelcome,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return FadeTransitionPage(
          key: state.pageKey,
          child: WelcomeScreen(
            displayName: extra?['displayName'] as String? ?? '',
            personaType: extra?['personaType'] as String? ?? 'player',
            isFirstTime: extra?['isFirstTime'] as bool? ?? false,
            isConversion: extra?['isConversion'] as bool? ?? false,
          ),
        );
      },
    ),

    // Transactions route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/transactions',
      redirect: (context, state) {
        if (!FeatureFlags.enablePayments) {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const TransactionsScreen(),
      ),
    ),

    // Game Creation Routes - Differentiated by profile type
    // Organisers can create, players cannot (MVP)
    GoRoute(
      path: RoutePaths.createGame,
      name: RouteNames.createGame,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) async {
        // Check user's profile type and apply feature flags
        final container = ProviderScope.containerOf(context, listen: false);
        final profileState = container.read(profileControllerProvider);
        final profileType = profileState.profile?.profileType;

        // Block players from creating games if feature disabled
        if (profileType == 'player' && !FeatureFlags.enablePlayerGameCreation) {
          return RoutePaths.home;
        }

        // Block organisers from creating games if feature disabled
        if (profileType == 'organiser' &&
            !FeatureFlags.enableOrganiserGameCreation) {
          return RoutePaths.home;
        }

        // Allow access if profile type has permission
        return null;
      },
      // Drawer-style modal: leaves the top safe area exposed and lets the
      // composer's glass surface blur the screen behind it.
      pageBuilder: (context, state) => AdaptiveModalPage(
        key: state.pageKey,
        transparentSurface: true,
        child: const GameComposerScreen(),
      ),
    ),

    GoRoute(
      path: RoutePaths.createGameBasicInfo,
      name: RouteNames.createGameBasicInfo,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) async {
        final container = ProviderScope.containerOf(context, listen: false);
        final profileState = container.read(profileControllerProvider);
        final profileType = profileState.profile?.profileType;

        if (profileType == 'player' && !FeatureFlags.enablePlayerGameCreation) {
          return RoutePaths.home;
        }
        if (profileType == 'organiser' &&
            !FeatureFlags.enableOrganiserGameCreation) {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) => AdaptiveModalPage(
        key: state.pageKey,
        transparentSurface: true,
        child: const GameComposerScreen(),
      ),
    ),

    // Edit an existing game — same drawer as creation, prefilled. Host-only
    // enforcement lives in rpc_update_game; the entry button is host-gated.
    GoRoute(
      path: RoutePaths.editGame,
      name: RouteNames.editGame,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => AdaptiveModalPage(
        key: state.pageKey,
        transparentSurface: true,
        child: GameComposerScreen(
          editGameId: state.pathParameters['gameId']!,
        ),
      ),
    ),

    // Settings sub-routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings/account',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const AccountManagementScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings/privacy',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const PrivacySettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings/notifications',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const NotificationSettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings/theme',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const ThemeSettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings/language',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const LanguageSelectionScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Preferences routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/preferences/games',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const GamePreferencesScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/preferences/availability',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const AvailabilityPreferencesScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Help & Support routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/help/center',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const HelpCenterScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/help/contact',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const ContactSupportScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/help/bug-report',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const BugReportScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // EULA / Terms-of-Use acceptance gate — shown before login/registration.
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.eulaGate,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const EulaGateScreen(),
      ),
    ),

    // About routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.aboutTerms,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const TermsOfServiceScreen(),
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.aboutPrivacy,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const PrivacyPolicyScreen(),
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/about/licenses',
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const LicensesScreen(),
      ),
    ),

    // ── Post Creation ──
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialCreatePost,
      name: RouteNames.socialCreatePost,
      // transparentSurface: the composer draws its own glass panel — without
      // it the modal frame paints a second opaque sheet behind it.
      pageBuilder: (context, state) => AdaptiveModalPage(
        key: state.pageKey,
        transparentSurface: true,
        child: const PostComposerScreen(),
      ),
    ),

    // ── Post Composer (full-featured) ──
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.postComposer,
      name: RouteNames.postComposer,
      pageBuilder: (context, state) => AdaptiveModalPage(
        key: state.pageKey,
        transparentSurface: true,
        child: const PostComposerScreen(),
      ),
    ),

    // Social Feed route — feed lives in HomeScreen now.
    GoRoute(
      path: RoutePaths.socialFeed,
      name: RouteNames.socialFeed,
      redirect: (context, state) => RoutePaths.home,
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialSearch,
      name: RouteNames.socialSearch,
      redirect: (context, state) {
        if (!FeatureFlags.socialFeed) return RoutePaths.home;
        return null;
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const SocialSearchScreen(),
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '${RoutePaths.hashtagFeed}/:slug',
      name: RouteNames.hashtagFeed,
      pageBuilder: (context, state) {
        final slug = state.pathParameters['slug'] ?? '';
        final initialPostCount = int.tryParse(
          state.uri.queryParameters['postCount'] ?? '',
        );
        return FadeThroughTransitionPage(
          key: state.pageKey,
          child: HashtagFeedScreen(
            hashtagSlug: Uri.decodeComponent(slug),
            initialPostCount: initialPostCount,
          ),
        );
      },
    ),

    GoRoute(
      path: '${RoutePaths.socialPostDetail}/:postId',
      name: RouteNames.socialPostDetail,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final postId = state.pathParameters['postId'] ?? '';
        return ScaleTransitionPage(
          key: state.pageKey,
          child: PostDetailScreen(postId: postId),
        );
      },
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '${RoutePaths.userProfile}/:userId',
      name: RouteNames.userProfile,
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        final profileId = state.uri.queryParameters['profileId'];
        return SharedAxisTransitionPage(
          key: state.pageKey,
          child: UserProfileScreen(userId: userId, profileId: profileId),
          type: SharedAxisType.horizontal,
        );
      },
    ),

    // Social Onboarding Routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialOnboardingWelcome,
      name: RouteNames.socialOnboardingWelcome,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingWelcomeScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialOnboardingFriends,
      name: RouteNames.socialOnboardingFriends,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingFriendsScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialOnboardingPrivacy,
      name: RouteNames.socialOnboardingPrivacy,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingPrivacyScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialOnboardingNotifications,
      name: RouteNames.socialOnboardingNotifications,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingNotificationsScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialOnboardingComplete,
      name: RouteNames.socialOnboardingComplete,
      pageBuilder: (context, state) => ScaleTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingCompleteScreen(),
      ),
    ),

    // Social Friends (People) screen — own profile, 3 tabs
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialFriends,
      name: RouteNames.socialFriends,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const RealFriendsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Following list for a specific profile (2 tabs, starts on Following)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '${RoutePaths.following}/:profileId',
      name: RouteNames.following,
      pageBuilder: (context, state) {
        final profileId = state.pathParameters['profileId']!;
        return SharedAxisTransitionPage(
          key: state.pageKey,
          child: RealFriendsScreen(profileId: profileId, initialTab: 0),
          type: SharedAxisType.horizontal,
        );
      },
    ),

    // Followers list for a specific profile (2 tabs, starts on Followers)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '${RoutePaths.followers}/:profileId',
      name: RouteNames.followers,
      pageBuilder: (context, state) {
        final profileId = state.pathParameters['profileId']!;
        return SharedAxisTransitionPage(
          key: state.pageKey,
          child: RealFriendsScreen(profileId: profileId, initialTab: 1),
          type: SharedAxisType.horizontal,
        );
      },
    ),

    // Placeholder Social Routes (for routes referenced in code but screens don't exist yet)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialChatList,
      name: RouteNames.socialChatList,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const _PlaceholderScreen(title: 'Chat List'),
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialNotifications,
      name: RouteNames.socialNotifications,
      redirect: (context, state) {
        if (!FeatureFlags.notifications) return RoutePaths.home;
        return null;
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const _PlaceholderScreen(title: 'Social Notifications'),
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialMessages,
      name: RouteNames.socialMessages,
      redirect: (context, state) {
        if (!FeatureFlags.messaging) return RoutePaths.home;
        return null;
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const _PlaceholderScreen(title: 'Messages'),
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '${RoutePaths.socialChat}/:conversationId',
      name: RouteNames.socialChat,
      redirect: (context, state) {
        if (!FeatureFlags.messaging) return RoutePaths.home;
        return null;
      },
      pageBuilder: (context, state) {
        final conversationId = state.pathParameters['conversationId'] ?? '';
        return FadeThroughTransitionPage(
          key: state.pageKey,
          child: _PlaceholderScreen(
            title: 'Chat: ${conversationId.substring(0, 8)}...',
          ),
        );
      },
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialEditPost,
      name: RouteNames.socialEditPost,
      pageBuilder: (context, state) => BottomSheetTransitionPage(
        key: state.pageKey,
        child: const _PlaceholderScreen(title: 'Edit Post'),
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.socialAnalytics,
      name: RouteNames.socialAnalytics,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const _PlaceholderScreen(title: 'Social Analytics'),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Admin routes with admin check guards
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.adminModerationQueue,
      redirect: (context, state) async {
        // Gate on authentication before the admin RPC, so the route is never
        // momentarily reachable while auth state is still hydrating.
        if (Supabase.instance.client.auth.currentSession == null) {
          return RoutePaths.landing;
        }
        try {
          final response = await Supabase.instance.client.rpc(SupabaseConfig.isAdminFn);
          if (response != true) {
            return RoutePaths.home; // Redirect non-admins to home
          }
        } catch (e) {
          return RoutePaths.home; // Redirect on error
        }
        return null; // Allow access if admin
      },
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const ModerationQueueScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: RoutePaths.adminSafetyOverview,
      redirect: (context, state) async {
        // Gate on authentication before the admin RPC, so the route is never
        // momentarily reachable while auth state is still hydrating.
        if (Supabase.instance.client.auth.currentSession == null) {
          return RoutePaths.landing;
        }
        try {
          final response = await Supabase.instance.client.rpc(SupabaseConfig.isAdminFn);
          if (response != true) {
            return RoutePaths.home; // Redirect non-admins to home
          }
        } catch (e) {
          return RoutePaths.home; // Redirect on error
        }
        return null; // Allow access if admin
      },
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const SafetyOverviewScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Error route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '${RoutePaths.error}:message',
      name: RouteNames.error,
      pageBuilder: (context, state) {
        final message = state.pathParameters['message'];
        return FadeTransitionPage(
          key: state.pageKey,
          child: ErrorPage(message: message),
        );
      },
    ),
  ];
}

/// Placeholder screen for routes that don't have screens implemented yet
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '$title\nComing Soon',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
