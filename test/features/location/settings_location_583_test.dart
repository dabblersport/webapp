import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/presentation/screens/saved_locations_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// KAN-583 criterion 3: Settings > Location manages this device's location
/// next to the saved places; a device with no city gets the city-first
/// "Set location" prompt and no "Use current location" action.

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

Future<void> _pump(WidgetTester tester, ActiveLocationState state) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(() => _Active(state)),
        profileLocationNotifierProvider.overrideWith(_Saved.new),
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

  testWidgets('a device with a city shows it with both change actions', (
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
    );
    expect(find.text('Dubai Marina'), findsOneWidget);
    expect(find.text(l.location_use_current), findsOneWidget);
    expect(find.text(l.listing_set_location), findsOneWidget);
  });

  testWidgets('no city: only the city-first Set location prompt', (
    tester,
  ) async {
    await _pump(tester, ActiveLocationDenied());
    expect(find.text(l.location_use_current), findsNothing);
    expect(find.text(l.listing_set_location), findsWidgets);
  });
}
