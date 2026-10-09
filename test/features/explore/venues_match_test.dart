import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/home/presentation/widgets/section_themed.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/domain/venue_listing_filters.dart';
import 'package:dabbler/features/venues/presentation/providers/nearby_venues_provider.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/geometry_dump.dart';
import '../../support/render_mode.dart';

/// Venues listing match (Listings.dc.html:750-810, filters :1832-1839): the
/// card's cover placeholder, aggregate rating, badges, distance chip, all
/// sports and keyed facilities; the venue filters, sorts and the empty state.
/// Rendered LTR/RTL, with and without filters, into
/// `venues-match/app/<mode>/`.
const String _shotsDir = String.fromEnvironment(
  'VENUES_MATCH_DIR',
  defaultValue: '$kShotsRoot/venues-match/app',
);
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

/// Dubai Marina; venues are placed relative to it for the haversine chip.
const double _lat = 25.0805;
const double _lng = 55.1403;

class _Location extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: _lat,
      lng: _lng,
      area: Area(
        id: 'a1',
        name: 'Dubai Marina',
        district: 'Marina',
        city: 'Dubai',
        country: 'AE',
        centerLat: _lat,
        centerLng: _lng,
      ),
      source: ActiveLocationSource.manual,
    ),
  );
}

/// No ready active location (KAN-446): the listing has nothing to measure from.
class _NoLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf',
    'Glory-Regular.ttf',
    'Glory-Medium.ttf',
    'Glory-SemiBold.ttf',
    'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf',
    'meral-sans-regular.ttf',
    'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf',
    'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader = FontLoader(
      'packages/iconsax_flutter/FlutterIconsax',
    )..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  dumpGeometry(tester, name);
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
  Sport(id: 's2', nameEn: 'Padel', nameAr: 'بادل', sportKey: 'padel'),
];

const Map<String, VenueAmenityLabel> _catalog = {
  'parking': (en: 'Parking Available', ar: 'مواقف سيارات'),
  'showers': (en: 'Showers', ar: 'مرشات'),
  'cafeteria': (en: 'Cafeteria', ar: 'كافتيريا'),
  'lighting': (en: 'Flood Lighting', ar: 'إضاءة'),
  'wifi': (en: 'Wi-Fi', ar: 'واي فاي'),
};

const List<VenueWithSportModel> _venues = <VenueWithSportModel>[
  VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Elite Football Arena',
    nameAr: 'ساحة النخبة لكرة القدم',
    city: 'Dubai',
    area: 'Dubai Silicon Oasis',
    isIndoor: false,
    pricePerHour: 120,
    latitude: 25.1205,
    longitude: 55.3803,
    amenities: ['parking', 'showers', 'cafeteria', 'lighting', 'wifi'],
    rating: 4.8,
    ratingCount: 126,
    isVerified: true,
    isOpenNow: true,
    sports: ['Football', 'Padel', 'Basketball'],
    sportsAr: ['كرة القدم', 'بادل', 'كرة السلة'],
  ),
  VenueWithSportModel(
    id: 'v2',
    sportId: 's1',
    nameEn: 'Zayed Indoor Arena',
    city: 'Dubai',
    area: 'Al Quoz',
    isIndoor: true,
    pricePerHour: 80,
    latitude: 25.1405,
    longitude: 55.2403,
    amenities: ['parking'],
    rating: 4.1,
    ratingCount: 18,
    sports: ['Football'],
    sportsAr: ['كرة القدم'],
  ),
  VenueWithSportModel(
    id: 'v3',
    sportId: 's1',
    nameEn: 'Al Quoz Courts',
    city: 'Dubai',
    area: 'Al Quoz',
    sports: ['Football'],
    sportsAr: ['كرة القدم'],
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Locale locale, {
  required bool filters,
  List<VenueWithSportModel> venues = _venues,
  bool locationReady = true,
  List<NearbyVenueModel>? nearby,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(
          locationReady ? _Location.new : _NoLocation.new,
        ),
        if (nearby != null) ...[
          nearbyVenuesFilterEnabledProvider.overrideWith((ref) => true),
          nearbyVenuesProvider.overrideWith((ref, p) async => nearby),
        ],
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        venueAmenityCatalogProvider.overrideWith((ref) async => _catalog),
        venuesBySportWithFiltersProvider.overrideWith((ref, f) async => venues),
        if (filters) ...[
          venueIndoorFilterProvider.overrideWith((ref) => false),
          venueMaxPriceFilterProvider.overrideWith((ref) => 150),
          venueMinRatingFilterProvider.overrideWith((ref) => 4.5),
          nearbyVenueSortProvider.overrideWith((ref) => VenueSortOrder.rating),
        ],
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: const Key('shot'), child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: SectionThemed(
          theme: DabblerTheme.main,
          child: const DabblerPage(body: VenuesScreen()),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settleImages(tester);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  final String mode = _dark ? 'dark' : 'light';

  group('venue listing helpers', () {
    test('haversine: Marina to Silicon Oasis is about 24.6 km', () {
      final m = haversineMeters(_lat, _lng, 25.1205, 55.3803);
      expect(m, inInclusiveRange(24000, 25000));
      expect(haversineMeters(_lat, _lng, _lat, _lng), 0);
    });

    test('radius steps walk up and stop at the largest', () {
      expect(nextVenueRadius(5000), 10000);
      expect(nextVenueRadius(10000), 20000);
      expect(nextVenueRadius(50000), isNull);
    });

    test('sort values match the RPC', () {
      expect(VenueSortOrder.values.map((e) => e.rpcValue), [
        'distance',
        'rating',
        'price',
      ]);
    });

    test('NearbyVenueModel reads the new RPC columns', () {
      final v = NearbyVenueModel.fromJson({
        'id': 'x',
        'name_en': 'X',
        'distance_meters': 1500,
        'cover_url': 'https://e/x.jpg',
        'rating': 4.6,
        'rating_count': 12,
        'is_verified': true,
        'is_open_now': true,
        'amenities': ['parking'],
        'sports': ['Padel'],
        'sports_ar': ['بادل'],
      });
      expect(v.coverUrl, 'https://e/x.jpg');
      expect(v.rating, 4.6);
      expect(v.ratingCount, 12);
      expect(v.isVerified && v.isOpenNow, isTrue);
      expect(v.amenities, ['parking']);
      expect(v.sportsAr, ['بادل']);
      expect(v.distanceLabel, '1.5 km');
    });

    test('VenueWithSportModel reads the new view columns', () {
      final v = VenueWithSportModel.fromJson({
        'id': 'x',
        'sport_id': 's',
        'name_en': 'X',
        'city': 'Dubai',
        'rating': 4.2,
        'rating_count': 3,
        'is_verified': true,
        'is_open_now': false,
        'sports': ['Gym'],
        'amenities': ['wifi'],
      });
      expect(v.rating, 4.2);
      expect(v.ratingCount, 3);
      expect(v.isVerified, isTrue);
      expect(v.sports, ['Gym']);
    });
  });

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    final bool ar = dir == 'rtl';
    for (final bool filters in <bool>[false, true]) {
      final String fs = filters ? 'filters' : 'plain';
      testWidgets('venues $mode $dir $fs', (tester) async {
        await _pump(tester, locale, filters: filters);
        expect(tester.takeException(), isNull);
        // Cover slot always draws, with the gallery glyph (no photos here).
        expect(find.byType(DabblerImage), findsWidgets);
        // Rating, badges, distance chip, all sports, keyed facilities.
        expect(find.text(ar ? '4.8' : '4.8'), findsOneWidget);
        expect(find.text(ar ? '(126 تقييم)' : '(126)'), findsOneWidget);
        expect(find.text(ar ? 'الأعلى تقييمًا' : 'Top rated'), findsOneWidget);
        expect(find.text(ar ? 'موثّق' : 'Verified'), findsOneWidget);
        expect(find.text(ar ? 'مفتوح الآن' : 'Open now'), findsOneWidget);
        expect(find.textContaining('Instant'), findsNothing);
        expect(
          find.text(ar ? 'ساحة النخبة لكرة القدم' : 'Elite Football Arena'),
          findsOneWidget,
        );
        expect(find.text(ar ? 'بادل' : 'Padel'), findsWidgets);
        expect(find.text(ar ? 'كرة السلة' : 'Basketball'), findsOneWidget);
        expect(
          find.text(ar ? 'مواقف سيارات' : 'Parking Available'),
          findsWidgets,
        );
        // The Indoor/Outdoor card tag stays.
        expect(find.text(ar ? 'خارجي' : 'Outdoor'), findsWidgets);
        // Distance chip on every venue that has coordinates (two of three).
        expect(find.textContaining(ar ? 'على بعد' : 'away'), findsNWidgets(2));
        if (filters) {
          expect(
            find.text(ar ? 'حتى 150 د.إ' : 'Up to AED 150'),
            findsOneWidget,
          );
          expect(find.text(ar ? '4.5 فأكثر' : '4.5 and up'), findsOneWidget);
        }
        await _shoot(tester, const Key('shot'), 'venues-$dir-$fs');
      }, variant: desktop);
    }

    testWidgets('venues $mode $dir empty state', (tester) async {
      await _pump(tester, locale, filters: true, venues: const []);
      expect(tester.takeException(), isNull);
      expect(
        find.text(ar ? 'وسّع نطاق البحث' : 'Expand search area'),
        findsOneWidget,
      );
      expect(find.textContaining('Instant'), findsNothing);
      await _shoot(tester, const Key('shot'), 'venues-$dir-empty');
    }, variant: desktop);
  }

  testWidgets('filter sheet lists the five venue groups', (tester) async {
    await _pump(tester, const Locale('en'), filters: false);
    await tester.tap(find.bySemanticsLabel('Filters'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final label in [
      'Distance',
      'Indoor / outdoor',
      'Price per hour',
      'Rating',
      'Sort by',
      'Up to AED 80',
      'Up to AED 150',
      'Any price',
      '4.0 and up',
      '4.5 and up',
      'Lowest price',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Starting soonest'), findsNothing);
    await _shoot(tester, const Key('shot'), 'venues-ltr-filter-sheet');
  }, variant: desktop);

  testWidgets('filter rail carries Clear all after the applied pills', (
    tester,
  ) async {
    await _pump(tester, const Locale('en'), filters: true);
    // Four applied pills overflow the rail, so Clear all is the last item,
    // reached by scrolling the rail (as on the Games listing).
    expect(find.byKey(DabblerFilterRail.clearAllKey), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
  }, variant: desktop);
  // KAN-446: the distance tag never hides; without a distance it says so.
  group('distance unavailable', () {
    // Both venues carry coordinates: only the missing location hides them.
    final List<VenueWithSportModel> withCoords = _venues.sublist(0, 2);
    const VenueWithSportModel noLat = VenueWithSportModel(
      id: 'n1',
      sportId: 's1',
      nameEn: 'No Lat Venue',
      city: 'Dubai',
      longitude: 55.2,
    );
    const VenueWithSportModel noLng = VenueWithSportModel(
      id: 'n2',
      sportId: 's1',
      nameEn: 'No Lng Venue',
      city: 'Dubai',
      latitude: 25.1,
    );
    const VenueWithSportModel origin = VenueWithSportModel(
      id: 'n3',
      sportId: 's1',
      nameEn: 'Same Spot Venue',
      city: 'Dubai',
      latitude: _lat,
      longitude: _lng,
    );
    const VenueWithSportModel nullIsland = VenueWithSportModel(
      id: 'n4',
      sportId: 's1',
      nameEn: 'Zero Coords Venue',
      city: 'Dubai',
      latitude: 0.0,
      longitude: 0.0,
    );
    NearbyVenueModel near(
      String id, {
      double? lat,
      double? lng,
      double metres = 0,
    }) => NearbyVenueModel(
      id: id,
      nameEn: 'Nearby $id',
      city: 'Dubai',
      latitude: lat,
      longitude: lng,
      distanceMeters: metres,
    );

    for (final (String code, String unavailable, String away)
        in <(String, String, String)>[
          ('en', 'Distance unavailable', 'away'),
          ('ar', 'المسافة غير متاحة', 'على بعد'),
        ]) {
      final Locale locale = Locale(code);

      testWidgets('$code: no ready location, normal list', (tester) async {
        await _pump(
          tester,
          locale,
          filters: false,
          locationReady: false,
          venues: withCoords,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(unavailable), findsNWidgets(withCoords.length));
        expect(find.textContaining(away), findsNothing);
      }, variant: desktop);

      testWidgets('$code: no ready location, nearby falls back', (
        tester,
      ) async {
        await _pump(
          tester,
          locale,
          filters: false,
          locationReady: false,
          venues: withCoords,
          nearby: [near('x', lat: _lat, lng: _lng, metres: 900)],
        );
        expect(tester.takeException(), isNull);
        // The fallback renders the normal list, every card unavailable.
        expect(find.text('Nearby x'), findsNothing);
        expect(find.text(unavailable), findsNWidgets(withCoords.length));
        expect(find.textContaining(away), findsNothing);
      }, variant: desktop);

      testWidgets('$code: missing latitude / longitude, normal list', (
        tester,
      ) async {
        await _pump(
          tester,
          locale,
          filters: false,
          venues: const [noLat, noLng],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(unavailable), findsNWidgets(2));
        expect(find.textContaining(away), findsNothing);
      }, variant: desktop);

      testWidgets('$code: missing latitude / longitude, nearby list', (
        tester,
      ) async {
        await _pump(
          tester,
          locale,
          filters: false,
          nearby: [
            near('a', lng: _lng, metres: 900),
            near('b', lat: _lat, metres: 900),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(unavailable), findsNWidgets(2));
        expect(find.textContaining(away), findsNothing);
      }, variant: desktop);

      testWidgets('$code: available distance stays numeric, zeros included', (
        tester,
      ) async {
        await _pump(
          tester,
          locale,
          filters: false,
          venues: const [origin, nullIsland],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(unavailable), findsNothing);
        expect(find.textContaining(away), findsNWidgets(2));
        expect(find.textContaining('0 m'), findsOneWidget);
      }, variant: desktop);

      testWidgets('$code: nearby available distance unchanged', (tester) async {
        await _pump(
          tester,
          locale,
          filters: false,
          nearby: [
            near('c', lat: _lat, lng: _lng, metres: 1500),
            near('d', lat: 0.0, lng: 0.0),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(unavailable), findsNothing);
        final AppLocalizations l = lookupAppLocalizations(locale);
        expect(find.text(l.listing_km_away('1.5 km')), findsOneWidget);
        expect(find.text(l.listing_km_away('0 m')), findsOneWidget);
      }, variant: desktop);
    }
  });
}
