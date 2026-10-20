import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/features/home/presentation/widgets/home_news_rows.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'home_test_harness.dart';
import '../../support/render_mode.dart';

Post _post({
  String? body = 'Anyone playing cricket in Dubai this weekend?',
  String? avatarUrl,
  Map<String, dynamic> reactionBreakdown = const {},
  String authorProfileId = 'prof1',
  int viewCount = 0,
}) =>
    Post(
      id: 'p1',
      authorProfileId: authorProfileId,
      authorUserId: 'user1',
      authorAvatarUrl: avatarUrl,
      reactionBreakdown: reactionBreakdown,
      viewCount: viewCount,
      repostCount: 2,
      allowReposts: true,
      authorDisplayName: 'Suraj Mehta',
      kind: PostKind.original,
      visibility: PostVisibility.public,
      postType: PostType.dab,
      body: body,
      sport: 'Cricket',
      tags: const <String>['dabblersport', 'cricket'],
      likeCount: 12,
      commentCount: 0,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now(),
    );

Future<List<String>> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  String myProfileId = 'someone-else',
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final visited = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Material(child: SingleChildScrollView(child: child)),
      ),
      GoRoute(
        path: '/news/:newsId',
        name: RouteNames.newsDetail,
        builder: (_, s) {
          visited.add(s.uri.toString());
          return const SizedBox.shrink();
        },
      ),
      GoRoute(
        path: '/:rest(.*)',
        builder: (_, s) {
          visited.add(s.uri.toString());
          return const SizedBox.shrink();
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hasLikedProvider.overrideWith((ref, id) async => false),
        hasRepostedProvider.overrideWith((ref, id) async => false),
        myReactionsProvider.overrideWith((ref, id) async => <String>{}),
        myProfileIdProvider.overrideWith((ref) async => myProfileId),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(
        builder: (context, child) => DabblerToastProvider(child: child!),
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return visited;
}

void _noMaterialVisuals() {
  for (final Type t in <Type>[
    Card,
    ListTile,
    CircleAvatar,
    Chip,
    ElevatedButton,
    TextButton,
    OutlinedButton,
    IconButton,
    FilledButton,
  ]) {
    expect(
      find.byType(t),
      findsNothing,
      reason: '$t is a Material/Cupertino visual; Home rows use Dabbler* parts',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  testWidgets('HomePostRow is built from DS parts and opens post detail', (
    tester,
  ) async {
    final visited = await _pump(tester, HomePostRow(post: _post()));
    expect(find.text('Suraj Mehta'), findsOneWidget);
    expect(
      find.textContaining('Anyone playing cricket', findRichText: true),
      findsOneWidget,
      reason: 'body as DabblerPostRow runs',
    );
    expect(find.text('Cricket'), findsOneWidget, reason: 'sport label');
    expect(find.byType(DabblerPostRow), findsOneWidget);
    expect(find.byType(DabblerAvatar), findsOneWidget);
    expect(find.text('12'), findsOneWidget, reason: 'like count');
    expect(
      find.textContaining('#cricket', findRichText: true),
      findsOneWidget,
      reason: 'hashtag runs',
    );
    expect(find.byType(DabblerPostRow), findsOneWidget);
    _noMaterialVisuals();

    await tester.tap(
      find.textContaining('Anyone playing cricket', findRichText: true),
    );
    await tester.pumpAndSettle();
    expect(visited.last, contains('${RoutePaths.socialPostDetail}/p1'));
  });

  testWidgets('DabblerAvatar(imageUrl:) draws the photo; no URL falls back to the seed', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: const [
          DabblerAvatar(seed: 'With Photo', imageUrl: 'https://example.invalid/a.png'),
          DabblerAvatar(seed: 'No Photo'),
        ],
      ),
    );
    expect(find.byType(Image), findsOneWidget, reason: 'the real photo');
    expect(find.byType(DabblerAvatar), findsWidgets, reason: 'seed fallback');
  });

  testWidgets('a news story is a DabblerNewsCard that opens the detail and can be hidden', (
    tester,
  ) async {
    var hidden = 0;
    final item = FeedNewsItem(
      newsId: 'n1',
      id: 'n1',
      title: const {'en': 'Transfer window opens'},
      body: const {'en': 'Clubs have until Friday.'},
      likeCount: 0,
      commentCount: 0,
      viewCount: 0,
      tags: const [],
      isPinned: false,
      priorityScore: 0,
      createdAt: DateTime.now(),
      feedLabel: 'Padel',
    );
    final visited = await _pump(
      tester,
      HomeNewsCard(item: item, onDismiss: () => hidden++),
    );
    expect(find.text('Transfer window opens'), findsOneWidget);
    expect(find.byType(DabblerNewsCard), findsOneWidget);
    _noMaterialVisuals();
    // DabblerSwipeAction: swipe toward the end to reveal Hide, then press it.
    await tester.drag(find.text('Transfer window opens'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(hidden, 1);
    await tester.tap(find.text('Transfer window opens'));
    await tester.pumpAndSettle();
    expect(visited.last, '/news/n1');
  });

  testWidgets('HomeActivityRow renders actor and action from DS parts', (
    tester,
  ) async {
    final activity = PublicActivity(
      id: 'a1',
      activityType: PublicActivityType.comment,
      actorProfileId: 'x',
      actorUsername: 'khalid',
      createdAt: DateTime.now(),
    );
    await _pump(tester, HomeActivityRow(activity: activity));
    expect(find.textContaining('khalid'), findsOneWidget);
    expect(find.byType(DabblerAvatar), findsOneWidget);
    _noMaterialVisuals();
  });

  testWidgets('post row lays out in RTL without error', (tester) async {
    await _pump(
      tester,
      HomePostRow(post: _post(body: 'مرحبا يا لاعبين')),
      locale: const Locale('ar'),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('مرحبا يا لاعبين', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('restored: author photo and author tap open the profile', (
    tester,
  ) async {
    final visited = await _pump(
      tester,
      HomePostRow(post: _post(avatarUrl: 'https://example.invalid/s.png')),
    );
    expect(
      tester.widget<DabblerAvatar>(find.byType(DabblerAvatar)).imageUrl,
      'https://example.invalid/s.png',
    );
    await tester.tap(find.text('Suraj Mehta'));
    await tester.pumpAndSettle();
    expect(visited.last, contains('${RoutePaths.userProfile}/user1'));
  });

  testWidgets('restored: repost action, kind badge, reaction summary', (
    tester,
  ) async {
    await _pump(
      tester,
      HomePostRow(
        post: _post(
          reactionBreakdown: const {
            'breakdown': {'hyped': 4},
          },
        ),
      ),
    );
    // The frame's share glyph carries the repost action, with no count.
    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    expect(find.text('2'), findsNothing, reason: 'the frame shows no count');
    expect(find.text('Dab'), findsOneWidget, reason: 'post type pill');
    expect(find.text('hyped 4'), findsOneWidget, reason: 'reaction chip');
  });

  testWidgets('the frame draws no view count on a post row', (tester) async {
    await _pump(
      tester,
      HomePostRow(post: _post(authorProfileId: 'me', viewCount: 77)),
      myProfileId: 'me',
    );
    expect(find.text('77'), findsNothing);
  });

  testWidgets('restored: long press on the news heart opens the picker', (
    tester,
  ) async {
    final item = FeedNewsItem(
      newsId: 'n2',
      id: 'n2',
      title: const {'en': 'Story'},
      body: const {},
      likeCount: 0,
      commentCount: 0,
      viewCount: 0,
      tags: const [],
      isPinned: false,
      priorityScore: 0,
      createdAt: DateTime.now(),
    );
    await _pump(tester, HomeNewsCard(item: item));
    await tester.longPress(find.byWidgetPredicate(
      (w) => w is DabblerIcon && w.name == 'heart',
    ));
    await tester.pumpAndSettle();
    expect(find.text('Loving'), findsOneWidget);
    expect(find.text('Angry'), findsOneWidget);
  });

  testWidgets('restored: activity cover thumbnail', (tester) async {
    final activity = PublicActivity(
      id: 'a2',
      activityType: PublicActivityType.comment,
      actorProfileId: 'x',
      actorUsername: 'khalid',
      targetNewsId: 'n1',
      targetCoverImageUrl: 'https://example.invalid/c.png',
      createdAt: DateTime.now(),
    );
    await _pump(tester, HomeActivityRow(activity: activity));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('post media: DabblerImage tiles, with a position badge', (
    tester,
  ) async {
    await _pump(
      tester,
      HomePostMedia(
        urls: const ['https://example.invalid/1.png', 'https://example.invalid/2.png'],
      ),
    );
    expect(find.byType(DabblerImage), findsNWidgets(2));
    expect(find.text('1/2'), findsOneWidget);
    await _pump(
      tester,
      HomePostMedia(urls: const ['https://example.invalid/1.png']),
    );
    expect(find.byType(DabblerImage), findsOneWidget);
  });
}
