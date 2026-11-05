import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-588: searching a city name in Change location lists a city row with a
/// "Use city only" action; choosing it sets the city on its own, with no area.
Area _area(String id, String name, String city, String country) => Area(
  id: id,
  name: name,
  district: 'D',
  city: city,
  country: country,
  centerLat: 25.08,
  centerLng: 55.14,
);

final Area _barsha = _area('a1', 'Al Barsha', 'Dubai', 'UAE');
final Area _bay = _area('a2', 'Business Bay', 'Dubai', 'UAE');
final Area _corniche = _area('a3', 'Corniche', 'Abu Dhabi', 'UAE');

final List<List<String?>> _cityCalls = <List<String?>>[];

class _FakeActive extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.08,
      lng: 55.14,
      area: _barsha,
      source: ActiveLocationSource.manual,
    ),
  );

  @override
  Future<void> useManualCity(
    String city, {
    String? cityId,
    String? country,
    String? countryCode,
    bool clearArea = false,
  }) async {
    _cityCalls.add(<String?>[city, country]);
    state = AsyncData(ActiveLocationCityOnly(city, country: country));
  }

  @override
  Future<void> refresh() async {}

  @override
  void setRadiusOverride(int meters) {}
}

class _FakeSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const <ProfileLocation>[];

  @override
  Future<void> updatePrimaryRadius(int meters) async {}
}

class _FakeAreaRepo implements AreaRepository {
  @override
  Future<Map<String, List<Area>>> areasByDistrict() async =>
      <String, List<Area>>{
        'Dubai': <Area>[_barsha, _bay],
        'Abu Dhabi': <Area>[_corniche],
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _host(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_FakeActive.new),
        profileLocationNotifierProvider.overrideWith(_FakeSaved.new),
        areaRepositoryV2Provider.overrideWithValue(_FakeAreaRepo()),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        builder: (context, child) => DabblerToastProvider(child: child!),
        home: DabblerPage(
          body: Builder(
            builder: (context) => Center(
              child: DabblerButton(
                label: 'open',
                onPressed: () => HomeLocationPickerSheet.show(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('open'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _cityCalls.clear();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('searching "Dubai" lists one Dubai city row with Use city '
        'only (${locale.languageCode})', (tester) async {
      final l = lookupAppLocalizations(locale);
      await _host(tester, locale);
      await tester.enterText(find.byType(EditableText), 'Dubai');
      await _settle(tester);
      expect(find.byKey(const Key('home-location-city-Dubai')), findsOneWidget);
      expect(find.text(l.listing_use_city_only), findsOneWidget);
      expect(find.text('Business Bay'), findsOneWidget);
    });
  }

  testWidgets('Use city only sets the city on its own (no area) and the '
      'listings city becomes Dubai', (tester) async {
    final l = lookupAppLocalizations(const Locale('en'));
    await _host(tester, const Locale('en'));
    await tester.enterText(find.byType(EditableText), 'Dubai');
    await _settle(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text(l.listing_use_city_only));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester);
    expect(_cityCalls.single, <String?>['Dubai', 'UAE']);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DabblerPage)),
    );
    expect(container.read(listingCityProvider)?.name, 'Dubai');
    expect(container.read(listingCityOnlyProvider), isTrue);
  });

  testWidgets('no city rows without a search, so browsing is unchanged', (
    tester,
  ) async {
    await _host(tester, const Locale('en'));
    expect(find.byKey(const Key('home-location-city-Dubai')), findsNothing);
  });
}
