import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/auth_welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_input_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/landing_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/otp_verification_screen.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart'
    show debugAuthCountries;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders the entry screens (landing, welcome back / complete, auth welcome,
/// email, password) under the design-system theme in LTR and RTL and writes
/// PNGs to the Alpha plan folder.
const String _shotsDir = String.fromEnvironment(
  'AUTH_SHOTS_DIR',
  defaultValue: '$kShotsRoot/auth',
);

class _FakeLocation extends StateNotifier<AsyncValue<LocationState>>
    implements SelectedLocationNotifier {
  _FakeLocation()
    : super(AsyncValue.data(LocationState(country: 'United Arab Emirates')));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf',
    'Glory-Regular.ttf',
    'Glory-Medium.ttf',
    'Glory-SemiBold.ttf',
    'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf',
    'meral-sans-regular.ttf',
    'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf',
    'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader =
        FontLoader('packages/iconsax_flutter/FlutterIconsax')
          ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

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

Future<void> _pump(WidgetTester tester, Widget screen, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  // The frames reserve a 50px status bar above the screen.
  tester.view.padding = const FakeViewPadding(top: 50);
  tester.view.viewPadding = const FakeViewPadding(top: 50);
  addTearDown(tester.view.reset);
  const Key key = Key('shot');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedLocationProvider.overrideWith((ref) => _FakeLocation()),
      ],
      child: MaterialApp(
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
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settleImages(tester);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  // The frames are drawn for iOS: the entry screens show the Apple button there.
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  const Set<String> iosShots = <String>{
    'auth-welcome',
    'email',
    'email-invalid',
    'sheet-terms',
    'password',
    'password-filled',
  };

  final Map<String, Widget Function()> screens = <String, Widget Function()>{
    'landing': () => const LandingPage(),
    'welcome-back': () => const WelcomeScreen(
      displayName: 'Marcus',
      personaType: 'player',
      isFirstTime: false,
    ),
    'welcome-complete': () => const WelcomeScreen(
      displayName: 'Marcus',
      personaType: 'organiser',
      isFirstTime: true,
      primarySportKey: 'football',
    ),
    'auth-welcome': () => const AuthWelcomeScreen(),
    'email': () => const EmailInputScreen(),
    'password': () => const EnterPasswordScreen(email: 'marcus@dabbler.ae'),
  };

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    for (final MapEntry<String, Widget Function()> e in screens.entries) {
      testWidgets('renders ${e.key} - $dir', (tester) async {
        await _pump(tester, e.value(), locale);
        expect(tester.takeException(), isNull);
        expect(
          find.byType(DabblerPage).evaluate().isNotEmpty ||
              find.byType(DabblerFlowPage).evaluate().isNotEmpty,
          isTrue,
        );
        await _shoot(tester, const Key('shot'), '${e.key}-$dir');
      }, variant: iosShots.contains(e.key) ? ios : desktop);
    }
  }

  testWidgets('email: continue is disabled until the email is valid', (
    tester,
  ) async {
    await _pump(tester, const EmailInputScreen(), const Locale('en'));
    DabblerButton continueButton() => tester.widget<DabblerButton>(
      find.widgetWithText(DabblerButton, 'Send me a code').first,
    );
    expect(continueButton().onPressed, isNull);
    await tester.enterText(find.byType(EditableText).first, 'a@b.co');
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);
  });

  // States of the frames that need an interaction: a field in error, a code
  // part-way typed, and the sheets the chips and the legal links open.
  final Map<String, (Widget Function(), Future<void> Function(WidgetTester))>
  states = <String, (Widget Function(), Future<void> Function(WidgetTester))>{
    'email-invalid': (
      () => const EmailInputScreen(),
      (t) async {
        await t.enterText(find.byType(EditableText).first, 'marcus@dabbler');
        // The frame shows the field at rest in error, not focused.
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
      },
    ),
    'password-filled': (
      () => const EnterPasswordScreen(email: 'marcus@dabbler.ae'),
      (t) async {
        await t.enterText(find.byType(EditableText).at(1), 'secret');
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
      },
    ),
    'otp': (
      () => const OtpVerificationScreen(
        identifier: 'marcus@dabbler.ae',
        identifierType: IdentifierType.email,
      ),
      (t) async {
        await t.pump();
      },
    ),
    'otp-typed': (
      () => const OtpVerificationScreen(
        identifier: 'marcus@dabbler.ae',
        identifierType: IdentifierType.email,
      ),
      (t) async {
        await t.enterText(find.byType(EditableText).first, '318');
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
      },
    ),
    'otp-invalid': (
      () => const OtpVerificationScreen(
        identifier: 'marcus@dabbler.ae',
        identifierType: IdentifierType.email,
        initialErrorMessage: 'Invalid token',
        initialCode: '000000',
      ),
      (t) async {
        await t.pump();
      },
    ),
    'otp-expired': (
      () => const OtpVerificationScreen(
        identifier: 'marcus@dabbler.ae',
        identifierType: IdentifierType.email,
        initialErrorMessage: 'Token has expired',
        initialCode: '111111',
      ),
      (t) async {
        await t.pump();
      },
    ),
    'sheet-language': (
      () => const AuthWelcomeScreen(),
      (t) async {
        await t.tap(find.text('English'));
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    ),
    'sheet-region': (
      () {
        debugAuthCountries = <Map<String, dynamic>>[
          for (final String n in <String>[
            'United Arab Emirates',
            'Saudi Arabia',
            'Qatar',
            'Kuwait',
            'United Kingdom',
          ])
            <String, dynamic>{'name_en': n, 'name_ar': n},
        ];
        return const AuthWelcomeScreen();
      },
      (t) async {
        await t.tap(find.text('United Arab Emirates'));
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    ),
    'sheet-terms': (
      () => const EmailInputScreen(),
      (t) async {
        final int links = find.byType(DabblerTextLink).evaluate().length;
        await t.tap(find.byType(DabblerTextLink).at(links - 2));
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    ),
  };

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    for (final MapEntry<
          String,
          (Widget Function(), Future<void> Function(WidgetTester))
        >
        e
        in states.entries) {
      testWidgets('renders ${e.key} - $dir', (tester) async {
        await _pump(tester, e.value.$1(), locale);
        await e.value.$2(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        await _shoot(tester, const Key('shot'), '${e.key}-$dir');
        // Let the OTP resend countdown (a Future.delayed chain) finish.
        await tester.pump(const Duration(seconds: 31));
      }, variant: iosShots.contains(e.key) ? ios : desktop);
    }
  }
}
