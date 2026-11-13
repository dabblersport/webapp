import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/presentation/screens/saved_locations_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/l10n/app_localizations_ar.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-589 rework (Codex QA): Settings > Location carries the privacy copy that
/// Location.dc.html L27/L30 specifies: "Only you see this page" under the page
/// title, and the "Saved places · Private" header with "Only you see these".
/// Both render in the empty state and with saved places, in English and Arabic.

const Area _marina = Area(
  id: 'a1',
  name: 'Dubai Marina',
  district: 'JLT & Marina',
  city: 'Dubai',
  country: 'UAE',
  centerLat: 25.08,
  centerLng: 55.14,
);

final DateTime _t = DateTime(2026, 10, 1);

class _FakeActive extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: 25.08,
      lng: 55.14,
      area: _marina,
      source: ActiveLocationSource.gps,
    ),
  );

  @override
  Future<void> refresh() async {}
}

class _FakeSaved extends ProfileLocationNotifier {
  _FakeSaved(this._places);
  final List<ProfileLocation> _places;

  @override
  Future<List<ProfileLocation>> build() async => _places;
}

Future<void> _pump(
  WidgetTester tester,
  List<ProfileLocation> places,
  Locale locale,
) async {
  tester.view.physicalSize = const Size(393, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(_FakeActive.new),
        profileLocationNotifierProvider.overrideWith(() => _FakeSaved(places)),
        areaNameProvider.overrideWith((ref, id) async => 'Dubai Marina'),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
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
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final List<ProfileLocation> saved = <ProfileLocation>[
    ProfileLocation(
      id: 's1',
      profileId: 'p',
      areaId: 'a1',
      label: ProfileLocationLabel.home,
      isPrimary: true,
      createdAt: _t,
      updatedAt: _t,
    ),
  ];

  final cases = <String, (Locale, AppLocalizations)>{
    'en': (const Locale('en'), AppLocalizationsEn()),
    'ar': (const Locale('ar'), AppLocalizationsAr()),
  };

  for (final entry in cases.entries) {
    final Locale locale = entry.value.$1;
    final AppLocalizations l10n = entry.value.$2;

    for (final withPlaces in <bool>[false, true]) {
      final String state = withPlaces ? 'with saved places' : 'empty state';
      testWidgets('privacy copy renders in the $state (${entry.key})', (
        tester,
      ) async {
        await _pump(
          tester,
          withPlaces ? saved : const <ProfileLocation>[],
          locale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.location_page_private), findsOneWidget);
        expect(find.text(l10n.location_saved_places_header), findsOneWidget);
        expect(find.text(l10n.location_saved_places_note), findsOneWidget);
      });
    }
  }

  test('the privacy strings are the design copy', () {
    final en = AppLocalizationsEn();
    expect(en.location_page_private, contains('Only you see this page'));
    expect(en.location_saved_places_header, 'Saved places · Private');
    expect(en.location_saved_places_note, startsWith('Only you see these.'));
  });
}
