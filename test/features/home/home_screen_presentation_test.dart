import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initHomeTestSupabase);

  // Push prompts are mobile/web only; desktop keeps the permission sheet out
  // of these presentation tests.
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('header, tabs and loading skeleton come from the DS', (
    tester,
  ) async {
    await pumpHome(tester, feedState: const FeedLoading());
    expect(find.byType(DabblerWordmark), findsOneWidget);
    expect(find.byType(DabblerAvatar), findsWidgets);
    expect(find.byType(DabblerTabs), findsOneWidget);
    expect(find.byType(DabblerSkeleton), findsWidgets);
    expect(find.text('3'), findsOneWidget, reason: 'unread count badge');
    expect(find.text('Set location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: desktop);

  testWidgets('error state is a DS empty state whose retry reloads', (
    tester,
  ) async {
    final h = await pumpHome(tester, feedState: const FeedFailure('x'));
    final before = h.feed.loads;
    expect(find.byType(DabblerEmptyState), findsOneWidget);
    await tester.tap(find.byType(DabblerButton).last);
    await tester.pump();
    expect(h.feed.loads, before + 1);
  }, variant: desktop);

  testWidgets('header actions keep their navigation targets', (tester) async {
    final h = await pumpHome(tester, feedState: const FeedLoading());
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    expect(h.pushed.last, contains('search'));
  }, variant: desktop);

  testWidgets('RTL (Arabic) renders without overflow', (tester) async {
    await pumpHome(
      tester,
      feedState: const FeedLoading(),
      locale: const Locale('ar'),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(DabblerTabs), findsOneWidget);
  }, variant: desktop);
}
