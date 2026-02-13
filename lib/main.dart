import 'dart:async';
import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/core/services/theme_service.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/social/services/realtime_likes_service.dart';
import 'package:dabbler/design_system/theme/app_theme.dart';
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

    // Push notification service is now initialized on-demand in home screen
    // On web, this will be a no-op to avoid Firebase Messaging web compatibility issues

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

    // Initialize realtime likes service for social features (non-blocking).
    // Don't await websocket handshakes — they can timeout on flaky networks
    // and would delay app launch. The service handles retries internally.
    if (FeatureFlags.socialFeed) {
      unawaited(RealtimeLikesService().initialize());
    }

    runApp(const ProviderScope(child: MyApp()));
  } catch (e) {
    // Log minimal error information without excessive debug output
    // ignore: avoid_print
    // ...existing code...
    // Still try to run the app even if there's an error
    runApp(const ProviderScope(child: MyApp()));
  }
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
