import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_share.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meetup_screens_harness.dart';

Future<List<(String, String)>> _pump(
  WidgetTester tester, {
  bool host = false,
  Locale locale = const Locale('en'),
}) async {
  final shared = <(String, String)>[];
  final repo = FakeMeetupRepository()
    ..card = MeetupCard(
      id: 'm1',
      title: 'Sunrise run',
      startAt: DateTime.now().add(const Duration(days: 1)),
      isHost: host,
    )
    ..eligibility = const RsvpEligibility(
      allowed: true,
      cta: RsvpCta.rsvpGoing,
    );
  await pumpMeetups(
    tester,
    MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
    repo,
    locale: locale,
    overrides: <Override>[
      meetupShareProvider.overrideWithValue((link, headline) async {
        shared.add((link, headline));
      }),
    ],
  );
  return shared;
}

void main() {
  test('the share link is the public meetup URL', () {
    expect(RoutePaths.meetupLink('abc'), 'https://app.dabbler.pro/meetups/abc');
    expect(RoutePaths.meetupDetail('abc'), '/meetups/abc');
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('share sends the link and headline (${locale.languageCode})', (
      tester,
    ) async {
      final shared = await _pump(tester, locale: locale);
      await tester.tap(find.bySemanticsLabel('Share'));
      await settle(tester);
      expect(shared, hasLength(1));
      expect(shared.single.$1, 'https://app.dabbler.pro/meetups/m1');
      expect(shared.single.$2, contains('Sunrise run'));
    });
  }

  testWidgets('Report opens the report dialog for target meetup', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await settle(tester);
    expect(find.text('Report meetup'), findsOneWidget);
    await tester.tap(find.text('Report meetup'));
    await settle(tester);
    final dialog = tester.widget<ReportDialog>(find.byType(ReportDialog));
    expect(dialog.targetType, ReportTargetType.meetup);
    expect(dialog.targetId, 'm1');
    expect(dialog.targetType.toModTarget().toPostgresString(), 'meetup');
    tester.takeException();
  });

  testWidgets('a host sees Share but not Report', (tester) async {
    await _pump(tester, host: true);
    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    expect(find.bySemanticsLabel('More'), findsNothing);
  });
}
