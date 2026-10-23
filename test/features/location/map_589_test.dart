import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/presentation/screens/saved_locations_screen.dart';
import 'package:dabbler/features/location/presentation/widgets/location_map_preview.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../support/render_mode.dart';

/// KAN-589 (CEO defect, 2026-10-23): Settings > Location always shows a map.
/// Default centre with no location, a pin on the active location, and a
/// "Map unavailable" state (never nothing) when there is no Mapbox token.

const Area _marina = Area(
  id: 'a1',
  name: 'Dubai Marina',
  district: 'JLT & Marina',
  city: 'Dubai',
  country: 'UAE',
  centerLat: 25.08,
  centerLng: 55.14,
);

class _Active extends ActiveLocationNotifier {
  _Active(this.value);
  final ActiveLocationState value;
  @override
  Future<ActiveLocationState> build() async => value;
}

class _Saved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const <ProfileLocation>[];
}

Future<void> _pump(
  WidgetTester tester,
  ActiveLocationState state, {
  required String token,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(() => _Active(state)),
        profileLocationNotifierProvider.overrideWith(_Saved.new),
        mapTokenProvider.overrideWithValue(token),
        mapTileLayerBuilderProvider.overrideWithValue(
          () => const SizedBox.shrink(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        home: const SavedLocationsScreen(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final l = AppLocalizationsEn();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRenderFonts();
  });

  testWidgets(
    'no saved location: the map shows at the default centre, no pin',
    (tester) async {
      await _pump(tester, ActiveLocationDenied(), token: 'pk.test');
      expect(find.byType(FlutterMap), findsOneWidget);
      final FlutterMap map = tester.widget(find.byType(FlutterMap));
      expect(map.options.initialCenter, kDefaultMapCentre);
      expect(find.byType(MarkerLayer), findsNothing);
      expect(find.text(l.location_map_unavailable), findsNothing);
    },
  );

  testWidgets('a location is active: the map centres on it with a pin', (
    tester,
  ) async {
    await _pump(
      tester,
      ActiveLocationReady(
        const ActiveLocation(
          lat: 25.08,
          lng: 55.14,
          area: _marina,
          source: ActiveLocationSource.manual,
        ),
      ),
      token: 'pk.test',
    );
    final FlutterMap map = tester.widget(find.byType(FlutterMap));
    expect(map.options.initialCenter, const LatLng(25.08, 55.14));
    expect(find.byType(MarkerLayer), findsOneWidget);
  });

  testWidgets('empty token: "Map unavailable" instead of a blank area', (
    tester,
  ) async {
    await _pump(tester, ActiveLocationDenied(), token: '');
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Map unavailable'), findsOneWidget);
    expect(find.text(l.location_map_unavailable), findsOneWidget);
  });
}
