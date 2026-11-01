import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_render_support.dart';

Future<void> _pump(WidgetTester tester, Widget child) => pumpProfileScreen(
  tester,
  Scaffold(body: SingleChildScrollView(child: child)),
  const Locale('en'),
);

void main() {
  setUpAll(loadProfileFonts);

  testWidgets('hero taps fire its callback (All sports, no sport chosen)', (
    tester,
  ) async {
    int taps = 0;
    await _pump(
      tester,
      OwnProfileStats(
        posts: 7,
        sportsCount: 2,
        gamesPlayed: 5,
        onOpenSport: () => taps++,
      ),
    );
    await tester.tap(find.text('5'));
    expect(taps, 1);
  });

  testWidgets('hero without a callback is inert', (tester) async {
    await _pump(
      tester,
      const OwnProfileStats(posts: 7, sportsCount: 2, gamesPlayed: 5),
    );
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
  });
}
