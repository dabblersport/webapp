import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_entry.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_backend.dart';

import '../../../support/render_mode.dart';

Widget _host(GameChatEntryFlags? flags, {required bool allowed}) =>
    ProviderScope(
      overrides: [
        fakeMessagingBackend,
        if (flags != null) gameChatEntryFlagsProvider.overrideWithValue(flags),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: Scaffold(
          body: GameChatEntry(gameId: 'g1', allowed: allowed),
        ),
      ),
    );

void main() {
  test('committed flags are all true (KAN-554 launch)', () {
    expect(FeatureFlags.messaging, isTrue);
    expect(FeatureFlags.enableMessagingGameChat, isTrue);
    expect(FeatureFlags.enableMessagingReporting, isTrue);
  });

  test('visible only with every flag on and the user allowed', () {
    for (final m in [false, true]) {
      for (final g in [false, true]) {
        for (final r in [false, true]) {
          for (final a in [false, true]) {
            expect(
              gameChatEntryVisible((
                messaging: m,
                gameChat: g,
                reporting: r,
              ), allowed: a),
              m && g && r && a,
              reason: 'm=$m g=$g r=$r allowed=$a',
            );
          }
        }
      }
    }
  });

  testWidgets('present with the real flags (all true, KAN-554 launch)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null, allowed: true));
    expect(find.byKey(GameChatEntry.buttonKey), findsOneWidget);
  });

  testWidgets('absent when reporting is off', (tester) async {
    await tester.pumpWidget(
      _host((messaging: true, gameChat: true, reporting: false), allowed: true),
    );
    expect(find.byKey(GameChatEntry.buttonKey), findsNothing);
  });

  testWidgets('absent when the user is not allowed', (tester) async {
    await tester.pumpWidget(
      _host((messaging: true, gameChat: true, reporting: true), allowed: false),
    );
    expect(find.byKey(GameChatEntry.buttonKey), findsNothing);
  });

  testWidgets('present with every flag on and the user allowed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host((messaging: true, gameChat: true, reporting: true), allowed: true),
    );
    expect(find.byKey(GameChatEntry.buttonKey), findsOneWidget);
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).messaging_chat_open),
      findsOneWidget,
    );
  });
}
