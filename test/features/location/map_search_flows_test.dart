import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/presentation/widgets/city_required_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_location_surfaces_support.dart';

/// KAN-587: the Set location drawer and the City step search the map service
/// worldwide; a failed search is an error with Retry, never "no results".
const MapboxPlace _paris = MapboxPlace(
  id: 'fr-paris',
  name: 'Paris',
  fullAddress: 'Paris, France',
  lat: 48.85,
  lng: 2.35,
  country: 'France',
  countryCode: 'FR',
);

const MapboxPlace _ajman = MapboxPlace(
  id: 'ae-ajman',
  name: 'Ajman',
  fullAddress: 'Ajman, United Arab Emirates',
  lat: 25.4,
  lng: 55.45,
  country: 'United Arab Emirates',
  countryCode: 'AE',
);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  Widget body,
  Future<List<MapboxPlace>> Function(String q) cities,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeCatalogOverride,
        fakeCountryOverride,
        mapboxCityProvider.overrideWith((ref, q) => cities(q)),
        mapboxCountryCityProvider.overrideWith((ref, q) => cities(q.query)),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: Scaffold(body: SingleChildScrollView(child: body)),
      ),
    ),
  );
  await frames(tester);
  return lookupAppLocalizations(const Locale('en'));
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.pump(const Duration(seconds: 1));
  await frames(tester);
}

void main() {
  testWidgets('drawer: a city missing from the list is found inside the '
      'chosen country, and still needs an area', (tester) async {
    installGeo();
    final l = await _pump(
      tester,
      const ManualLocationDrawer(),
      (q) async => q.toLowerCase().startsWith('ajm') ? [_ajman] : [],
    );
    await tester.tap(find.text('United Arab Emirates'));
    await frames(tester);
    await _type(tester, 'ajm');
    expect(find.text('Ajman, United Arab Emirates'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await tester.tap(find.text('Ajman, United Arab Emirates'));
    await frames(tester);
    // The city alone is not an address: the area step is next, nothing saved.
    expect(find.text(l.manual_location_change_city), findsOneWidget);
    final s = container.read(activeLocationProvider).valueOrNull;
    expect(s, isNot(isA<ActiveLocationReady>()));
    expect(s, isNot(isA<ActiveLocationCityOnly>()));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('drawer: a failed search shows an error with Retry, and Retry '
      'recovers', (tester) async {
    installGeo();
    var calls = 0;
    final l = await _pump(tester, const ManualLocationDrawer(), (q) async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return [_ajman];
    });
    await tester.tap(find.text('United Arab Emirates'));
    await frames(tester);
    await _type(tester, 'ajm');
    expect(find.text(l.feed_retry), findsOneWidget);
    expect(
      find.text(l.manual_location_empty_title),
      findsNothing,
      reason: 'an error is not "no results"',
    );
    await tester.tap(find.text(l.feed_retry));
    await frames(tester);
    expect(find.text('Ajman, United Arab Emirates'), findsOneWidget);
    expect(find.text(l.feed_retry), findsNothing);
  });

  testWidgets('City step: a failed search shows an error with Retry', (
    tester,
  ) async {
    installGeo();
    var calls = 0;
    final l = await _pump(tester, const CityRequiredSheet(), (q) async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return [_paris];
    });
    await _type(tester, 'par');
    expect(find.text(l.feed_retry), findsOneWidget);
    expect(find.text(l.manual_location_empty_title), findsNothing);
    await tester.tap(find.text(l.feed_retry));
    await frames(tester);
    expect(find.text('Paris, France'), findsOneWidget);
  });
}
