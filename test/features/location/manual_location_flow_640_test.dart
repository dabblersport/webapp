import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/presentation/set_location_when_denied.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'manual_location_surfaces_support.dart';

/// KAN-640 R4: the manual location flow is country, then city, then area.
/// Renders: `--dart-define=LOCATION_FLOW_DIR=<dir>`.
const String _dir = String.fromEnvironment('LOCATION_FLOW_DIR');

Future<AppLocalizations> _open(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [fakeCatalogOverride],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => RepaintBoundary(
          key: const Key('shot'),
          child: DabblerToastProvider(child: child!),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );
  showSetLocationDrawer(tester.element(find.byType(Scaffold)));
  await frames(tester);
  return lookupAppLocalizations(locale);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_dir.isEmpty) return;
  await tester.runAsync(() async {
    final b =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await frames(tester, 5);
}

ActiveLocationState? _state(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold)),
).read(activeLocationProvider).valueOrNull;

void main() {
  setUpAll(() async {
    if (_dir.isNotEmpty) await loadRenderFonts();
  });

  testWidgets('country first: no city and no search until a country is '
      "chosen, then only that country's cities", (tester) async {
    installGeo();
    final l = await _open(tester, const Locale('en'));

    // Nothing but countries yet.
    expect(find.byType(ManualLocationDrawer), findsOneWidget);
    expect(find.text('Dubai'), findsNothing);
    expect(find.text('Abu Dhabi'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.text(l.region_country_UAE), findsOneWidget);
    expect(find.text(l.region_country_Global), findsNothing);
    await _shoot(tester, 'country-en');

    await _tap(tester, l.region_country_UAE);
    expect(find.text('Dubai'), findsOneWidget);
    expect(find.text('Abu Dhabi'), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    await _shoot(tester, 'city-en');

    // Another country shows its own (here: no) cities, never the UAE's.
    await _tap(tester, l.location_intro_country_change);
    await _tap(tester, l.region_country_Qatar);
    expect(find.text('Dubai'), findsNothing);
    expect(find.text(l.manual_location_empty_title), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('area step: a city alone is not an address; the area completes '
      'it', (tester) async {
    installGeo();
    final l = await _open(tester, const Locale('en'));
    await _tap(tester, l.region_country_UAE);
    await _tap(tester, 'Dubai');

    // The area step: the city is chosen but nothing is saved yet.
    expect(find.text(l.manual_location_change_city), findsOneWidget);
    expect(find.text(l.manual_location_areas_in('Dubai')), findsOneWidget);
    expect(find.text('Downtown Dubai'), findsOneWidget);
    expect(find.text('Dubai Marina'), findsOneWidget);
    expect(find.byType(ManualLocationDrawer), findsOneWidget);
    expect(_state(tester), isNot(isA<ActiveLocationReady>()));
    expect(_state(tester), isNot(isA<ActiveLocationCityOnly>()));
    await _shoot(tester, 'area-en');

    // Change city goes back to the city list.
    await _tap(tester, l.manual_location_change_city);
    expect(find.text('Abu Dhabi'), findsOneWidget);
    await _tap(tester, 'Dubai');

    await _tap(tester, 'Downtown Dubai');
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(ManualLocationDrawer), findsNothing);
    final s = _state(tester);
    expect(s, isA<ActiveLocationReady>());
    final loc = (s as ActiveLocationReady).location;
    expect((loc.area.city, loc.lat, loc.lng), ('Dubai', 25.1972, 55.2744));
  });

  testWidgets('Arabic: the same three steps', (tester) async {
    installGeo();
    final l = await _open(tester, const Locale('ar'));
    expect(find.text('Dubai'), findsNothing);
    expect(find.text('دبي'), findsNothing);
    await _shoot(tester, 'country-ar');

    await _tap(tester, l.region_country_UAE);
    expect(find.text('دبي'), findsOneWidget);
    await _shoot(tester, 'city-ar');

    await _tap(tester, 'دبي');
    expect(find.text(l.manual_location_change_city), findsOneWidget);
    expect(find.text('Downtown Dubai'), findsOneWidget);
    await _shoot(tester, 'area-ar');
    await tester.pump(const Duration(seconds: 6));
  });
}
