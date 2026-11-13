// The welcome screen's "Already have an account? Log in" line is ONE
// accessible button named by the whole sentence, and both a semantic tap and
// a real pointer tap on the visible "Log in" span go to /enter-password.
// The auth service is a FAKE: nothing real is called.
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/auth_welcome_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';

class _FakeAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _passwordMarker = 'ENTER-PASSWORD-ROUTE';

Future<void> _pump(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AuthWelcomeScreen()),
      GoRoute(
        path: RoutePaths.enterPassword,
        builder: (_, _) => const Text(_passwordMarker),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuth()),
        currentUserIdProvider.overrideWithValue(null),
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  testWidgets('EN: one button named "Already have an account? Log in"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const Locale('en'));

    final finder = find.bySemanticsLabel(
      RegExp(r'^Already have an account\? Log in$'),
    );
    expect(finder, findsOneWidget);
    // getSemantics returns the merged node the platform exposes; its merged
    // data is what a screen reader and Playwright see.
    expect(
      tester.getSemantics(finder),
      matchesSemantics(
        label: 'Already have an account? Log in',
        identifier: 'auth-welcome-log-in',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        textDirection: TextDirection.ltr,
      ),
    );
    expect(
      tester.getSemantics(finder).getSemanticsData().flagsCollection.isButton,
      isTrue,
    );

    // A semantic activation (what a screen reader / Playwright click does).
    tester.semantics.tap(
      find.semantics.byLabel(RegExp(r'^Already have an account\? Log in$')),
    );
    await _settle(tester);
    expect(find.text(_passwordMarker), findsOneWidget);
    handle.dispose();
  });

  testWidgets('EN: a pointer tap on the visible "Log in" span still works', (
    tester,
  ) async {
    await _pump(tester, const Locale('en'));
    await tester.tapOnText(find.textRange.ofSubstring('Log in'));
    await _settle(tester);
    expect(find.text(_passwordMarker), findsOneWidget);
  });

  testWidgets('AR: the button is named by the localized prefix + action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const Locale('ar'));
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final finder = find.bySemanticsLabel(
      '${l10n.auth_already_have_account} ${l10n.auth_log_in}',
    );
    expect(finder, findsOneWidget);
    expect(
      tester.getSemantics(finder).getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    handle.dispose();
  });
}
