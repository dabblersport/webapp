// KAN-998: the meetup detail draws the check-in row only for a going member
// who is not the host.

import 'package:dabbler/features/attendance/presentation/check_in_entry.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meetup_screens_harness.dart';

void main() {
  final cases = <String, (MeetupCard, bool)>{
    'a going member sees the row': (
      const MeetupCard(id: 'm1', title: 'Run', myStatus: 'going'),
      true,
    ),
    'the host does not': (
      const MeetupCard(id: 'm1', title: 'Run', myStatus: 'going', isHost: true),
      false,
    ),
    'a waitlisted member does not': (
      const MeetupCard(id: 'm1', title: 'Run', myStatus: 'waitlisted'),
      false,
    ),
    'an interested member does not': (
      const MeetupCard(id: 'm1', title: 'Run', myStatus: 'interested'),
      false,
    ),
  };
  for (final c in cases.entries) {
    testWidgets(c.key, (t) async {
      await pumpMeetups(
        t,
        MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
        FakeMeetupRepository()..card = c.value.$1,
      );
      expect(
        find.byType(CheckInEntry),
        c.value.$2 ? findsOneWidget : findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    });
  }
}
