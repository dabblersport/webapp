// KAN-746: the auth welcome screen shows 'Continue with Apple' on every
// platform (iOS, Android, web), not only iOS. The auth service is a FAKE:
// nothing real is called, no Supabase, no network, no account.
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/auth_welcome_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';

/// The auth service, scripted. Every member not listed throws if called.
class _FakeAuth implements AuthService {
  int appleCalls = 0;

  /// false = the user cancelled the Apple sheet.
  @override
  Future<bool> signInWithApple() async {
    appleCalls++;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<_FakeAuth> _pump(WidgetTester tester) async {
  final auth = _FakeAuth();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const AuthWelcomeScreen())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        currentUserIdProvider.overrideWithValue(null),
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
  return auth;
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  final label = lookupAppLocalizations(
    const Locale('en'),
  ).auth_entry_continue_apple;

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets(
      '$platform: the Apple button is shown and calls signInWithApple',
      (tester) async {
        // Reset inside the test body: the framework checks it before tearDown.
        debugDefaultTargetPlatformOverride = platform;
        try {
          final auth = await _pump(tester);

          expect(find.text(label), findsOneWidget);
          expect(
            find.bySemanticsIdentifier('auth-welcome-continue-apple'),
            findsOneWidget,
          );

          await tester.tap(find.text(label));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          expect(auth.appleCalls, 1);
          // A cancelled sheet leaves the button usable and shows no error.
          expect(find.text(label), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
