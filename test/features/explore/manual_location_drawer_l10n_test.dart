import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../location/manual_location_surfaces_support.dart';

/// KAN-528: the manual location drawer's copy comes from the ARB files.
Future<AppLocalizations> _pump(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeCatalogOverride,
        // KAN-587: typed searches go to the map service; none matches here.
        mapboxCountryCityProvider.overrideWith((ref, q) async => const []),
      ],
      child: MaterialApp(
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: const Scaffold(
          body: SingleChildScrollView(child: ManualLocationDrawer()),
        ),
      ),
    ),
  );
  await frames(tester);
  return lookupAppLocalizations(locale);
}

void main() {
  final seen = <String, List<String>>{};

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('drawer copy is localized (${locale.languageCode})', (
      tester,
    ) async {
      installGeo();
      final l = await _pump(tester, locale);
      // Country first: no city and no search box until a country is chosen.
      expect(find.text(l.manual_location_divider), findsOneWidget);
      expect(find.text(l.location_intro_country_title), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.text(l.region_country_UAE));
      await frames(tester);
      expect(find.text(l.manual_location_search_city), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'zzqqxx-nowhere');
      await tester.pump(const Duration(seconds: 1));
      await frames(tester);
      expect(find.text(l.manual_location_empty_title), findsOneWidget);
      expect(find.text(l.manual_location_empty_text), findsOneWidget);

      final values = [
        l.manual_location_divider,
        l.location_intro_country_title,
        l.manual_location_search_city,
        l.manual_location_empty_title,
      ];
      seen[locale.languageCode] = values;
      if (locale.languageCode == 'en') {
        expect(seen['en'], const [
          'or choose from list',
          'Choose your country',
          'Search for a city',
          'No locations found',
        ]);
      } else {
        for (var i = 0; i < values.length; i++) {
          expect(
            values[i],
            isNot(seen['en']![i]),
            reason: 'Arabic copy must differ from English',
          );
        }
      }
    });
  }
}
