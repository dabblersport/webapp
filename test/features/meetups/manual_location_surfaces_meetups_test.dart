import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import '../location/manual_location_surfaces_support.dart';
import 'meetup_screens_harness.dart';

/// A non-empty list: the empty state's long button overflows under Ahem.
FakeMeetupRepository _repo() =>
    FakeMeetupRepository()..list = [meetupRow('a', title: 'Sunrise run')];

/// KAN-526 on Meetups: denied -> the "Set location" drawer, never a prompt.
void main() {
  final surface = find.byType(MeetupsScreen);

  testWidgets('denied: drawer opens once, a pick drives the surface', (
    tester,
  ) async {
    final fake = installGeo();
    await pumpMeetups(tester, const MeetupsScreen(), _repo(), denied: true);
    await expectPickFlow(tester, fake, surface);
  });

  testWidgets('denied: dismiss keeps the Set location action, no loop', (
    tester,
  ) async {
    final fake = installGeo();
    await pumpMeetups(tester, const MeetupsScreen(), _repo(), denied: true);
    await expectDismissFlow(tester, fake, surface);
  });

  testWidgets('granted with a location: no drawer', (tester) async {
    final fake = installGeo(permission: LocationPermission.whileInUse);
    await pumpMeetups(
      tester,
      const MeetupsScreen(),
      _repo(),
      locationReady: true,
    );
    await expectNoDrawer(tester, fake);
  });
}
