// KAN-966: For you draws the Active tab's card between posts with no divider
// above or below it (dividers stay between posts), never two cards in a row,
// and records a card as seen only once it is on screen, with its feed_at.
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';
import 'package:dabbler/features/home/presentation/widgets/home_for_you_card.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/social/providers/feed_impressions.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_957_support.dart' show activeNow, desktopOnly;
import 'active_fixtures.dart';
import 'home_measure_fixtures.dart' show framePost;
import 'home_test_harness.dart';

FeedPostItem _p(String id) =>
    FeedPostItem(framePost(id, 'Name $id', 'Body of $id', 'padel', 1));

FeedActiveItem _c(String id, String anchor) => FeedActiveItem(
  activeGame(id: id, at: activeNow.subtract(const Duration(minutes: 30))),
  feedAt: DateTime.utc(2026, 11, 16, 10),
  cursorId: anchor,
  score: 70,
);

const Duration _delay = Duration(milliseconds: 20);

Future<List<List<FeedImpression>>> _pump(
  WidgetTester tester,
  List<FeedItem> items,
  Locale locale,
) async {
  final sent = <List<FeedImpression>>[];
  final tracker = FeedImpressionTracker(
    (b) async => sent.add(b),
    delay: _delay,
  );
  await pumpHome(
    tester,
    feedState: FeedData(items: items, hasMore: false),
    locale: locale,
    overrides: <Override>[
      homeNowProvider.overrideWithValue(() => activeNow),
      feedImpressionTrackerProvider.overrideWithValue(tracker),
    ],
  );
  await tester.pump();
  return sent;
}

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  test(
    'spaceForYouCards keeps the order and drops a leading or doubled card',
    () {
      final out = spaceForYouCards(<FeedItem>[
        _c('g0', 'x'),
        _p('p1'),
        _c('g1', 'p1'),
        _c('g2', 'p1'),
        _p('p2'),
        _c('g3', 'p2'),
      ]);
      expect(
        out.map(
          (i) => i is FeedActiveItem
              ? i.item.entityId
              : (i as FeedPostItem).post.id,
        ),
        <String>['p1', 'g1', 'p2', 'g3'],
      );
    },
  );

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('$lang: a card between posts, no divider above or below it', (
      tester,
    ) async {
      await _pump(tester, <FeedItem>[
        _p('p1'),
        _c('g1', 'p1'),
        _p('p2'),
        _p('p3'),
      ], locale);
      expect(find.byType(HomeForYouCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HomeForYouCard),
          matching: find.byType(ActiveEventCard),
        ),
        findsOneWidget,
        reason: 'the Active tab card',
      );
      final card = _rect(tester, find.byType(HomeForYouCard));
      final rows = find.byType(HomePostRow);
      expect(rows, findsNWidgets(3));
      final p1 = _rect(tester, rows.at(0));
      final p2 = _rect(tester, rows.at(1));
      final p3 = _rect(tester, rows.at(2));
      expect(p1.bottom, moreOrLessEquals(card.top), reason: 'nothing above');
      expect(card.bottom, moreOrLessEquals(p2.top), reason: 'nothing below');
      final dividers = find
          .byType(DabblerDivider)
          .evaluate()
          .map(
            (e) => (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
          );
      expect(
        dividers.where((y) => y >= p2.bottom - 0.5 && y <= p3.top + 0.5),
        isNotEmpty,
        reason: 'posts keep their divider',
      );
      expect(
        dividers.where((y) => y > p1.top && y < p2.top),
        isEmpty,
        reason: 'no divider touches the card',
      );
    }, variant: desktopOnly);

    testWidgets('$lang: two cards arriving together draw one', (tester) async {
      await _pump(tester, <FeedItem>[
        _p('p1'),
        _c('g1', 'p1'),
        _c('g2', 'p1'),
        _p('p2'),
      ], locale);
      expect(find.byType(HomeForYouCard), findsOneWidget);
    }, variant: desktopOnly);

    testWidgets('$lang: an on-screen card is recorded once, with feed_at', (
      tester,
    ) async {
      final sent = await _pump(tester, <FeedItem>[
        _p('p1'),
        _c('g1', 'p1'),
        _p('p2'),
      ], locale);
      await tester.pump(_delay * 3);
      await tester.pump();
      expect(sent, hasLength(1));
      expect(sent.single, <FeedImpression>[
        {
          'entity_type': 'game',
          'entity_id': 'g1',
          'feed_at': DateTime.utc(2026, 11, 16, 10).toIso8601String(),
        },
      ]);
    }, variant: desktopOnly);
  }
}
