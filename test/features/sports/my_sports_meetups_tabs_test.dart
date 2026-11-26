// KAN-1052: Meetups' sport tabs and All list follow the viewer's can-solo
// sports; "Browse all sports" brings back the rest.

import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/sports/presentation/providers/my_sports_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../meetups/meetup_screens_harness.dart';

// The harness's solo sports are s1 Running and s2 Yoga.
const _yoga = Sport(id: 's2', nameEn: 'Yoga', canSolo: true);

FakeMeetupRepository _repo() => FakeMeetupRepository()
  ..list = [
    meetupRow('run', title: 'Sunrise run').copyWith(sportId: 's1'),
    meetupRow(
      'yoga',
      title: 'Beach yoga',
    ).copyWith(sportId: 's2', sportNameEn: 'Yoga'),
  ];

Future<void> _pump(WidgetTester tester, {Locale locale = const Locale('en')}) =>
    pumpMeetups(
      tester,
      const MeetupsScreen(),
      _repo(),
      locale: locale,
      overrides: [
        mySportsNowProvider.overrideWithValue(const MySports([_yoga])),
      ],
    );

void main() {
  testWidgets('tabs show only the viewer\'s sports', (tester) async {
    await _pump(tester);
    expect(find.text('Yoga'), findsWidgets);
    expect(find.text('Running'), findsNothing);
  });

  testWidgets('the All tab lists only the viewer\'s sports', (tester) async {
    await _pump(tester);
    expect(find.text('Beach yoga'), findsWidgets);
    expect(find.text('Sunrise run'), findsNothing);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('Browse all shows the rest (${locale.languageCode})', (
      tester,
    ) async {
      await _pump(tester, locale: locale);
      final browse = locale.languageCode == 'ar'
          ? 'تصفح كل الرياضات'
          : 'Browse all sports';
      await tester.tap(find.bySemanticsLabel(browse));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(browse), findsNothing);
      expect(
        find.text(locale.languageCode == 'ar' ? 'جري' : 'Running'),
        findsWidgets,
      );
      expect(find.text('Sunrise run'), findsWidgets);
      // The rail chip's remove goes back to the viewer's sports.
      await tester.tap(
        find.bySemanticsLabel(
          locale.languageCode == 'ar'
              ? 'اعرض رياضاتي فقط'
              : 'Show only my sports',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sunrise run'), findsNothing);
    });
  }
}
