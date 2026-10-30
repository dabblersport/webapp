import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/location_intro_screen.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-640 R7 (CEO defect, Jira 14001): the "Where do you play?" country
/// selector is bound to the one app country, so a detected country shows there
/// and is never replaced by the first item of the list (Egypt).
class _Gateway implements LocationPermissionGateway {
  @override
  Future<LocationPermission> check() async => LocationPermission.denied;
  @override
  Future<LocationPermission> request() async => LocationPermission.denied;
  @override
  Future<bool> servicesEnabled() async => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

class _NoRemote implements ServiceRegionRemote {
  @override
  Future<String?> fetch(String userId) async => null;
  @override
  Future<void> save(String userId, String region) async {}
}

Future<void> _open(
  WidgetTester tester, {
  String? userId,
  CountryDetector? detect,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationPermissionGatewayProvider.overrideWithValue(_Gateway()),
        currentUserIdProvider.overrideWithValue(userId),
        selectedLocationProvider.overrideWith(
          (ref) => SelectedLocationNotifier(
            userId: userId,
            remote: _NoRemote(),
            detect: detect,
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        home: LocationIntroScreen(userId: userId, onFinish: () {}),
      ),
    ),
  );
  // Let the async load / detection settle (real timers).
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  testWidgets('first run, detected AE: the selector shows United Arab '
      'Emirates, not Egypt', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _open(tester, detect: () async => 'United Arab Emirates');
    expect(find.text(l.region_country_UAE), findsOneWidget);
    expect(find.text(l.region_country_Egypt), findsNothing);
  });

  testWidgets('detected on the signed-out screens, then signed in: the '
      'selector still shows the detected country', (tester) async {
    SharedPreferences.setMockInitialValues({
      'selected_country': 'United Arab Emirates',
    });
    await _open(tester, userId: 'u1');
    expect(find.text(l.region_country_UAE), findsOneWidget);
    expect(find.text(l.region_country_Egypt), findsNothing);
  });

  testWidgets('no detection: the selector shows Global, never the first '
      'list item', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _open(tester, detect: () async => throw Exception('offline'));
    expect(find.text(l.region_country_Global), findsOneWidget);
    expect(find.text(l.region_country_Egypt), findsNothing);
  });
}
