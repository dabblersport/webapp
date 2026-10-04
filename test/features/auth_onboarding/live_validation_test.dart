import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_input_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/reset_password_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/set_username_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// The auth forms validate live (after the first edit) and gate submit on
/// `Form.validate()`, as the pre-migration TextFormField screens did.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The test font (Ahem) is wider than the real faces; a button label that
  // fits in the app overflows here. Layout is covered by the render tests.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(onboardingDataProvider.notifier)
    ..initWithEmail('aisha@example.com')
    ..setIntention('player');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _field(int i) => find.byType(EditableText).at(i);

DabblerButton _button(WidgetTester tester, String label) => tester
    .widget<DabblerButton>(find.widgetWithText(DabblerButton, label).first);

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
  });

  testWidgets('email input: error appears on interaction, submit gated', (
    tester,
  ) async {
    await _pump(tester, const EmailInputScreen());
    expect(find.text('That does not look like an email address.'), findsNothing);
    expect(_button(tester, 'Send me a code').onPressed, isNull);

    await tester.enterText(_field(0), 'abc');
    await tester.pump();
    expect(find.text('That does not look like an email address.'), findsOneWidget);
    expect(_button(tester, 'Send me a code').onPressed, isNull);

    await tester.enterText(_field(0), '');
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);

    await tester.enterText(_field(0), 'a@b.co');
    await tester.pump();
    expect(find.text('That does not look like an email address.'), findsNothing);
    expect(find.text('Email is required'), findsNothing);
    expect(_button(tester, 'Send me a code').onPressed, isNotNull);
  });

  testWidgets('email + password: live errors and gated login', (tester) async {
    await _pump(tester, const EnterPasswordScreen(email: ''));
    expect(_button(tester, 'Log in').onPressed, isNull);

    await tester.enterText(_field(0), 'nope');
    await tester.pump();
    expect(find.text('That does not look like an email address.'), findsOneWidget);
    expect(_button(tester, 'Log in').onPressed, isNull);

    await tester.enterText(_field(0), 'a@b.co');
    await tester.pump();
    expect(find.text('That does not look like an email address.'), findsNothing);
    expect(_button(tester, 'Log in').onPressed, isNotNull);

    await tester.enterText(_field(1), 'x');
    await tester.pump();
    await tester.enterText(_field(1), '');
    await tester.pump();
    expect(find.text('Enter password'), findsOneWidget);

    // Submitting with an empty password is stopped by Form.validate().
    await tester.tap(find.widgetWithText(DabblerButton, 'Log in').first);
    await tester.pump();
    expect(find.text('Enter password'), findsOneWidget);
    expect(_button(tester, 'Log in').loading, isFalse);
  });

  testWidgets('reset password: live min-length and match errors', (
    tester,
  ) async {
    await _pump(tester, const ResetPasswordScreen());
    expect(find.text('Use at least 8 characters'), findsNothing);

    await tester.enterText(_field(0), 'short');
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await tester.enterText(_field(0), 'longenough');
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsNothing);

    await tester.enterText(_field(1), 'different');
    await tester.pump();
    expect(find.text("Passwords don't match"), findsOneWidget);

    await tester.enterText(_field(1), '');
    await tester.pump();
    expect(find.text('Re-enter the password'), findsOneWidget);

    await tester.tap(find.widgetWithText(DabblerButton, 'Update Password'));
    await tester.pump();
    expect(_button(tester, 'Update Password').loading, isFalse);
    expect(find.text('Re-enter the password'), findsOneWidget);
  });

  testWidgets('set username: display name validates live', (tester) async {
    await _pump(tester, const SetUsernameScreen());
    expect(
      find.text('Display name must be at least 2 characters'),
      findsNothing,
    );
    await tester.enterText(_field(0), 'A');
    await tester.pump();
    expect(
      find.text('Display name must be at least 2 characters'),
      findsOneWidget,
    );
    await tester.enterText(_field(0), '');
    await tester.pump();
    expect(find.text('Display name is required'), findsOneWidget);
    await tester.enterText(_field(0), 'Aisha');
    await tester.pump();
    expect(find.text('Display name is required'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}
