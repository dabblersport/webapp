import 'package:dabbler/features/profile/presentation/screens/preferences/game_preferences_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_render_support.dart';

/// Game preferences: default, custom (flexible duration/team size) and the
/// save toast, LTR and RTL. No design frame: Settings inner-page pattern.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settleProfile(tester);
}

void main() {
  setUpAll(loadProfileFonts);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final AppLocalizations l10n = lookupAppLocalizations(locale);

    testWidgets('game preferences default — $dir', (tester) async {
      await pumpProfileScreen(
        tester,
        const GamePreferencesScreen(),
        locale,
        height: 2600,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.game_prefs_title), findsOneWidget);
      expect(find.byType(DabblerCheckbox), findsNWidgets(6));
      expect(find.byType(DabblerRadio), findsNWidgets(8));
      expect(find.byType(DabblerChip), findsNWidgets(6));
      expect(find.byType(DabblerSlider), findsNothing);
      await shootProfile(tester, kShotKey, 'game-preferences-default-$dir');
    });

    testWidgets('game preferences custom — $dir', (tester) async {
      await pumpProfileScreen(
        tester,
        const GamePreferencesScreen(),
        locale,
        height: 2800,
      );
      await _tap(tester, find.text(l10n.game_prefs_duration_flexible));
      await _tap(tester, find.text(l10n.game_prefs_team_flexible));
      await _tap(tester, find.text(l10n.game_prefs_type_leagues));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.game_prefs_duration_custom), findsOneWidget);
      expect(find.text(l10n.game_prefs_duration_min), findsOneWidget);
      expect(find.byType(DabblerSlider), findsOneWidget);
      await shootProfile(tester, kShotKey, 'game-preferences-custom-$dir');
    });

    testWidgets('game preferences save toast — $dir', (tester) async {
      await pumpProfileScreen(tester, const GamePreferencesScreen(), locale);
      await tester.tap(find.bySemanticsLabel(l10n.game_prefs_save));
      await settleProfile(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.game_prefs_saved), findsOneWidget);
      await shootProfile(tester, kShotKey, 'game-preferences-saved-$dir');
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
