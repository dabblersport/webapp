import 'package:dabbler/features/games/presentation/widgets/game_create_gate.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// A Create game entry reached directly (a deep link) refuses a persona that
/// may not create, with the generic message, and never builds the form.
Future<void> _pump(WidgetTester tester, PersonaType? persona, Locale locale) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [activePersonaProvider.overrideWithValue(persona)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: const Scaffold(body: GameCreateGate(child: Text('the-form'))),
      ),
    ),
  );
}

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final rtl = locale.languageCode == 'ar';
    final dir = rtl ? 'rtl' : 'ltr';
    final refusal = rtl
        ? 'لا يمكنك إنشاء مباراة الآن. حاول مرة أخرى لاحقًا.'
        : "You can't create a game right now. Try again later.";
    for (final persona in <PersonaType?>[
      PersonaType.socialiser,
      PersonaType.host,
      null,
    ]) {
      testWidgets('refuses ${persona?.name} - $dir', (tester) async {
        await _pump(tester, persona, locale);
        await tester.pump();
        expect(find.text('the-form'), findsNothing);
        expect(find.text(refusal), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    for (final persona in <PersonaType>[
      PersonaType.player,
      PersonaType.organiser,
    ]) {
      testWidgets('opens the form for ${persona.name} - $dir', (tester) async {
        await _pump(tester, persona, locale);
        await tester.pump();
        expect(find.text('the-form'), findsOneWidget);
        expect(find.text(refusal), findsNothing);
      });
    }
  }
}
