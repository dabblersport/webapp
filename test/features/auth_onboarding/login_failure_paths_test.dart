// KAN-570: the login failure paths of the password screen and the Google
// button, driven through the real screens with a FAKE auth service. Nothing
// real is called: no Supabase, no network, no account, no credential. The
// passwords and emails below are placeholders.
import 'package:dabbler/core/models/google_sign_in_failure.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/auth_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_password_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/render_mode.dart';

/// The auth service, scripted. Every member not listed throws if called.
class _FakeAuth implements AuthService {
  Future<AuthResponse> Function(String email, String password)? signIn;
  Future<Map<String, dynamic>?> Function()? profile;
  Future<bool> Function()? google;
  Future<GoogleSignInResult> Function()? googleFlow;
  int signInCalls = 0;
  int googleCalls = 0;
  int profileCalls = 0;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    signInCalls++;
    return signIn!(email, password);
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile({
    List<String>? fields,
    String? personaType,
  }) {
    profileCalls++;
    return profile!();
  }

  @override
  Future<bool> signInWithGoogle() {
    googleCalls++;
    return google!();
  }

  @override
  Future<GoogleSignInResult> handleGoogleSignInFlow() => googleFlow!();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeSimpleAuth extends StateNotifier<SimpleAuthState>
    implements SimpleAuthNotifier {
  _FakeSimpleAuth() : super(const SimpleAuthState());

  Future<void> Function()? onLogin;
  int loginCalls = 0;

  @override
  Future<void> handleSuccessfulLogin() async {
    loginCalls++;
    await onLogin?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

AuthResponse _signedIn() => AuthResponse(
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026).toIso8601String(),
  ),
);

class _Harness {
  _Harness(this.tester) {
    auth = _FakeAuth();
    simple = _FakeSimpleAuth();
  }
  final WidgetTester tester;
  late final _FakeAuth auth;
  late final _FakeSimpleAuth simple;
  final visited = <String>[];

  Future<void> pump(Widget screen, {String path = '/screen'}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    GoRoute stub(String p) => GoRoute(
      path: p,
      builder: (_, _) {
        visited.add(p);
        return SizedBox(key: ValueKey('stub-$p'));
      },
    );
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: path, builder: (_, _) => screen),
        stub(RoutePaths.welcome),
        stub(RoutePaths.createUserInfo),
        stub(RoutePaths.home),
        stub(RoutePaths.setUsername),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          // The welcome screen's region chips read the signed-in account and
          // the stored region (KAN-584); this screen runs without Supabase.
          currentUserIdProvider.overrideWithValue(null),
          simpleAuthProvider.overrideWith((ref) => simple),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => DabblerToastProvider(child: child!),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            locale: const Locale('en'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  AppLocalizations get l10n => lookupAppLocalizations(const Locale('en'));

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// Types the placeholder email and password into the login form and submits.
  Future<void> submitPassword() async {
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'person@example.test');
    await tester.enterText(fields.at(1), 'placeholder-password');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(l10n.auth_login_button));
    await settle();
  }
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  group('password login', () {
    testWidgets('success with a complete profile reaches the welcome screen', (
      tester,
    ) async {
      final h = _Harness(tester);
      h.auth
        ..signIn = ((_, _) async => _signedIn())
        ..profile = (() async => {
          'id': 'p1',
          'onboard': true,
          'display_name': 'Fake Name',
          'intention': 'player',
        });
      await h.pump(const EnterPasswordScreen(email: ''));
      await h.submitPassword();
      expect(h.auth.signInCalls, 1);
      expect(h.simple.loginCalls, 1);
      expect(h.visited, [RoutePaths.welcome]);
    });

    testWidgets('success with no profile reaches onboarding', (tester) async {
      final h = _Harness(tester);
      h.auth
        ..signIn = ((_, _) async => _signedIn())
        ..profile = (() async => null);
      await h.pump(const EnterPasswordScreen(email: ''));
      await h.submitPassword();
      expect(h.visited, [RoutePaths.createUserInfo]);
    });

    testWidgets('success with an unfinished profile goes Home', (tester) async {
      final h = _Harness(tester);
      h.auth
        ..signIn = ((_, _) async => _signedIn())
        ..profile = (() async => {'id': 'p1', 'onboard': false});
      await h.pump(const EnterPasswordScreen(email: ''));
      await h.submitPassword();
      expect(h.visited, [RoutePaths.home]);
    });

    testWidgets(
      'invalid credentials show the password message, not "Login failed"',
      (tester) async {
        final h = _Harness(tester);
        h.auth.signIn = (_, _) async => throw Exception(
          'Sign in failed: AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)',
        );
        await h.pump(const EnterPasswordScreen(email: ''));
        await h.submitPassword();
        expect(find.text(h.l10n.auth_login_password_wrong), findsOneWidget);
        expect(
          find.text(h.l10n.email_password_error_login_failed),
          findsNothing,
        );
        expect(h.simple.loginCalls, 0);
        expect(h.auth.profileCalls, 0);
        expect(h.visited, isEmpty);
      },
    );

    testWidgets(
      'a network/provider failure shows "Login failed" and signs nobody in',
      (tester) async {
        final h = _Harness(tester);
        h.auth.signIn = (_, _) async => throw Exception(
          'Sign in failed: SocketException: Failed host lookup',
        );
        await h.pump(const EnterPasswordScreen(email: ''));
        await h.submitPassword();
        expect(
          find.text(h.l10n.email_password_error_login_failed),
          findsOneWidget,
        );
        expect(find.text(h.l10n.auth_login_password_wrong), findsNothing);
        expect(h.simple.loginCalls, 0);
        expect(h.visited, isEmpty);
        // No provider text, email or password on screen.
        expect(find.textContaining('SocketException'), findsNothing);
        expect(
          find.textContaining('person@example.test'),
          findsOneWidget,
        ); // the typed field only
      },
    );

    testWidgets(
      'a profile failure AFTER a successful sign-in is its own message, not "Login failed"',
      (tester) async {
        final h = _Harness(tester);
        h.auth
          ..signIn = ((_, _) async => _signedIn())
          ..profile = (() async => throw Exception('profiles query failed'));
        await h.pump(const EnterPasswordScreen(email: ''));
        await h.submitPassword();
        expect(h.auth.signInCalls, 1);
        expect(h.auth.profileCalls, 1);
        expect(
          find.text(h.l10n.email_password_error_profile_failed),
          findsOneWidget,
        );
        expect(
          find.text(h.l10n.email_password_error_login_failed),
          findsNothing,
        );
        expect(find.text(h.l10n.auth_login_password_wrong), findsNothing);
        expect(find.textContaining('profiles query failed'), findsNothing);
        expect(h.visited, isEmpty);
      },
    );

    testWidgets(
      'a session bootstrap failure after sign-in is also the profile message',
      (tester) async {
        final h = _Harness(tester);
        h.auth.signIn = (_, _) async => _signedIn();
        h.simple.onLogin = () async => throw StateError('session check failed');
        await h.pump(const EnterPasswordScreen(email: ''));
        await h.submitPassword();
        expect(
          find.text(h.l10n.email_password_error_profile_failed),
          findsOneWidget,
        );
        expect(
          find.text(h.l10n.email_password_error_login_failed),
          findsNothing,
        );
        expect(h.auth.profileCalls, 0);
      },
    );
  });

  group('Google button', () {
    testWidgets(
      'cancelling the Google sheet is silent and the button works again',
      (tester) async {
        final h = _Harness(tester);
        h.auth.google = () async => false;
        await h.pump(const AuthWelcomeScreen());
        await tester.tap(find.text(h.l10n.auth_entry_continue_google));
        await h.settle();
        expect(h.auth.googleCalls, 1);
        expect(h.visited, isEmpty);
        expect(find.textContaining('google:'), findsNothing);
        await tester.tap(find.text(h.l10n.auth_entry_continue_google));
        await h.settle();
        expect(h.auth.googleCalls, 2); // not stuck in a loading state
      },
    );

    testWidgets(
      'a native Android failure shows only the stage and the status code',
      (tester) async {
        final h = _Harness(tester);
        h.auth.google = () async =>
            throw const GoogleSignInFailure(GoogleSignInStage.native, '10');
        await h.pump(const AuthWelcomeScreen());
        await tester.tap(find.text(h.l10n.auth_entry_continue_google));
        await h.settle();
        expect(
          find.text(h.l10n.auth_welcome_google_error('google:native:10')),
          findsOneWidget,
        );
        expect(h.visited, isEmpty);
      },
    );

    testWidgets('a network failure of the exchange shows no provider text', (
      tester,
    ) async {
      final h = _Harness(tester);
      h.auth.google = () async => throw GoogleSignInFailure.from(
        GoogleSignInStage.exchange,
        AuthRetryableFetchException(
          message: 'connection reset by peer 203.0.113.9',
        ),
      );
      await h.pump(const AuthWelcomeScreen());
      await tester.tap(find.text(h.l10n.auth_entry_continue_google));
      await h.settle();
      expect(find.textContaining('google:exchange:'), findsOneWidget);
      expect(find.textContaining('203.0.113.9'), findsNothing);
      expect(find.textContaining('connection reset'), findsNothing);
    });

    testWidgets('success reaches the destination chosen by the sign-in flow', (
      tester,
    ) async {
      final h = _Harness(tester);
      h.auth
        ..google = (() async => true)
        ..googleFlow = (() async => const GoogleSignInResultGoToHome());
      await h.pump(const AuthWelcomeScreen());
      await tester.tap(find.text(h.l10n.auth_entry_continue_google));
      await h.settle();
      expect(h.visited, [RoutePaths.home]);
    });

    testWidgets(
      'a post-auth bootstrap failure after Google sign-in is reported by stage-free text only',
      (tester) async {
        final h = _Harness(tester);
        h.auth
          ..google = (() async => true)
          ..googleFlow = (() async =>
              throw Exception('profile bootstrap failed'));
        await h.pump(const AuthWelcomeScreen());
        await tester.tap(find.text(h.l10n.auth_entry_continue_google));
        await h.settle();
        expect(h.visited, isEmpty);
        // Distinguishable from a provider failure: no google:<stage>:<code> text.
        expect(find.textContaining('google:'), findsNothing);
      },
    );
  });
}
