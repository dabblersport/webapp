import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
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
      expect(find.text(l.manual_location_divider), findsOneWidget);
      expect(find.text(l.manual_location_search_placeholder), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'zzqqxx-nowhere');
      await frames(tester);
      expect(find.text(l.manual_location_empty_title), findsOneWidget);
      expect(find.text(l.manual_location_empty_text), findsOneWidget);

      seen[locale.languageCode] = [
        l.manual_location_divider,
        l.manual_location_search_placeholder,
        l.manual_location_empty_title,
        l.manual_location_empty_text,
      ];
      if (locale.languageCode == 'en') {
        expect(seen['en'], const [
          'or choose from list',
          'Search locations...',
          'No locations found',
          'Try a different search term',
        ]);
      } else {
        final en = lookupAppLocalizations(const Locale('en'));
        final enValues = [
          en.manual_location_divider,
          en.manual_location_search_placeholder,
          en.manual_location_empty_title,
          en.manual_location_empty_text,
        ];
        for (var i = 0; i < 4; i++) {
          expect(seen['ar']![i], isNot(enValues[i]));
        }
      }
    });
  }
}
