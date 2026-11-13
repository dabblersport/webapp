import 'package:dabbler/features/location/presentation/widgets/city_required_sheet.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'home_test_harness.dart';

/// KAN-588: the Home Nearby tab needs a city. With none it says "Choose city"
/// and offers "Select city"; the other tabs never depend on a location.
void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  Future<void> openNearby(WidgetTester tester) async {
    await tester.tap(find.text('Nearby').first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'no city: Nearby says Choose city and Select city opens the picker',
    (tester) async {
      await pumpHome(
        tester,
        feedState: const FeedLoading(),
        nearbyState: const TabFeedData(posts: [], hasMore: false),
      );
      await openNearby(tester);
      expect(find.text('Choose city'), findsOneWidget);
      expect(find.text('Select city'), findsOneWidget);
      expect(find.text('Nothing nearby yet.'), findsNothing);

      await tester.tap(find.text('Select city'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CityRequiredSheet), findsOneWidget);
    },
    variant: desktop,
  );

  testWidgets('a city: Nearby is the feed, not the Choose city answer', (
    tester,
  ) async {
    await pumpHome(
      tester,
      feedState: const FeedLoading(),
      nearbyState: const TabFeedData(posts: [], hasMore: false),
      locationName: 'Dubai Marina',
    );
    await openNearby(tester);
    expect(find.text('Choose city'), findsNothing);
    expect(find.text('Nothing nearby yet.'), findsOneWidget);
  }, variant: desktop);

  testWidgets('no city: the other tabs still open without a location', (
    tester,
  ) async {
    await pumpHome(tester, feedState: const FeedLoading());
    for (final tab in <String>['Following', 'Active', 'News']) {
      await tester.tap(find.text(tab).first);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Choose city'), findsNothing, reason: tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
  }, variant: desktop);
}
