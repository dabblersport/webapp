import 'package:dabbler/features/auth_onboarding/presentation/screens/email_input_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/email_password_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// The email typed on /email_input is carried to /enter-password, and kept when the
/// user goes back to /email_input.
Future<GoRouter> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  final router = GoRouter(
    initialLocation: '/email_input',
    routes: [
      GoRoute(
        path: '/email_input',
        builder: (_, _) => const EmailInputScreen(),
      ),
      GoRoute(
        path: '/enter-password',
        builder: (_, state) {
          final extra = state.extra;
          final email = extra is Map ? extra['email'] as String? : null;
          return EnterPasswordScreen(email: email ?? '');
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

String _fieldText(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).first)
    .controller
    .text;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
  });

  testWidgets('email typed on the email screen shows on the password screen', (
    tester,
  ) async {
    final router = await _pump(tester);
    await tester.enterText(
      find.byType(EditableText).first,
      'aisha@example.com',
    );
    await tester.pump();

    await tester.tap(find.text('Log in'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(EnterPasswordScreen), findsOneWidget);
    expect(_fieldText(tester), 'aisha@example.com');

    // Going back to the email screen keeps it too.
    router.go('/email_input');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(EmailInputScreen), findsOneWidget);
    expect(_fieldText(tester), 'aisha@example.com');
  });

  testWidgets(
    'the password screen falls back to the typed email without extra',
    (tester) async {
      final router = await _pump(tester);
      await tester.enterText(
        find.byType(EditableText).first,
        'lina@example.com',
      );
      await tester.pump();
      router.go('/enter-password'); // no extra: e.g. a plain link to the route
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EnterPasswordScreen), findsOneWidget);
      expect(_fieldText(tester), 'lina@example.com');
    },
  );
}
