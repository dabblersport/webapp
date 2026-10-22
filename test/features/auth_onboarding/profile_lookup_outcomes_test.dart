// KAN-602: a temporary failure after sign-in must not send a returning user
// into new-user onboarding. The profile lookup has three outcomes and the
// password, code (OTP) and email-verification flows are driven through each,
// including SocketException and TimeoutException. A FAKE auth service is
// used: no Supabase, no network, no account. Emails and codes are placeholders.
import 'dart:async';
import 'dart:io';

import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_verification_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/otp_verification_screen.dart';
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

/// How the scripted lookup behaves. The failures go through the REAL
/// classifier, so a thrown socket/timeout error becomes could-not-check the
/// same way it does in the app.
enum _Outcome { found, confirmedNoProfile, socket, timeout, serverError }

Future<ProfileLookupResult> _run(_Outcome o) =>
    AuthService.classifyProfileQuery(() async {
      switch (o) {
        case _Outcome.found:
          return [
            {
              'id': 'p1',
              'onboard': true,
              'display_name': 'Fake Name',
              'intention': 'player',
            },
          ];
        case _Outcome.confirmedNoProfile:
          return <dynamic>[];
        case _Outcome.socket:
          throw const SocketException('Failed host lookup');
        case _Outcome.timeout:
          throw TimeoutException('lookup timed out');
        case _Outcome.serverError:
          throw const PostgrestException(message: 'boom', code: '500');
      }
    });

class _FakeAuth implements AuthService {
  _Outcome outcome = _Outcome.found;
  int lookups = 0;
  int signIns = 0;
  int verifies = 0;
  int creates = 0;
  Object? sendOtpError;
  Object? verifyError;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signIns++;
    return AuthResponse(user: _user());
  }

  @override
  Future<AuthResponse> verifyOtp({
    required String identifier,
    required IdentifierType type,
    required String token,
  }) async {
    verifies++;
    if (verifyError != null) throw verifyError!;
    return AuthResponse();
  }

  @override
  Future<void> sendOtp({
    required String identifier,
    required IdentifierType type,
  }) async {
    if (sendOtpError != null) throw sendOtpError!;
  }

  @override
  Future<ProfileLookupResult> lookupUserProfile({
    List<String>? fields,
    String? personaType,
  }) {
    lookups++;
    return _run(outcome);
  }

  @override
  Future<void> createProfile({
    required String userId,
    required String displayName,
    required String username,
    required int age,
    required String gender,
    required String intention,
    required String preferredSport,
    String? interests,
  }) async {
    creates++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeSimpleAuth extends StateNotifier<SimpleAuthState>
    implements SimpleAuthNotifier {
  _FakeSimpleAuth() : super(const SimpleAuthState());

  @override
  Future<void> handleSuccessfulLogin() async {}

  @override
  Future<void> refreshAuthState() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

User _user() => User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  email: 'person@example.test',
  createdAt: DateTime.utc(2026).toIso8601String(),
);

class _Harness {
  _Harness(this.tester, {this.locale = const Locale('en')});
  final WidgetTester tester;
  final Locale locale;
  final auth = _FakeAuth();
  final visited = <String>[];

  AppLocalizations get l10n => lookupAppLocalizations(locale);

  Future<void> pump(Widget screen) async {
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
      initialLocation: '/screen',
      routes: [
        GoRoute(path: '/screen', builder: (_, _) => screen),
        stub(RoutePaths.welcome),
        stub(RoutePaths.createUserInfo),
        stub(RoutePaths.home),
        stub(RoutePaths.emailInput),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          currentUserIdProvider.overrideWithValue(null),
          simpleAuthProvider.overrideWith((ref) => _FakeSimpleAuth()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => DabblerToastProvider(child: child!),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            locale: locale,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> submitPassword() async {
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'person@example.test');
    await tester.enterText(fields.at(1), 'placeholder-password');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(l10n.auth_login_button));
    await settle();
  }

  /// The code screen runs a 30 s resend countdown on real timers; let it end
  /// so the test does not finish with a timer pending.
  Future<void> drain() async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> submitCode() async {
    await tester.tap(find.text(l10n.auth_otp_continue));
    await settle();
  }
}

const _failures = <_Outcome>[
  _Outcome.socket,
  _Outcome.timeout,
  _Outcome.serverError,
];

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  group('lookup classifier', () {
    test('rows -> found', () async {
      expect(await _run(_Outcome.found), isA<ProfileLookupFound>());
    });
    test('completed query with no rows -> confirmed no profile', () async {
      expect(
        await _run(_Outcome.confirmedNoProfile),
        isA<ProfileLookupConfirmedNoProfile>(),
      );
    });
    for (final o in _failures) {
      test('${o.name} -> could not check, never "no profile"', () async {
        final r = await _run(o);
        expect(r, isA<ProfileLookupCouldNotCheck>());
        expect(r, isNot(isA<ProfileLookupConfirmedNoProfile>()));
      });
    }
  });

  group('password login', () {
    testWidgets('found -> welcome', (tester) async {
      final h = _Harness(tester)..auth.outcome = _Outcome.found;
      await h.pump(const EnterPasswordScreen(email: ''));
      await h.submitPassword();
      expect(h.visited, [RoutePaths.welcome]);
    });

    testWidgets('confirmed no profile -> onboarding', (tester) async {
      final h = _Harness(tester)..auth.outcome = _Outcome.confirmedNoProfile;
      await h.pump(const EnterPasswordScreen(email: ''));
      await h.submitPassword();
      expect(h.visited, [RoutePaths.createUserInfo]);
    });

    for (final o in _failures) {
      testWidgets('${o.name} -> stays, keeps input, retry reaches welcome', (
        tester,
      ) async {
        final h = _Harness(tester)..auth.outcome = o;
        await h.pump(const EnterPasswordScreen(email: ''));
        await h.submitPassword();

        expect(h.visited, isEmpty, reason: 'must not route to onboarding');
        expect(find.text(h.l10n.auth_profile_check_failed), findsOneWidget);
        expect(find.text(h.l10n.auth_profile_check_retry), findsOneWidget);
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.text('person@example.test'), findsOneWidget);
        expect(h.auth.signIns, 1);

        // Retry re-checks the profile only; it does not sign in again.
        h.auth.outcome = _Outcome.found;
        await tester.tap(find.text(h.l10n.auth_profile_check_retry));
        await h.settle();
        expect(h.auth.signIns, 1);
        expect(h.auth.lookups, 2);
        expect(h.visited, [RoutePaths.welcome]);
      });
    }

    testWidgets('Arabic shows the localized message and retry', (tester) async {
      final h = _Harness(tester, locale: const Locale('ar'))
        ..auth.outcome = _Outcome.socket;
      await h.pump(const EnterPasswordScreen(email: ''));
      await h.submitPassword();
      expect(find.text(h.l10n.auth_profile_check_failed), findsOneWidget);
      expect(find.text(h.l10n.auth_profile_check_retry), findsOneWidget);
      expect(h.visited, isEmpty);
    });
  });

  group('code (OTP) verification', () {
    Widget screen() => const OtpVerificationScreen(
      identifier: 'person@example.test',
      initialCode: '123456',
    );

    testWidgets('found -> welcome', (tester) async {
      final h = _Harness(tester)..auth.outcome = _Outcome.found;
      await h.pump(screen());
      await h.submitCode();
      expect(h.visited, [RoutePaths.welcome]);
      await h.drain();
    });

    testWidgets('confirmed no profile -> onboarding', (tester) async {
      final h = _Harness(tester)..auth.outcome = _Outcome.confirmedNoProfile;
      await h.pump(screen());
      await h.submitCode();
      expect(h.visited, [RoutePaths.createUserInfo]);
      await h.drain();
    });

    for (final o in _failures) {
      testWidgets('${o.name} -> stays with retry, code kept', (tester) async {
        final h = _Harness(tester)..auth.outcome = o;
        await h.pump(screen());
        await h.submitCode();

        expect(h.visited, isEmpty, reason: 'must not route to onboarding');
        expect(find.text(h.l10n.auth_profile_check_failed), findsOneWidget);
        expect(find.text(h.l10n.auth_profile_check_retry), findsOneWidget);
        expect(h.auth.verifies, 1);

        h.auth.outcome = _Outcome.found;
        await tester.tap(find.text(h.l10n.auth_profile_check_retry));
        await h.settle();
        expect(h.auth.verifies, 1, reason: 'the code is not re-verified');
        expect(h.visited, [RoutePaths.welcome]);
        await h.drain();
      });
    }

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        'a verify failure shows the generic line (${locale.languageCode})',
        (tester) async {
          final h = _Harness(tester, locale: locale);
          h.auth.verifyError = const SocketException(
            'Failed host lookup 10.0.0.1',
          );
          await h.pump(screen());
          await h.submitCode();
          expect(find.text(h.l10n.auth_otp_generic_error), findsOneWidget);
          expect(find.textContaining('SocketException'), findsNothing);
          expect(find.textContaining('10.0.0.1'), findsNothing);
          expect(h.visited, isEmpty);
          expect(h.auth.lookups, 0);
          await h.drain();
        },
      );
    }

    testWidgets('a resend failure shows no raw exception text', (tester) async {
      final h = _Harness(tester);
      h.auth.sendOtpError = const SocketException(
        'Failed host lookup 10.0.0.1',
      );
      await h.pump(
        const OtpVerificationScreen(identifier: 'person@example.test'),
      );
      // Wait out the 30 s resend countdown, then tap resend.
      await h.drain();
      await tester.tap(find.text(h.l10n.auth_otp_resend));
      await h.settle();
      expect(find.text(h.l10n.auth_otp_resend_failed), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('10.0.0.1'), findsNothing);
    });
  });

  group('email verification profile step', () {
    final data = <String, dynamic>{'displayName': 'Fake Name'};

    test('found -> existing, nothing created', () async {
      final auth = _FakeAuth()..outcome = _Outcome.found;
      final r = await ensureEmailVerifiedProfile(
        authService: auth,
        user: _user(),
        data: data,
      );
      expect(r, EmailVerifyProfileOutcome.existing);
      expect(auth.creates, 0);
    });

    test('confirmed no profile -> created', () async {
      final auth = _FakeAuth()..outcome = _Outcome.confirmedNoProfile;
      final r = await ensureEmailVerifiedProfile(
        authService: auth,
        user: _user(),
        data: data,
      );
      expect(r, EmailVerifyProfileOutcome.created);
      expect(auth.creates, 1);
    });

    for (final o in _failures) {
      test('${o.name} -> could not check, nothing created', () async {
        final auth = _FakeAuth()..outcome = o;
        final r = await ensureEmailVerifiedProfile(
          authService: auth,
          user: _user(),
          data: data,
        );
        expect(r, EmailVerifyProfileOutcome.couldNotCheck);
        expect(auth.creates, 0);
      });
    }
  });
}
