import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
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
Future<void> _pump(
  WidgetTester tester,
  PersonaType? persona,
  Locale locale, {
  Future<bool> Function()? bootstrap,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        activePersonaProvider.overrideWithValue(persona),
        // The profile bootstrap has finished (no persona came of it).
        initializeProfileDataProvider.overrideWith(
          (ref) => (bootstrap ?? () async => false)(),
        ),
      ],
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

  // KAN-934: a direct load / refresh of /create-game builds no home shell, so
  // the gate itself runs the profile bootstrap while the persona is unknown.
  testWidgets(
    'unknown persona: a spinner while the profile loads, no refusal',
    (tester) async {
      final done = Completer<bool>();
      await _pump(
        tester,
        null,
        const Locale('en'),
        bootstrap: () => done.future,
      );
      await tester.pump();
      expect(find.byType(DabblerSpinner), findsOneWidget);
      expect(find.text('the-form'), findsNothing);
      expect(
        find.text("You can't create a game right now. Try again later."),
        findsNothing,
      );
      done.complete(false);
    },
  );

  testWidgets(
    'direct load: the bootstrap seeds the persona and the form opens',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // The real rule minus the profile read (which needs Supabase).
            activePersonaProvider.overrideWith(
              (ref) => personaTypeOrNull(ref.watch(activeProfileTypeProvider)),
            ),
            initializeProfileDataProvider.overrideWith((ref) async {
              // As the real one: the profile read comes first.
              await Future<void>.delayed(Duration.zero);
              ref.read(activeProfileTypeProvider.notifier).state = 'player';
              return true;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            home: const Scaffold(body: GameCreateGate(child: Text('the-form'))),
          ),
        ),
      );
      expect(find.byType(DabblerSpinner), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('the-form'), findsOneWidget);
    },
  );
}
