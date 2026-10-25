import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/presentation/widgets/location_picker_row.dart';
import 'package:dabbler/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_location_surfaces_support.dart';

/// KAN-616: the search field and its results stay above the on-screen
/// keyboard. The keyboard is simulated by a live `viewInsets.bottom`.
const double _keyboard = 300;
const Size _screen = Size(390, 844);
const double _limit = 844 - _keyboard;

late BuildContext _host;

Area _area(int i) => Area(
  id: 'a$i',
  name: 'Area $i',
  district: i < 6 ? 'District A' : 'District B',
  city: 'Dubai',
  country: 'UAE',
  centerLat: 25.0 + i / 100,
  centerLng: 55.0 + i / 100,
);

final List<Area> _areas = <Area>[for (var i = 0; i < 12; i++) _area(i)];
final DateTime _t = DateTime(2026, 10, 1);

class _FakeActive extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.0,
      lng: 55.0,
      area: _areas.first,
      source: ActiveLocationSource.gps,
    ),
  );

  @override
  Future<void> refresh() async {}

  @override
  void setRadiusOverride(int meters) {}
}

class _FakeSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => <ProfileLocation>[
    ProfileLocation(
      id: 's1',
      profileId: 'p',
      areaId: 'a0',
      label: ProfileLocationLabel.home,
      isPrimary: true,
      createdAt: _t,
      updatedAt: _t,
    ),
  ];

  @override
  Future<void> updatePrimaryRadius(int meters) async {}
}

class _FakeAreaRepo implements AreaRepository {
  @override
  Future<Map<String, List<Area>>> areasByDistrict() async =>
      <String, List<Area>>{
        'District A': _areas.sublist(0, 6),
        'District B': _areas.sublist(6),
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final List<Map<String, dynamic>> _venues = <Map<String, dynamic>>[
  for (var i = 0; i < 12; i++)
    <String, dynamic>{'id': 'v$i', 'name': 'Venue $i', 'city': 'Dubai'},
];

final List<MapboxPlace> _places = <MapboxPlace>[
  for (var i = 0; i < 6; i++)
    MapboxPlace(
      id: 'p$i',
      name: 'Place $i',
      fullAddress: 'Place $i, Dubai',
      lat: 25,
      lng: 55,
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeCatalogOverride,
        fakeCountryOverride,
        activeLocationProvider.overrideWith(_FakeActive.new),
        profileLocationNotifierProvider.overrideWith(_FakeSaved.new),
        areaRepositoryV2Provider.overrideWithValue(_FakeAreaRepo()),
        currentUserIdProvider.overrideWithValue('u1'),
        activeAreasProvider.overrideWith((ref) async => _areas),
        venueSearchProvider.overrideWith((ref, q) async => _venues),
        mapboxGeocodeProvider.overrideWith((ref, q) async => _places),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(
          ThemeData(brightness: brightness),
        ),
        builder: (context, child) => DabblerToastProvider(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: _keyboard)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) {
            _host = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    ),
  );
}

/// The field and the first row sit above the keyboard; scrolling brings the
/// last row above it too.
Future<void> _expectAboveKeyboard(
  WidgetTester tester, {
  required Finder field,
  required Finder rows,
  bool tapField = true,
  Finder? scrollable,
}) async {
  if (tapField) {
    await tester.tap(field);
    await frames(tester, 3);
  }
  expect(
    tester.getRect(field).bottom,
    lessThanOrEqualTo(_limit),
    reason: 'field',
  );
  expect(rows, findsWidgets);
  expect(
    tester.getRect(rows.first).bottom,
    lessThanOrEqualTo(_limit),
    reason: 'first row',
  );
  final Finder last = rows.last;
  for (var i = 0; i < 30; i++) {
    if (tester.getRect(last).bottom <= _limit) break;
    await tester.drag(
      scrollable ?? find.byType(Scrollable).hitTestable().first,
      const Offset(0, -150),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    tester.getRect(last).bottom,
    lessThanOrEqualTo(_limit),
    reason: 'last row',
  );
}

void main() {
  for (final (String name, Locale l, Brightness b) in [
    ('EN light', const Locale('en'), Brightness.light),
    ('AR dark', const Locale('ar'), Brightness.dark),
  ]) {
    testWidgets('HomeLocationPickerSheet above keyboard ($name)', (
      tester,
    ) async {
      await _pump(tester, locale: l, brightness: b);
      HomeLocationPickerSheet.show(_host);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await frames(tester);
      await _expectAboveKeyboard(
        tester,
        field: find.byType(EditableText),
        rows: find.byType(DabblerListRow),
      );
    });

    testWidgets('LocationPickerSheet venue search above keyboard ($name)', (
      tester,
    ) async {
      await _pump(tester, locale: l, brightness: b);
      LocationPickerSheet.show(_host);
      await frames(tester);
      await tester.tap(find.text('Tag a venue'));
      await frames(tester, 3);
      await tester.enterText(find.byType(EditableText), 'ven');
      await tester.pump(const Duration(seconds: 1));
      await frames(tester, 3);
      await _expectAboveKeyboard(
        tester,
        field: find.byType(EditableText),
        rows: find.byType(PickerRow),
      );
    });

    testWidgets('LocationPickerSheet area list above keyboard ($name)', (
      tester,
    ) async {
      await _pump(tester, locale: l, brightness: b);
      LocationPickerSheet.show(_host);
      await frames(tester);
      await tester.tap(find.text('Pick an area'));
      await frames(tester, 3);
      final rows = find.byType(PickerRow);
      expect(rows, findsWidgets);
      expect(tester.getRect(rows.first).bottom, lessThanOrEqualTo(_limit));
    });

    testWidgets('LocationPickerSheet place search above keyboard ($name)', (
      tester,
    ) async {
      await _pump(tester, locale: l, brightness: b);
      LocationPickerSheet.show(_host);
      await frames(tester);
      await tester.tap(find.text('Search a place'));
      await frames(tester, 3);
      await tester.enterText(find.byType(EditableText), 'pla');
      await tester.pump(const Duration(seconds: 1));
      await frames(tester, 3);
      await _expectAboveKeyboard(
        tester,
        field: find.byType(EditableText),
        rows: find.byType(DabblerInputRow),
        tapField: false,
        scrollable: find.byType(ListView).hitTestable().first,
      );
    });
  }

  for (final (String name, Locale l, Brightness b) in [
    ('EN light', const Locale('en'), Brightness.light),
    ('AR dark', const Locale('ar'), Brightness.dark),
  ]) {
    testWidgets('ManualLocationDrawer above keyboard ($name)', (tester) async {
      installGeo();
      await _pump(tester, locale: l, brightness: b);
      showSetLocationDrawer(_host);
      await frames(tester);
      // KAN-640: the search box and the cities appear after a country.
      final uae = find.text(lookupAppLocalizations(l).region_country_UAE);
      await tester.ensureVisible(uae);
      await tester.tap(uae);
      await frames(tester);
      await _expectAboveKeyboard(
        tester,
        field: find.byType(EditableText),
        rows: find.byType(DabblerInputRow),
      );
    });
  }
}
