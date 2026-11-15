// KAN-956: Home's scroll and fixed regions match `Home Feed.dc.html` — the
// status bar and the header above one scroll area, the header folding on a
// scroll down and back on a scroll up, the tab rail scrolling away with the
// feed, and the bottom bar floating fixed over it.
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/features/home/presentation/widgets/home_feed_scroll.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_fixtures.dart';
import 'home_test_harness.dart';

FeedData _feed({bool hasMore = false}) => FeedData(
  items: <FeedItem>[
    for (var i = 0; i < 30; i++)
      FeedPostItem(framePost('p$i', 'Name $i', 'Body $i', 'football', 1)),
  ],
  hasMore: hasMore,
);

Finder get _header => find.byKey(HomeCollapsingHeader.regionKey);
Finder get _feedScroll => find.byType(CustomScrollView).first;
Finder get _bar => find.byType(DabblerNavigationBottomBar);

/// Lets the 200ms fold run out.
Future<void> _settleFold(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  // Off mobile, Home never asks the push-permission plugin.
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('header folds on scroll down, unfolds on scroll up — $dir', (
      tester,
    ) async {
      await pumpHome(tester, feedState: _feed(), locale: locale, inShell: true);
      await tester.pump();
      final open = tester.getSize(_header).height;
      expect(open, greaterThan(0));

      await tester.drag(_feedScroll, const Offset(0, -300));
      await _settleFold(tester);
      expect(tester.getSize(_header).height, 0, reason: 'folded');

      await tester.drag(_feedScroll, const Offset(0, 120));
      await _settleFold(tester);
      expect(tester.getSize(_header).height, open, reason: 'back on scroll up');
      expect(tester.takeException(), isNull);
    }, variant: desktop);

    testWidgets('bottom bar stays fixed while the list scrolls — $dir', (
      tester,
    ) async {
      await pumpHome(tester, feedState: _feed(), locale: locale, inShell: true);
      await tester.pump();
      final bar = tester.getRect(_bar);
      final row = tester.getTopLeft(find.text('Body 1')).dy;

      await tester.drag(_feedScroll, const Offset(0, -200));
      await _settleFold(tester);

      expect(tester.getTopLeft(find.text('Body 1')).dy, lessThan(row));
      expect(tester.getRect(_bar), bar);
    }, variant: desktop);

    testWidgets('tab rail scrolls away with the feed — $dir', (tester) async {
      await pumpHome(tester, feedState: _feed(), locale: locale, inShell: true);
      await tester.pump();
      expect(find.byType(DabblerTabs).hitTestable(), findsOneWidget);

      await tester.drag(_feedScroll, const Offset(0, -600));
      await _settleFold(tester);

      expect(
        find.byType(DabblerTabs).hitTestable(),
        findsNothing,
        reason: 'the rail is not sticky',
      );
    }, variant: desktop);
  }

  // The frame draws the row at the end of the Active list only
  // (`Home Feed.dc.html:434`); the other tabs end at their last row.
  group("You're all caught up", () {
    ActiveFeedData active({required bool hasMore, bool empty = false}) =>
        ActiveFeedData(
          events: <ActiveEvent>[
            if (!empty)
              GameCreatedEvent(
                id: 'g1',
                createdAt: DateTime(2026, 11, 16),
                gameId: 'g1',
                gameTitle: 'Sunday 5-a-side',
                sport: 'Football',
                venueName: 'Al Wasl Sports Club',
              ),
          ],
          hasMore: hasMore,
        );

    Future<void> openActive(
      WidgetTester tester,
      ActiveFeedData state, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpHome(
        tester,
        feedState: _feed(),
        activeState: state,
        locale: locale,
      );
      await tester.pump();
      // The rail scrolls sideways on its own: bring the tab into view first.
      final tab = find.text(
        FeedTab.active.label(lookupAppLocalizations(locale)),
      );
      await tester.ensureVisible(tab);
      await tester.pump();
      await tester.tap(tab);
      await tester.pump();
    }

    for (final (Locale locale, String text) in const <(Locale, String)>[
      (Locale('en'), "You're all caught up"),
      (Locale('ar'), 'وصلت لآخر المنشورات'),
    ]) {
      testWidgets('ends the Active list with no more pages — '
          '${locale.languageCode}', (tester) async {
        await openActive(tester, active(hasMore: false), locale: locale);
        expect(find.text(text), findsOneWidget);
        // After the last row, centred in the feed column.
        expect(
          tester.getTopLeft(find.text(text)).dy,
          greaterThan(tester.getTopLeft(find.byType(ActiveEventCard)).dy),
        );
        final row = tester.getRect(find.text(text));
        final page = tester.getRect(_feedScroll);
        expect(row.center.dx, moreOrLessEquals(page.center.dx, epsilon: 1));
      }, variant: desktop);
    }

    testWidgets('is absent while more pages remain', (tester) async {
      await openActive(tester, active(hasMore: true));
      expect(find.text("You're all caught up"), findsNothing);
    }, variant: desktop);

    testWidgets('is absent on an empty list', (tester) async {
      await openActive(tester, active(hasMore: false, empty: true));
      expect(find.text("You're all caught up"), findsNothing);
    }, variant: desktop);

    testWidgets('is not drawn on For you', (tester) async {
      await pumpHome(
        tester,
        feedState: FeedData(
          items: <FeedItem>[
            FeedPostItem(framePost('p0', 'Name 0', 'Body 0', 'football', 1)),
          ],
          hasMore: false,
        ),
      );
      await tester.pump();
      expect(find.text("You're all caught up"), findsNothing);
    }, variant: desktop);
  });

  // KAN-955: Following matches followed people and followed sports, and its
  // empty state says so in both languages.
  for (final (Locale locale, String title, String hint)
      in const <(Locale, String, String)>[
        (
          Locale('en'),
          'Nothing from who and what you follow yet',
          'Follow players or sports to see their posts here.',
        ),
        (
          Locale('ar'),
          'لا يوجد شيء ممن وما تتابعه بعد',
          'تابع لاعبين أو رياضات لترى منشوراتهم هنا.',
        ),
      ]) {
    testWidgets('Following empty state — ${locale.languageCode}', (
      tester,
    ) async {
      await pumpHome(
        tester,
        feedState: _feed(),
        followingState: const TabFeedData(posts: [], hasMore: false),
        locale: locale,
      );
      await tester.pump();
      final tab = find.text(
        FeedTab.following.label(lookupAppLocalizations(locale)),
      );
      await tester.ensureVisible(tab);
      await tester.pump();
      await tester.tap(tab);
      await tester.pump();
      expect(find.text(title), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
    }, variant: desktop);
  }

  testWidgets('switching tabs shows the header', (tester) async {
    await pumpHome(tester, feedState: _feed(), inShell: true);
    await tester.pump();
    final open = tester.getSize(_header).height;

    // A short scroll folds the header and leaves the rail on screen.
    await tester.drag(_feedScroll, const Offset(0, -40));
    await _settleFold(tester);
    expect(tester.getSize(_header).height, 0);

    await tester.tap(find.text('Following'));
    await _settleFold(tester);
    expect(tester.getSize(_header).height, open);
  }, variant: desktop);

  testWidgets('scrolling near the end loads the next page', (tester) async {
    final h = await pumpHome(
      tester,
      feedState: _feed(hasMore: true),
      inShell: true,
    );
    await tester.pump();
    expect(h.feed.loadMores, 0);

    // Drag the one feed scroll area down to its end, past the upcoming strip
    // and the rail, into the last 500px of the list.
    for (var i = 0; i < 8 && h.feed.loadMores == 0; i++) {
      await tester.drag(_feedScroll, const Offset(0, -800));
      await tester.pump();
    }

    expect(h.feed.loadMores, greaterThan(0));
  }, variant: desktop);
}
