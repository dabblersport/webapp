import 'package:dabbler/features/profile/presentation/widgets/profile/contributor_bento.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_render_support.dart';

Future<void> _pump(WidgetTester tester, Widget child, [Locale? l]) =>
    pumpProfileScreen(
      tester,
      Scaffold(body: SingleChildScrollView(child: child)),
      l ?? const Locale('en'),
    );

void main() {
  setUpAll(loadProfileFonts);

  testWidgets('All sports: design tiles in order, unknown hero is a dash', (
    tester,
  ) async {
    await _pump(
      tester,
      const ContributorBento(
        accent: DabblerSportAccent.all,
        played: 64,
        organised: 38,
        showUpPercent: 96,
        minutesPlayed: 1130,
        sportProfiles: 2,
      ),
    );
    for (final String t in <String>[
      'Games & meetups',
      'As player or organiser',
      'Played',
      'Organised',
      'Show-up rate',
      'Minutes played',
      'Sport profiles',
      '1,130',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Rated by players'), findsNothing);
    expect(find.text('Primary sports'), findsNothing);
  });

  testWidgets(
    'Selected sport: scoped hero label, unsourced tiles are labelled unavailable',
    (tester) async {
      await _pump(
        tester,
        const ContributorBento(
          accent: DabblerSportAccent.all,
          sportName: 'Padel',
          played: 41,
        ),
      );
      expect(find.text('Padel games & meetups'), findsOneWidget);
      for (final String label in <String>[
        'Organised',
        'Show-up rate',
        'Minutes played',
        'Partners',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Not available yet'), findsNWidgets(4));
      expect(find.text('0'), findsNothing);
      expect(find.text('Sport profiles'), findsNothing);
    },
  );

  testWidgets('Hero opens games and Arabic renders', (tester) async {
    int taps = 0;
    await _pump(
      tester,
      ContributorBento(
        accent: DabblerSportAccent.all,
        played: 1,
        onOpenGames: () => taps++,
      ),
      const Locale('ar'),
    );
    expect(find.text('الألعاب واللقاءات'), findsOneWidget);
    await tester.tap(find.text('الألعاب واللقاءات'));
    expect(taps, 1);
  });
}
