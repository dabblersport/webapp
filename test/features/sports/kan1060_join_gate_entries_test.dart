import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show sportsListProvider;
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/join_gate.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sport_test_harness.dart';

/// KAN-1060: the gate on the join entries outside the sport page (Games and
/// Meetups listings, game detail), which name the sport by id, key or name.
void main() {
  final List<Map<String, dynamic>> catalogue = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': kFootball,
      'name_en': 'Football',
      'sport_key': 'football',
    },
    <String, dynamic>{
      'id': kTennis,
      'name_en': 'Tennis',
      'sport_key': 'tennis',
    },
  ];

  Future<(SportHarness, List<bool>)> pumpGate(
    WidgetTester tester, {
    required MySportCard card,
    String? sportId,
    String? sportKey,
    String? sportName,
  }) async {
    final SportHarness h = SportHarness(following: <String>[kFootball]);
    h.repo.cardResult = Ok<MySportCard, Failure>(card);
    final List<bool> results = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sportOverviewRepositoryProvider.overrideWithValue(h.repo),
          sportFollowRepositoryProvider.overrideWithValue(h.follow),
          profileControllerProvider.overrideWith((ref) => h.profile),
          sportsListProvider.overrideWith((ref) async => catalogue),
        ],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              DabblerToastProvider(child: child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) => Center(
              child: DabblerButton(
                label: 'Join',
                onPressed: () async => results.add(
                  await confirmSportForJoin(
                    context: context,
                    ref: ref,
                    sportId: sportId,
                    sportKey: sportKey,
                    sportName: sportName,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return (h, results);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  for (final (String, String?, String?, String?) entry
      in <(String, String?, String?, String?)>[
        ('Games listing (name only)', null, null, 'Tennis'),
        ('Meetups listing (key)', null, 'tennis', 'Tennis'),
        ('Game detail (id)', kTennis, 'tennis', 'Tennis'),
      ]) {
    testWidgets('${entry.$1}: no card shows the add sheet, then adds', (
      tester,
    ) async {
      final (SportHarness h, List<bool> results) = await pumpGate(
        tester,
        card: MySportCard.none,
        sportId: entry.$2,
        sportKey: entry.$3,
        sportName: entry.$4,
      );
      await tapText(tester, 'Join');
      expect(find.text('Add Tennis to your sports'), findsOneWidget);
      await tapText(tester, 'Add and join');
      expect(h.follow.adds, <String>['me:$kTennis:2']);
      expect(results, <bool>[true]);
    });
  }

  testWidgets('level not set: asks the level, then sets it', (tester) async {
    final (SportHarness h, List<bool> results) = await pumpGate(
      tester,
      card: MySportCard.levelUnset,
      sportName: 'Tennis',
    );
    await tapText(tester, 'Join');
    expect(find.text('Set your Tennis level'), findsOneWidget);
    await tapText(tester, 'Save and join');
    expect(h.follow.levels, <String>['me:$kTennis:2']);
    expect(results, <bool>[true]);
  });

  testWidgets('level set: passes through with no sheet', (tester) async {
    final (SportHarness h, List<bool> results) = await pumpGate(
      tester,
      card: MySportCard.ready,
      sportKey: 'tennis',
    );
    await tapText(tester, 'Join');
    expect(find.byType(SportJoinLevelSheet), findsNothing);
    expect(h.follow.adds, isEmpty);
    expect(results, <bool>[true]);
  });

  testWidgets('an unknown sport lets the join RPC decide', (tester) async {
    final (SportHarness h, List<bool> results) = await pumpGate(
      tester,
      card: MySportCard.none,
      sportName: 'Curling',
    );
    await tapText(tester, 'Join');
    expect(find.byType(SportJoinLevelSheet), findsNothing);
    expect(h.follow.adds, isEmpty);
    expect(results, <bool>[true]);
  });

  test('every join entry runs the gate before its join', () {
    for (final (String, String, String) f in <(String, String, String)>[
      (
        'lib/features/games/presentation/widgets/games_listing_card.dart',
        'confirmSportForJoin(',
        'joinGameWithFeedback(',
      ),
      (
        'lib/features/meetups/presentation/widgets/meetup_listing_card.dart',
        'confirmSportForJoin(',
        'await rsvpWithFeedback(',
      ),
      (
        'lib/features/games/presentation/screens/join_game/game_detail_screen.dart',
        'confirmSportForJoin(',
        'await ctrl.joinGame()',
      ),
      (
        'lib/features/sports/presentation/widgets/sport_cards.dart',
        'confirmSportProfileForJoin(',
        'sportGameJoinerProvider',
      ),
    ]) {
      final String src = File(f.$1).readAsStringSync();
      final int gate = src.indexOf(f.$2);
      expect(gate, greaterThan(-1), reason: f.$1);
      expect(src.indexOf(f.$3, gate), greaterThan(gate), reason: f.$1);
    }
  });
}
