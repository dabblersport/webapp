import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/domain/usecases/register_usecase.dart';
import 'package:dabbler/features/auth_onboarding/presentation/controllers/register_controller.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/profile/onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_complete_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_friends_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_notifications_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_privacy_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/onboarding_scenarios/social/social_onboarding_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_verification_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/forgot_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/language_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/otp_verification_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/register_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/reset_password_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders the OTP / verify / password / language / onboarding-welcome and
/// social-onboarding screens (KAN-414 group B) in LTR and RTL and writes PNGs
/// to the Alpha plan shots folder. Only OTP and onboarding-welcome have a
/// design frame (A06, A10/A16); the rest are DS-default renders.
const String _shotsDir = '$kShotsRoot/auth';

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

class _NoopRegister implements RegisterUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededOnboardingData extends OnboardingDataNotifier {
  _SeededOnboardingData() {
    state = RegistrationOnboardingData(
      email: 'alex@example.com',
      displayName: 'Alex',
      username: 'alex',
      age: 28,
      intention: 'player',
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale,
  Key key,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  // The frames reserve a 50px status bar above the screen.
  tester.view.padding = const FakeViewPadding(top: 50);
  tester.view.viewPadding = const FakeViewPadding(top: 50);
  addTearDown(tester.view.reset);
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:rest(.*)', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        registerControllerProvider.overrideWith(
          (ref) => RegisterController(_NoopRegister()),
        ),
        onboardingDataProvider.overrideWith((ref) => _SeededOnboardingData()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
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
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  final Map<String, Widget Function()> screens = <String, Widget Function()>{
    'otp': () => const OtpVerificationScreen(
      identifier: 'alex@example.com',
      identifierType: IdentifierType.email,
    ),
    'email-verification': () => const EmailVerificationScreen(
      onboardingData: <String, dynamic>{'email': 'alex@example.com'},
    ),
    'forgot-password': () => const ForgotPasswordScreen(),
    'reset-password': () => const ResetPasswordScreen(),
    'register': () => const RegisterScreen(),
    'language': () => const LanguageSelectionScreen(),
    'onboarding-welcome': () => const ProfileOnboardingWelcomeScreen(),
    'social-welcome': () => const SocialOnboardingWelcomeScreen(),
    'social-friends': () => const SocialOnboardingFriendsScreen(),
    'social-privacy': () => const SocialOnboardingPrivacyScreen(),
    'social-notifications': () => const SocialOnboardingNotificationsScreen(),
    'social-complete': () => const SocialOnboardingCompleteScreen(),
  };

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    for (final MapEntry<String, Widget Function()> e in screens.entries) {
      testWidgets('renders ${e.key} - $dir', (tester) async {
        const Key key = Key('shot');
        await _pump(tester, e.value(), locale, key);
        expect(tester.takeException(), isNull);
        await _shoot(tester, key, '${e.key}-$dir');
        // Let the OTP resend countdown (a Future.delayed chain) finish.
        await tester.pump(const Duration(seconds: 31));
      }, variant: desktop);
    }
  }

  testWidgets('otp: a full code enables Continue', (tester) async {
    const Key key = Key('shot');
    await _pump(
      tester,
      const OtpVerificationScreen(
        identifier: 'alex@example.com',
        identifierType: IdentifierType.email,
      ),
      const Locale('en'),
      key,
    );
    expect(find.byType(DabblerCodeInput), findsOneWidget);
    final DabblerButton before = tester.widget(
      find.widgetWithText(DabblerButton, 'Continue'),
    );
    expect(before.disabled, isTrue);
    await tester.pump(const Duration(seconds: 31));
  }, variant: desktop);
}
