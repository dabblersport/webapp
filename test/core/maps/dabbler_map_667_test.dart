import 'package:dabbler/core/maps/dabbler_map.dart';
import 'package:dabbler/core/maps/map_config.dart';
import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../support/render_mode.dart';

/// KAN-667: the reusable map. Grant centres on the user, deny opens the
/// existing "Set location" drawer, and the OS is never asked again.

class _Run {
  int locates = 0;
  int drawers = 0;
}

Future<_Run> _pump(
  WidgetTester tester,
  LocationResult result, {
  List<DabblerMapMarker> markers = const <DabblerMapMarker>[],
  ValueChanged<DabblerMapMarker>? onTap,
  MapController? controller,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final run = _Run();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapTileLayerOverrideProvider.overrideWithValue(
          () => const SizedBox.shrink(),
        ),
        mapLocatorProvider.overrideWithValue(() async {
          run.locates++;
          return result;
        }),
        mapSetLocationOpenerProvider.overrideWithValue((_) async {
          run.drawers++;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        home: Scaffold(
          body: DabblerMap(
            markers: markers,
            onMarkerTap: onTap,
            controller: controller,
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return run;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRenderFonts();
  });

  testWidgets('grant: the map centres on the user and shows their marker', (
    tester,
  ) async {
    final controller = MapController();
    final run = await _pump(
      tester,
      LocationSuccess(lat: 24.4539, lng: 54.3773, accuracyMeters: 10),
      controller: controller,
    );
    expect(run.locates, 1);
    expect(run.drawers, 0);
    expect(find.byKey(const ValueKey('map-user-marker')), findsOneWidget);
    expect(controller.camera.center.latitude, closeTo(24.4539, 1e-6));
    expect(controller.camera.center.longitude, closeTo(54.3773, 1e-6));
  });

  testWidgets('deny: the existing Set location drawer opens once, no re-ask', (
    tester,
  ) async {
    final run = await _pump(tester, LocationDenied());
    expect(run.locates, 1);
    expect(run.drawers, 1);
    expect(find.byKey(const ValueKey('map-user-marker')), findsNothing);
    // A rebuild must neither ask the OS again nor reopen the drawer.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(run.locates, 1);
    expect(run.drawers, 1);
  });

  testWidgets('markers are tappable and the OSM attribution shows', (
    tester,
  ) async {
    DabblerMapMarker? tapped;
    const marker = DabblerMapMarker(id: 'g1', point: LatLng(25.2048, 55.2708));
    await _pump(
      tester,
      LocationDenied(),
      markers: const [marker],
      onTap: (m) => tapped = m,
    );
    await tester.tap(find.byKey(const ValueKey('map-marker-g1')));
    expect(tapped?.id, 'g1');
    expect(find.text(AppLocalizationsEn().map_attribution_osm), findsOneWidget);
    expect(
      AppLocalizationsEn().map_attribution_osm,
      '© OpenStreetMap contributors',
    );
  });

  test('tiles are the free keyless OSM provider with the app id (T-100)', () {
    expect(
      kOsmTileUrlTemplate,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
    expect(kMapUserAgentPackageName, 'app.dabbler.pro');
    expect(kOsmTileUrlTemplate.contains('access_token'), isFalse);
  });
}
