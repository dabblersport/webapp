import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/features/home/presentation/widgets/home_feed_parts.dart';
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

Post _post({String? body = 'Anyone playing cricket in Dubai this weekend?'}) =>
    Post(
      id: 'p1',
      authorProfileId: 'prof1',
      authorUserId: 'user1',
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
        myProfileIdProvider.overrideWith((ref) async => 'someone-else'),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
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
    expect(find.text('Anyone playing cricket in Dubai this weekend?'), findsOneWidget);
    expect(find.text('Cricket'), findsOneWidget, reason: 'sport DabblerBadge');
    expect(find.byType(DabblerBadge), findsWidgets);
    expect(find.byType(DabblerAvatar), findsOneWidget);
    expect(find.text('12'), findsOneWidget, reason: 'like count');
    expect(find.text('#cricket'), findsOneWidget);
    _noMaterialVisuals();

    await tester.tap(find.text('Anyone playing cricket in Dubai this weekend?'));
    await tester.pumpAndSettle();
    expect(visited.last, contains('${RoutePaths.socialPostDetail}/p1'));
  });

  testWidgets('a post photo keeps the photo, no photo falls back to the seed', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: const [
          HomeAvatar(name: 'With Photo', imageUrl: 'https://example.invalid/a.png'),
          HomeAvatar(name: 'No Photo'),
        ],
      ),
    );
    expect(find.byType(Image), findsOneWidget, reason: 'the real photo');
    expect(find.byType(DabblerAvatar), findsWidgets, reason: 'seed fallback');
  });

  testWidgets('HomeNewsCompactRow opens the news detail and offers hide', (
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
      sourceLabel: 'Gulf Sport',
    );
    final visited = await _pump(
      tester,
      HomeNewsCompactRow(item: item, onDismiss: () => hidden++),
    );
    expect(find.text('Transfer window opens'), findsOneWidget);
    expect(find.text('Gulf Sport'), findsOneWidget);
    _noMaterialVisuals();
    await tester.drag(find.text('Transfer window opens'), const Offset(-300, 0));
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
    expect(find.text('مرحبا يا لاعبين'), findsOneWidget);
  });
}
