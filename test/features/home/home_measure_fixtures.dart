/// Home pumped with the design file's own sample copy (`FrameData`), shared by
/// the measurement and the render tests so both see the same screen.
library;

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/home/presentation/widgets/home_news_rows.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_data.dart';
import 'home_test_harness.dart';

/// A post as the frame's `RECENT` array draws it.
Post framePost(
  String id,
  String name,
  String body,
  String sport,
  int likes, {
  int comments = 0,
  String? place,
  int hours = 2,
}) => Post(
  id: id,
  authorProfileId: 'prof-$id',
  authorUserId: 'user-$id',
  authorDisplayName: name,
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  personaTypeSnapshot: 'player',
  body: body,
  sport: sport,
  locationName: place,
  tags: const <String>[],
  likeCount: likes,
  commentCount: comments,
  createdAt: DateTime.now().subtract(Duration(hours: hours, minutes: 5)),
  updatedAt: DateTime.now(),
);

/// Three upcoming games: the frame's `UPCOMING[0..2]`. The first keeps its
/// 19:30 start; the other two start 12h 31m and 46h 1m out, so the countdown
/// reads the frame's "in 12h 30m" and "in 1d" (the minute is floored).
List<Game> frameGames(FrameData d) {
  final DateTime now = DateTime.now();
  String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  Game game(String id, String title, String venue, DateTime at, String start) =>
      Game(
        id: id,
        title: title,
        description: '',
        sport: 'Football',
        venueName: venue,
        scheduledDate: at,
        startTime: start,
        endTime: '23:59',
        minPlayers: 2,
        maxPlayers: 10,
        currentPlayers: 4,
        organizerId: 'o',
        skillLevel: 'mixed',
        pricePerPlayer: 0,
        status: GameStatus.upcoming,
        isPublic: true,
        allowsWaitlist: false,
        checkInEnabled: false,
        createdAt: now,
        updatedAt: now,
      );
  final DateTime second = now.add(const Duration(hours: 12, minutes: 31));
  final DateTime third = now.add(const Duration(hours: 46, minutes: 1));
  return <Game>[
    game(
      'u19',
      d.gameTitle,
      d.venue,
      now.add(const Duration(hours: 19)),
      '19:30',
    ),
    game('u12', d.listTitle1, d.listVenue1, second, hhmm(second)),
    game('u46', d.listTitle2, d.listVenue2, third, hhmm(third)),
  ];
}

/// Lets the page, the tab pager and every animation settle.
Future<void> settleHome(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Pumps Home with the frame's data in [locale]'s language: [postCount] copies
/// of the first post on every post tab, one activity, one news story, three
/// upcoming games, and the 50px status-bar inset the frame draws.
Future<void> pumpFrameHome(
  WidgetTester tester, {
  required Locale locale,
  List<Override> extra = const <Override>[],
  int postCount = 1,
  bool inShell = false,
  Key? boundaryKey,
}) async {
  final FrameData d = FrameData.of(locale.languageCode == 'ar');
  final List<Post> posts = <Post>[
    for (var i = 0; i < postCount; i++)
      framePost(
        'a$i',
        d.name,
        d.body,
        d.cricket,
        12,
        comments: 4,
        place: d.place,
      ),
  ];
  await pumpHome(
    tester,
    locale: locale,
    topInset: 50,
    inShell: inShell,
    boundaryKey: boundaryKey,
    locationName: d.location,
    overrides: <Override>[
      homeNewsReactionCountsProvider.overrideWith(
        (ref, id) async => <String, int>{'loving': 128},
      ),
      ...extra,
    ],
    upcoming: frameGames(d),
    feedState: FeedData(
      items: <FeedItem>[for (final Post p in posts) FeedPostItem(p)],
      hasMore: false,
    ),
    followingState: TabFeedData(posts: posts, hasMore: false),
    nearbyState: TabFeedData(posts: posts, hasMore: false),
    activeState: ActiveFeedData(
      events: <ActiveEvent>[
        GameCreatedEvent(
          id: 'g1',
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
          gameId: 'g1',
          gameTitle: d.gameTitle,
          sport: 'Padel',
          venueName: d.venue,
        ),
      ],
      hasMore: false,
    ),
    newsState: NewsTabState(
      items: <FeedNewsItem>[
        FeedNewsItem(
          newsId: 'n1',
          id: 'n1',
          title: <String, String>{
            'en': FrameData.en.newsTitle,
            'ar': FrameData.ar.newsTitle,
          },
          body: <String, String>{
            'en': FrameData.en.newsExcerpt,
            'ar': FrameData.ar.newsExcerpt,
          },
          likeCount: 0,
          commentCount: 24,
          viewCount: 1902,
          tags: const [],
          isPinned: false,
          priorityScore: 0,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          feedLabel: d.football,
          regions: <String>[d.region],
        ),
      ],
      loaded: true,
      hasMore: false,
    ),
  );
  await settleHome(tester);
}
