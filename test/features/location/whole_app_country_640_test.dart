import 'package:dabbler/features/auth_onboarding/domain/location/service_region.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'manual_location_surfaces_support.dart';

/// KAN-640 R7 (CEO ruling): a country change from the Home or Explore
/// location drawer is the app's country everywhere: the one saved country the
/// Location screen, the early screens and Explore all read.
void main() {
  testWidgets('a country picked in the Home drawer reaches the Location screen '
      'source, Explore and the saved country', (tester) async {
    SharedPreferences.setMockInitialValues({'selected_country': 'Global'});
    installGeo();
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeCatalogOverride,
          currentUserIdProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          builder: (context, child) => DabblerToastProvider(child: child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    final l = lookupAppLocalizations(const Locale('en'));
    for (var i = 0; i < 20 && c.read(selectedCountryProvider).isLoading; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(c.read(selectedCountryProvider).valueOrNull, 'Global');

    // Home: the Set location drawer opens on the country list; pick UAE.
    showSetLocationDrawer(tester.element(find.byType(Scaffold)));
    await frames(tester);
    await tester.tap(find.text(l.region_country_UAE).last);
    await frames(tester, 5);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );

    // The Location screen's selector reads exactly this provider.
    expect(
      normalizeServiceRegion(c.read(selectedCountryProvider).valueOrNull),
      'United Arab Emirates',
    );
    expect(
      c.read(selectedLocationProvider).valueOrNull?.country,
      'United Arab Emirates',
    );
    // The saved country (early screens, next launch) is the same value.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_country'), 'United Arab Emirates');

    // Explore: a fresh drawer opens straight on that country's cities.
    Navigator.of(tester.element(find.byType(Scaffold))).pop();
    await frames(tester, 5);
    showSetLocationDrawer(tester.element(find.byType(Scaffold)));
    await frames(tester);
    expect(find.text('Dubai'), findsOneWidget);
    expect(find.text(l.region_country_Egypt), findsNothing);
  });
}
