import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/contributor_games_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_render_support.dart';

GameCountRow _row(String id) => GameCountRow(
  id: id,
  title: 'Game $id',
  startAt: DateTime.now().add(const Duration(days: 1)),
  isCancelled: false,
);

Future<void> _pump(WidgetTester tester, Widget child) => pumpProfileScreen(
  tester,
  Scaffold(body: SingleChildScrollView(child: child)),
  const Locale('en'),
);

void main() {
  setUpAll(loadProfileFonts);

  testWidgets('Create game and game rows call their contracts', (tester) async {
    int create = 0;
    final List<String> opened = <String>[];
    await _pump(
      tester,
      ContributorGamesSections(
        counts: GameCounts(
          played: 1,
          organised: 1,
          upcoming: 1,
          upcomingGames: <GameCountRow>[_row('u1')],
          organisedGames: <GameCountRow>[_row('o1')],
        ),
        onCreateGame: () => create++,
        onOpenGame: opened.add,
      ),
    );
    await tester.tap(find.text('Create game'));
    await tester.tap(find.byKey(const ValueKey<String>('contributor-game-o1')));
    await tester.tap(find.byKey(const ValueKey<String>('contributor-game-u1')));
    expect(create, 1);
    expect(opened, <String>['o1', 'u1']);
  });

  testWidgets('A visitor sees no Create game', (tester) async {
    await _pump(
      tester,
      ContributorGamesSections(
        counts: GameCounts(
          played: 1,
          organised: 1,
          upcoming: 0,
          organisedGames: <GameCountRow>[_row('o1')],
        ),
        showOrganised: false,
      ),
    );
    expect(find.text('Create game'), findsNothing);
  });
}
