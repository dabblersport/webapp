import 'dart:async';
import 'dart:ui';
import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/core/services/theme_service.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/design_system/theme/app_theme.dart';
import 'package:dabbler/services/notifications/push_notification_service_mobile.dart'
    as push_mobile;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'app/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/responsive_app_shell.dart';

// Top-level background message handler for Firebase
// This function must be a top-level function (not in a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  // You can show local notifications, update badge counts, etc.
  // Note: Avoid heavy processing here
  debugPrint('Background message received: ${message.messageId}');
}

// Feature flags for future functionality
class AppFeatures {
  static const bool enableReferralProgram = false; // ✅ Toggle for future use
  static const bool enableDeepLinks =
      enableReferralProgram; // Links to referral feature
}

// Guard to send flags snapshot only once per session
bool _flagsLogged = false;

void _logFlagsOnce() {
  if (_flagsLogged) return;
  _flagsLogged = true;
  AnalyticsService.trackEvent('flags_snapshot', {
    'multiSport': FeatureFlags.multiSport,
    'organiserProfile': FeatureFlags.organiserProfile,
    'playerGameCreation': FeatureFlags.enablePlayerGameCreation,
    'organiserGameCreation': FeatureFlags.enableOrganiserGameCreation,
    'playerGameJoining': FeatureFlags.enablePlayerGameJoining,
    'organiserGameJoining': FeatureFlags.enableOrganiserGameJoining,
    'socialFeed': FeatureFlags.socialFeed,
    'messaging': FeatureFlags.messaging,
    'notifications': FeatureFlags.notifications,
    'squads': FeatureFlags.squads,
    'venuesBooking': FeatureFlags.venuesBooking,
    'payments': FeatureFlags.enablePayments,
    'bookingFlow': FeatureFlags.enableBookingFlow,
    'rewards': FeatureFlags.enableRewards,
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure we surface real errors in the browser console on Flutter web.
  // This is especially important for production builds where exceptions are
  // otherwise hard to inspect (minified stack traces, generic UI errors).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('FlutterError: ${details.exceptionAsString()}');
    // ignore: avoid_print
    print(details.stack);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // ignore: avoid_print
    print('Uncaught platform error: $error');
    // ignore: avoid_print
    print(stack);
    return true;
  };

  // Enable edge-to-edge mode for Android 15+ compatibility (SDK 35+).
  // This ensures the app draws behind system bars and handles insets properly.
  // Note: Do NOT use SystemChrome.setSystemUIOverlayStyle with color properties
  // as that triggers deprecated Window.setStatusBarColor/setNavigationBarColor
  // on Android 15 (SDK 35+). The native enableEdgeToEdge() in MainActivity
  // handles transparent bars via the modern WindowInsetsController API.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Disable inspector features for web debugging
  if (kIsWeb && kDebugMode) {
    debugProfileBuildsEnabled = false;
  }

  await runZonedGuarded(
    () async {
      try {
        await Environment.load();

        // Register background message handler (must be before Firebase.initializeApp)
        if (!kIsWeb) {
          FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler,
          );
        }

        // Initialize theme service before running the app
        // Location service is now initialized on-demand in sports screen
        await ThemeService().init();

        // Preload token-based color schemes and build ThemeData.
        await AppTheme.initialize();

        // Always use the JWT anon key for Supabase initialisation.
        // The publishable-key format (sb_publishable_*) is not a JWT and
        // is incompatible with the current supabase_flutter SDK, causing
        // every authenticated request to fail silently.
        final anonKey = Environment.supabaseAnonKey;

        // Initialize Supabase with deep-link detection enabled for auth flows
        // This is required so that OAuth providers (e.g. Google) can return
        // to the app and have the session detected from the redirect URL.
        await Supabase.initialize(
          url: Environment.supabaseUrl,
          anonKey: anonKey,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            // Must be true for Google sign-in to work correctly (PKCE flow).
            // Referral deep links can still be controlled separately via feature flags.
            detectSessionInUri: true,
            autoRefreshToken: true,
          ),
        );

        // Push notification service — initialize on mobile to set up
        // foreground handling, token refresh, and notification tap listeners.
        // Wire the tap callback BEFORE init so getInitialMessage can use it.
        if (!kIsWeb) {
          push_mobile
              .PushNotificationService
              .instance
              .onNotificationTap = (route) {
            // Delay slightly to ensure router/navigator is mounted on cold start
            Future.delayed(const Duration(milliseconds: 500), () {
              appRouter.push(route);
            });
          };
          // Init push service (Firebase, foreground listener, onMessageOpenedApp, etc.)
          unawaited(push_mobile.PushNotificationService.instance.init());
        }

        // Log the Supabase authorization token (JWT) after initialization and sign-in
        final authService = Supabase.instance.client.auth;
        final session = authService.currentSession;
        final accessToken = session?.accessToken;
        if (accessToken != null) {
          // Use debugPrint for logging in development
        } else {}

        // Log feature flags snapshot once per session
        _logFlagsOnce();

        // Initialize app lifecycle manager
        AppLifecycleManager().init();

        // Proactively refresh session on resume to avoid "JWT expired" loops.
        // This is best-effort; failures will be handled by per-request retry.
        AppLifecycleManager().onResume(() {
          unawaited(AuthService().refreshSession());
        });

        // TODO(post-rebuild): reinitialize realtime post updates when new service is ready

        runApp(const ProviderScope(child: MyApp()));
      } catch (e, st) {
        // Always log bootstrap errors so production web isn't a black box.
        // ignore: avoid_print
        print('App bootstrap failed: $e');
        // ignore: avoid_print
        print(st);

        // In debug, fail fast so configuration issues are visible (instead of
        // crashing later when something accesses Supabase.instance).
        if (kDebugMode) {
          rethrow;
        }

        // In release, still attempt to render the app (best-effort).
        runApp(const ProviderScope(child: MyApp()));
      }
    },
    (Object error, StackTrace stack) {
      // ignore: avoid_print
      print('Uncaught zoned error: $error');
      // ignore: avoid_print
      print(stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Use a single ThemeService instance to avoid recreating listeners on rebuilds
  static final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Dabbler',
          routerConfig: appRouter,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeService.effectiveThemeMode,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return ResponsiveAppShell(maxContentWidth: 500, child: child);
          },
        );
      },
    );
  }
}
