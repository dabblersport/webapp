import 'package:dabbler/features/home/presentation/screens/home_screen.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import '../location/manual_location_surfaces_support.dart';
import 'home_test_harness.dart';

/// KAN-526 on Home (header + nearby feed): denied -> the "Set location"
/// drawer, never an OS prompt.
void main() {
  setUpAll(initHomeTestSupabase);

  // Push prompts are mobile/web only; desktop keeps that sheet out.
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  final home = find.byType(HomeScreen);

  testWidgets('denied: drawer opens once, a pick sets the location', (
    tester,
  ) async {
    final fake = installGeo();
    await pumpHome(tester, feedState: const FeedLoading());
    await expectPickFlow(tester, fake, home);
  }, variant: desktop);

  testWidgets('denied: dismiss keeps the Set location action, no loop', (
    tester,
  ) async {
    final fake = installGeo();
    await pumpHome(tester, feedState: const FeedLoading());
    await expectDismissFlow(tester, fake, home);
  }, variant: desktop);

  testWidgets('granted with a location: no drawer', (tester) async {
    final fake = installGeo(permission: LocationPermission.whileInUse);
    await pumpHome(
      tester,
      feedState: const FeedLoading(),
      locationName: 'Marina',
    );
    await expectNoDrawer(tester, fake);
  }, variant: desktop);
}
