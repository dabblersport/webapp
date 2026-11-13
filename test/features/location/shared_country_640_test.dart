import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'manual_location_surfaces_support.dart';

/// KAN-640 R5: one app country, shared by the early screens, the Location
/// screen's selector and the manual drawer (`selectedCountryProvider`).
class _NoRemote implements ServiceRegionRemote {
  @override
  Future<String?> fetch(String userId) async => null;

  @override
  Future<void> save(String userId, String region) async {}
}

Future<ProviderContainer> _open(WidgetTester tester, String country) async {
  installGeo();
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeCatalogOverride,
        selectedCountryProvider.overrideWith((ref) => FakeCountry(country)),
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
  showSetLocationDrawer(tester.element(find.byType(Scaffold)));
  await frames(tester);
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  test('(a) the country chosen on the signed-out screens carries into the '
      'signed-in account', () async {
    SharedPreferences.setMockInitialValues({'selected_country': 'Qatar'});
    final n = SelectedLocationNotifier(userId: 'u1', remote: _NoRemote());
    for (var i = 0; i < 50 && n.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(n.state.valueOrNull?.country, 'Qatar');
  });

  testWidgets('(b) a real country opens the drawer straight on its cities', (
    tester,
  ) async {
    await _open(tester, 'United Arab Emirates');
    expect(find.text('Dubai'), findsOneWidget);
    expect(find.text('Abu Dhabi'), findsOneWidget);
    expect(find.byType(ManualLocationDrawer), findsOneWidget);
    expect(find.text('Morocco'), findsNothing);
  });

  testWidgets('(c) Global opens the drawer on the country list', (
    tester,
  ) async {
    await _open(tester, 'Global');
    expect(find.text('Dubai'), findsNothing);
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.region_country_UAE), findsOneWidget);
    expect(find.text(l.region_country_Egypt), findsOneWidget);
  });

  testWidgets('(d) a drawer change updates the app country, both ways', (
    tester,
  ) async {
    final c = await _open(tester, 'Global');
    final l = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l.region_country_Qatar).last);
    await frames(tester, 5);
    expect(c.read(selectedCountryProvider).valueOrNull, 'Qatar');

    await tester.tap(find.text(l.location_intro_country_change).last);
    await frames(tester, 5);
    expect(c.read(selectedCountryProvider).valueOrNull, 'Global');
    expect(find.text(l.region_country_UAE), findsOneWidget);

    // The reverse: the top selector changes, the open drawer follows.
    await c
        .read(selectedCountryProvider.notifier)
        .setCountry('United Arab Emirates');
    await frames(tester, 5);
    expect(find.text('Dubai'), findsOneWidget);
  });
}
