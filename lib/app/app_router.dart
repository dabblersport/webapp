import 'dart:async';
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
import 'package:dabbler/features/auth_onboarding/presentation/screens/identity_verification_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_input_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/otp_verification_screen.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/create_user_information.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/intent_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/interests_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/set_password_screen.dart';
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
import 'package:dabbler/features/explore/presentation/screens/sports_screen.dart';
import 'package:dabbler/features/misc/presentation/screens/activities_screen_v2.dart';
import 'package:dabbler/features/misc/presentation/screens/rewards_screen.dart';

// Profile screens
import 'package:dabbler/features/profile/presentation/screens/profile/profile_screen.dart';
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
import 'package:dabbler/features/misc/presentation/screens/create_game_screen.dart';

// Social screens
import 'package:dabbler/features/social/presentation/screens/post_detail_screen.dart';
import 'package:dabbler/features/social/presentation/screens/social_search_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/profile/user_profile_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_friends_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_privacy_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_notifications_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_complete_screen.dart';
import 'package:dabbler/features/social/presentation/screens/real_friends_screen.dart';
import 'package:dabbler/features/social/presentation/screens/create_post_screen.dart';

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
    debugLogDiagnostics: true, // Enable debug logging to see what's happening
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
        RoutePaths.phoneInput,
        RoutePaths.emailInput,
        RoutePaths.otpVerification,
        RoutePaths.createUserInfo,
        RoutePaths.intentSelection,
        RoutePaths.interestsSelection,
        RoutePaths.setPassword,
        RoutePaths.setUsername,
        RoutePaths.emailVerification,

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
        RoutePaths.setPassword,
        RoutePaths.setUsername,

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

      // PRIORITY CHECK: Check Supabase auth state directly (may be updated before provider)
      // This catches OAuth callbacks where auth state might not be reflected in provider yet
      // Also ensures ALL authenticated users have a profile before accessing protected routes
      try {
        final supabase = Supabase.instance.client;
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          // Check if profile exists for this user
          final profileResponse = await supabase
              .from('profiles')
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
        if (desired != null && loc != desired) {
          logRoute('redirect (onboarding step) -> $desired');
          return desired;
        }
      }

      // If not authenticated, always stay on onboarding/auth screens
      if (!isAuthenticated) {
        // If not on an auth page, redirect to landing page first
        if (!isOnAuthPage) {
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
      path: '/landing',
      pageBuilder: (context, state) =>
          FadeTransitionPage(key: state.pageKey, child: const LandingPage()),
    ),

    // Auth-choice welcome screen (after landing)
    GoRoute(
      path: RoutePaths.authWelcome,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const AuthWelcomeScreen(),
      ),
    ),

    GoRoute(
      path: RoutePaths.phoneInput,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const IdentityVerificationScreen(),
      ),
    ),

    // Email input route
    GoRoute(
      path: RoutePaths.emailInput,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const EmailInputScreen(),
      ),
    ),

    // OTP verification route
    GoRoute(
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
      path: RoutePaths.forgotPassword,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const ForgotPasswordScreen(),
      ),
    ),

    // Reset password route
    GoRoute(
      path: RoutePaths.resetPassword,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const ResetPasswordScreen(),
      ),
    ),

    // Register route
    GoRoute(
      path: RoutePaths.register,
      pageBuilder: (context, state) =>
          FadeTransitionPage(key: state.pageKey, child: const RegisterScreen()),
    ),

    // Create user information route
    GoRoute(
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
      path: RoutePaths.intentSelection,
      pageBuilder: (context, state) {
        return SlideTransitionPage(
          key: state.pageKey,
          child: const IntentSelectionScreen(),
          direction: SlideDirection.fromLeft,
        );
      },
    ),

    // Set password route (for email users)
    GoRoute(
      path: RoutePaths.setPassword,
      pageBuilder: (context, state) {
        return SlideTransitionPage(
          key: state.pageKey,
          child: const SetPasswordScreen(),
          direction: SlideDirection.fromLeft,
        );
      },
    ),

    // Set username route (for phone users)
    GoRoute(
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
      path: RoutePaths.welcome,
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
      path: RoutePaths.onboardingWelcome,
      name: RouteNames.onboardingWelcome,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const ProfileOnboardingWelcomeScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      path: RoutePaths.onboardingSports,
      name: RouteNames.onboardingSports,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const OnboardingSportsScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      path: RoutePaths.onboardingPreferences,
      name: RouteNames.onboardingPreferences,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const OnboardingPreferencesScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      path: RoutePaths.onboardingPrivacy,
      name: RouteNames.onboardingPrivacy,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const OnboardingPrivacyScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
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
      path: RoutePaths.onboardingPrimarySport,
      name: RouteNames.onboardingPrimarySport,
      pageBuilder: (context, state) => FadeTransitionPage(
        key: state.pageKey,
        child: const PrimarySportSelectionScreen(),
      ),
    ),

    // Home route
    GoRoute(
      path: RoutePaths.home,
      name: RouteNames.home,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const MainNavigationScreen(),
      ),
    ),

    // Social/Community route — feed lives in HomeScreen now.
    GoRoute(
      path: RoutePaths.social,
      name: RouteNames.social,
      redirect: (context, state) => RoutePaths.home,
    ),

    // Sports route (hidden for MVP - not in tab list)
    // Route kept for deep links/admin access but UI entry points hidden
    GoRoute(
      path: RoutePaths.sports,
      name: RouteNames.sports,
      redirect: (context, state) {
        // Hide Sports from MVP - redirect to Activities (My Games)
        // Keep route definition for deep links/future enablement
        if (!FeatureFlags.enableGameBrowsing) {
          return RoutePaths.home;
        }
        return null; // Allow access if enabled
      },
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const ExploreScreen(),
      ),
    ),

    // Activities route
    GoRoute(
      path: RoutePaths.activities,
      name: RouteNames.activities,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const ActivitiesScreenV2(),
      ),
    ),

    // Rewards route
    GoRoute(
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
      path: RoutePaths.profile,
      name: RouteNames.profile,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const ProfileScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Organiser Venue Submissions
    GoRoute(
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
      path: '/profile/edit',
      pageBuilder: (context, state) => BottomSheetTransitionPage(
        key: state.pageKey,
        child: const ProfileEditScreen(),
      ),
    ),

    // Profile Photo route
    GoRoute(
      path: '/profile/photo',
      pageBuilder: (context, state) => ScaleTransitionPage(
        key: state.pageKey,
        child: const ProfileAvatarScreen(),
      ),
    ),

    // Profile Sports Preferences route
    GoRoute(
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
      path: '/settings',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const SettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Add Persona Flow Routes (from Settings)
    GoRoute(
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
      path: RoutePaths.addPersonaUsername,
      name: RouteNames.addPersonaUsername,
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const SetUsernameScreen(mode: SetUsernameMode.addPersona),
        type: SharedAxisType.horizontal,
      ),
    ),
    GoRoute(
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
      pageBuilder: (context, state) => BottomSheetTransitionPage(
        key: state.pageKey,
        child: CreateGameScreen(
          initialData: state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : null,
        ),
      ),
    ),

    GoRoute(
      path: RoutePaths.createGameBasicInfo,
      name: RouteNames.createGameBasicInfo,
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

        return null; // Allow access if profile type has permission
      },
      pageBuilder: (context, state) => BottomSheetTransitionPage(
        key: state.pageKey,
        child: CreateGameScreen(
          initialData: state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : null,
        ),
      ),
    ),

    // Settings sub-routes
    GoRoute(
      path: '/settings/account',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const AccountManagementScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      path: '/settings/privacy',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const PrivacySettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      path: '/settings/notifications',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const NotificationSettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      path: '/settings/theme',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const ThemeSettingsScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      path: '/settings/language',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const LanguageSelectionScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Preferences routes
    GoRoute(
      path: '/preferences/games',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const GamePreferencesScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      path: '/preferences/availability',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const AvailabilityPreferencesScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // Help & Support routes
    GoRoute(
      path: '/help/center',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const HelpCenterScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      path: '/help/contact',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const ContactSupportScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    GoRoute(
      path: '/help/bug-report',
      pageBuilder: (context, state) => SharedAxisTransitionPage(
        key: state.pageKey,
        child: const BugReportScreen(),
        type: SharedAxisType.horizontal,
      ),
    ),

    // About routes
    GoRoute(
      path: '/about/terms',
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const TermsOfServiceScreen(),
      ),
    ),

    GoRoute(
      path: '/about/privacy',
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const PrivacyPolicyScreen(),
      ),
    ),

    GoRoute(
      path: '/about/licenses',
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const LicensesScreen(),
      ),
    ),

    // ── Post Creation ──
    GoRoute(
      path: RoutePaths.socialCreatePost,
      name: RouteNames.socialCreatePost,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const CreatePostScreen(),
        direction: SlideDirection.fromBottom,
      ),
    ),

    // Social Feed route — feed lives in HomeScreen now.
    GoRoute(
      path: RoutePaths.socialFeed,
      name: RouteNames.socialFeed,
      redirect: (context, state) => RoutePaths.home,
    ),

    GoRoute(
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
      path: '${RoutePaths.socialPostDetail}/:postId',
      name: RouteNames.socialPostDetail,
      pageBuilder: (context, state) {
        final postId = state.pathParameters['postId'] ?? '';
        return ScaleTransitionPage(
          key: state.pageKey,
          child: PostDetailScreen(postId: postId),
        );
      },
    ),

    GoRoute(
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
      path: RoutePaths.socialOnboardingWelcome,
      name: RouteNames.socialOnboardingWelcome,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingWelcomeScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      path: RoutePaths.socialOnboardingFriends,
      name: RouteNames.socialOnboardingFriends,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingFriendsScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      path: RoutePaths.socialOnboardingPrivacy,
      name: RouteNames.socialOnboardingPrivacy,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingPrivacyScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      path: RoutePaths.socialOnboardingNotifications,
      name: RouteNames.socialOnboardingNotifications,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingNotificationsScreen(),
        direction: SlideDirection.fromLeft,
      ),
    ),

    GoRoute(
      path: RoutePaths.socialOnboardingComplete,
      name: RouteNames.socialOnboardingComplete,
      pageBuilder: (context, state) => ScaleTransitionPage(
        key: state.pageKey,
        child: const SocialOnboardingCompleteScreen(),
      ),
    ),

    // Social Friends (People) screen — own profile, 3 tabs
    GoRoute(
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
      path: RoutePaths.socialChatList,
      name: RouteNames.socialChatList,
      pageBuilder: (context, state) => FadeThroughTransitionPage(
        key: state.pageKey,
        child: const _PlaceholderScreen(title: 'Chat List'),
      ),
    ),

    GoRoute(
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
      path: RoutePaths.socialEditPost,
      name: RouteNames.socialEditPost,
      pageBuilder: (context, state) => BottomSheetTransitionPage(
        key: state.pageKey,
        child: const _PlaceholderScreen(title: 'Edit Post'),
      ),
    ),

    GoRoute(
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
      path: RoutePaths.adminModerationQueue,
      redirect: (context, state) async {
        try {
          final response = await Supabase.instance.client.rpc('is_admin');
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
      path: RoutePaths.adminSafetyOverview,
      redirect: (context, state) async {
        try {
          final response = await Supabase.instance.client.rpc('is_admin');
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
