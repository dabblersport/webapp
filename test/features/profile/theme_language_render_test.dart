import 'package:dabbler/features/auth_onboarding/presentation/screens/language_selection_screen.dart';
import 'package:dabbler/features/misc/presentation/screens/help_center_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/theme_settings_screen.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import 'settings_render_support.dart';

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadSettingsFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final bool ar = locale.languageCode == 'ar';
    final String dir = ar ? 'rtl' : 'ltr';
    String t(String en, String arabic) => ar ? arabic : en;

    testWidgets('appearance renders the theme segments — $dir', (tester) async {
      await pumpSettings(tester, const ThemeSettingsScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerOptionSegments), findsOneWidget);
      await shootSettings(tester, 'appearance-default-$dir');

      await tester.tap(find.text(t('Dark', 'داكن')));
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      await shootSettings(tester, 'appearance-dark-$dir');
      // restore singleton state
      await tester.tap(find.text(t('System', 'النظام')));
      await settleSettings(tester);
    });

    testWidgets('language & region and its sheets — $dir', (tester) async {
      await pumpSettings(tester, const LanguageSelectionScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(
        find.text(t('Language & region', 'اللغة والمنطقة')),
        findsOneWidget,
      );
      await shootSettings(tester, 'region-default-$dir');

      await tester.tap(
        find.text(t('App and content language', 'لغة التطبيق والمحتوى')),
      );
      await settleSettings(tester);
      expect(tester.takeException(), isNull);
      await shootSettings(tester, 'region-language-sheet-$dir');
    });

    testWidgets('help center renders — $dir', (tester) async {
      await pumpSettings(tester, const HelpCenterScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text('This screen is under development'), findsOneWidget);
      await shootSettings(tester, 'help-center-default-$dir');
    });
  }
}
