import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';
import 'manual_location_surfaces_support.dart';

/// KAN-588: on Venues, Change location opened from the header, typing a city
/// name lists a Cities group and the "Use city only" action (the KAN-587 city
/// path), with the areas of that city still listed below it.
const String _shotsDir = String.fromEnvironment(
  'KAN588_SHOTS_DIR',
  defaultValue: '$kShotsRoot/kan588',
);
const Key _shotKey = Key('kan588-shot');

Area _area(String id, String name, String city) => Area(
  id: id,
  name: name,
  district: name,
  city: city,
  country: 'UAE',
  centerLat: 25.08,
  centerLng: 55.14,
);

final Area _barsha = _area('a1', 'Al Barsha', 'Dubai');
final Area _bay = _area('a2', 'Business Bay', 'Dubai');
final Area _corniche = _area('a3', 'Corniche', 'Abu Dhabi');

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
  Future<void> refresh() async {}
}

class _FakeSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const <ProfileLocation>[];
}

class _FakeAreaRepo implements AreaRepository {
  @override
  Future<Map<String, List<Area>>> areasByDistrict() async =>
      <String, List<Area>>{
        'Al Barsha': <Area>[_barsha],
        'Business Bay': <Area>[_bay],
        'Corniche': <Area>[_corniche],
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
];

const List<VenueWithSportModel> _venues = <VenueWithSportModel>[
  VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Zayed Indoor Arena',
    city: 'Dubai',
    isIndoor: true,
    pricePerHour: 100,
  ),
];

Future<void> _pumpVenues(
  WidgetTester tester,
  Locale locale,
  Brightness brightness,
) async {
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
        activeChallengeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        venuesBySportWithFiltersProvider.overrideWith(
          (ref, f) async => _venues,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _shotKey, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            brightness == Brightness.dark
                ? ThemeData.dark()
                : renderThemeBase(),
          ),
          locale: locale,
        ),
        home: const VenuesScreen(),
      ),
    ),
  );
  await frames(tester);
  await settleImages(tester);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_shotKey)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final entry in const [
    (Locale('en'), Brightness.light),
    (Locale('ar'), Brightness.dark),
  ]) {
    final locale = entry.$1;
    final brightness = entry.$2;
    final tag = '${locale.languageCode}-${brightness.name}';
    testWidgets('Venues > Change location: typing "Dubai" shows a Cities '
        'group and a "Use city only" action ($tag)', (tester) async {
      final l = lookupAppLocalizations(locale);
      await _pumpVenues(tester, locale, brightness);

      // Open Change location from the Venues header (the current area label).
      await tester.tap(find.text('Al Barsha').first);
      await frames(tester);
      await tester.enterText(find.byType(EditableText), 'Dubai');
      await frames(tester);

      expect(find.text(l.manual_location_cities_divider), findsOneWidget);
      expect(find.byKey(const Key('home-location-city-Dubai')), findsOneWidget);
      expect(find.text(l.listing_use_city_only), findsOneWidget);
      expect(find.text('Business Bay'), findsWidgets);
      await _shoot(tester, 'venues-city-search-$tag');
    }, variant: desktop);
  }
}
