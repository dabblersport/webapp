import 'dart:convert';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/search/search_result_bundle.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/data/repositories/search_repository.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/features/social/presentation/screens/social_search_screen.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/supabase_test_client.dart';
import '../../support/render_mode.dart';
import '../home/home_measure_fixtures.dart';
import '../home/home_test_harness.dart';

/// KAN-606 (feed and search): a failed refresh or Retry keeps the feed items
/// already on screen and the error answer is only for a feed with nothing to
/// show; a failed next page ends the list in a "Couldn't load more. Tap to
/// retry." row whose tap loads it again; a failed search shows localized text
/// (never the raw error) with Retry.

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

Post _post(String id) => framePost(id, 'Name $id', 'Body $id', 'football', 1);

/// The posts every page answers with, by id.
class _Posts implements PostRepository {
  @override
  Future<Result<List<Post>, Failure>> getPostsByIds(List<String> ids) async =>
      Ok(<Post>[for (final id in ids) _post(id)]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The home feed RPC, steered by the test: the next page's post ids, or a
/// failure.
class _HomeFeedRpc {
  List<String> nextIds = <String>[];
  bool fails = false;
  int calls = 0;

  Future<http.Response> handle(http.Request request) async {
    if (!request.url.path.endsWith('/rpc/get_home_feed')) {
      return jsonListResponse(const <Map<String, dynamic>>[], request: request);
    }
    calls++;
    if (fails) {
      return postgrestErrorResponse(
        message: 'boom',
        code: '500',
        status: 500,
        request: request,
      );
    }
    final now = DateTime.utc(2026, 10, 20);
    return http.Response(
      jsonEncode(<Map<String, dynamic>>[
        for (var i = 0; i < nextIds.length; i++)
          <String, dynamic>{
            'activity_id': nextIds[i],
            'activity_type': 'post',
            'created_at': now
                .subtract(Duration(minutes: calls * 100 + i))
                .toIso8601String(),
          },
      ]),
      200,
      headers: <String, String>{'content-type': 'application/json'},
      request: request,
    );
  }
}

List<String> _ids(String prefix, int n) => <String>[
  for (var i = 0; i < n; i++) '$prefix$i',
];

List<String> _feedIds(FeedState s) => <String>[
  for (final item in s.items)
    if (item is FeedPostItem) item.post.id,
];

/// A steerable tab feed fetcher.
class _TabSource {
  List<Post> next = <Post>[];
  bool fails = false;

  Future<Result<List<Post>, Failure>> fetch({
    required int limit,
    required int offset,
  }) async => fails
      ? const Err(Failure(message: 'PostgrestException: boom'))
      : Ok(List<Post>.of(next));
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  // ---------------------------------------------------- For you notifier --
  group('FeedNotifier', () {
    late _HomeFeedRpc rpc;
    late FeedNotifier notifier;

    Future<void> start(List<String> firstPage) async {
      rpc = _HomeFeedRpc()..nextIds = firstPage;
      notifier = FeedNotifier(_Posts(), buildTestSupabaseClient(rpc.handle));
      addTearDown(notifier.dispose);
      await pumpEventQueue();
    }

    test('populated + failed refresh keeps the items', () async {
      await start(_ids('a', 3));
      expect(_feedIds(notifier.state), _ids('a', 3));

      rpc.fails = true;
      final ok = await notifier.load();

      expect(ok, isFalse);
      expect(notifier.state, isA<FeedData>());
      expect(_feedIds(notifier.state), _ids('a', 3));
      expect(notifier.state.error, isNull);
    });

    test('a refresh over items keeps them on screen while it runs', () async {
      await start(_ids('a', 2));
      rpc.nextIds = _ids('b', 2);
      final pending = notifier.load();
      expect(notifier.state.isLoading, isFalse);
      expect(_feedIds(notifier.state), _ids('a', 2));
      expect(await pending, isTrue);
      expect(_feedIds(notifier.state), _ids('b', 2));
    });

    test('empty + failed load shows the failure', () async {
      rpc = _HomeFeedRpc()..fails = true;
      notifier = FeedNotifier(_Posts(), buildTestSupabaseClient(rpc.handle));
      addTearDown(notifier.dispose);
      await pumpEventQueue();
      expect(notifier.state, isA<FeedFailure>());
      expect(notifier.state.items, isEmpty);
    });

    test('a failed next page is flagged, keeps the items, and the retry '
        'loads it', () async {
      await start(_ids('a', 20)); // a full page: more may follow
      expect(notifier.state.hasMore, isTrue);

      rpc.fails = true;
      await notifier.loadMore();
      expect(notifier.state.loadMoreFailed, isTrue);
      expect(notifier.state.isLoadingMore, isFalse);
      expect(_feedIds(notifier.state), _ids('a', 20));

      rpc
        ..fails = false
        ..nextIds = _ids('b', 3);
      await notifier.loadMore();
      expect(notifier.state.loadMoreFailed, isFalse);
      expect(_feedIds(notifier.state), [..._ids('a', 20), ..._ids('b', 3)]);
    });
  });

  // ------------------------------------------- Following / Nearby notifier --
  group('TabFeedNotifier', () {
    test('populated + failed refresh keeps the posts', () async {
      final src = _TabSource()..next = [_post('p1'), _post('p2')];
      final n = TabFeedNotifier(src.fetch);
      addTearDown(n.dispose);
      await pumpEventQueue();
      expect(n.state.posts.map((p) => p.id), ['p1', 'p2']);

      src.fails = true;
      final ok = await n.load();

      expect(ok, isFalse);
      expect(n.state, isA<TabFeedData>());
      expect(n.state.posts.map((p) => p.id), ['p1', 'p2']);
      expect(n.state.error, isNull);
    });

    test('empty + failed load shows the failure', () async {
      final src = _TabSource()..fails = true;
      final n = TabFeedNotifier(src.fetch);
      addTearDown(n.dispose);
      await pumpEventQueue();
      expect(n.state, isA<TabFeedFailure>());
    });

    test('a failed next page is flagged, keeps the posts, and the retry '
        'loads it', () async {
      final src = _TabSource()
        ..next = [for (var i = 0; i < 20; i++) _post('a$i')];
      final n = TabFeedNotifier(src.fetch);
      addTearDown(n.dispose);
      await pumpEventQueue();

      src.fails = true;
      await n.loadMore();
      expect(n.state.loadMoreFailed, isTrue);
      expect(n.state.posts, hasLength(20));

      src
        ..fails = false
        ..next = [_post('b1')];
      await n.loadMore();
      expect(n.state.loadMoreFailed, isFalse);
      expect(n.state.posts.last.id, 'b1');
      expect(n.state.posts, hasLength(21));
    });
  });

  // -------------------------------------------------------- Home For you --
  group('Home For you tab', () {
    // Off mobile, Home never asks the push-permission plugin (as the other
    // Home tests run).
    final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

    Future<void> pull(WidgetTester tester) async {
      final list = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      );
      await tester.drag(list.first, const Offset(0, 340));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('populated + failed refresh keeps the items and toasts', (
      tester,
    ) async {
      final h = await pumpHome(
        tester,
        feedState: FeedData(items: [FeedPostItem(_post('p1'))]),
      );
      expect(find.text('Body p1'), findsOneWidget);
      h.feed.loadSucceeds = false;

      await pull(tester);

      expect(h.feed.loads, greaterThan(0));
      expect(find.text('Body p1'), findsOneWidget);
      expect(find.text(_l.feed_could_not_load), findsNothing);
      expect(find.text(_l.offline_refresh_failed), findsOneWidget);
    }, variant: desktop);

    testWidgets('a refresh that succeeds shows no failure toast', (
      tester,
    ) async {
      await pumpHome(
        tester,
        feedState: FeedData(items: [FeedPostItem(_post('p1'))]),
      );
      await pull(tester);
      expect(find.text(_l.offline_refresh_failed), findsNothing);
    }, variant: desktop);

    testWidgets('empty + failed load shows the error and Retry', (
      tester,
    ) async {
      final h = await pumpHome(
        tester,
        feedState: const FeedFailure('PostgrestException: boom'),
      );
      expect(find.text(_l.feed_could_not_load), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);
      final before = h.feed.loads;
      await tester.tap(find.text(_l.feed_retry));
      await tester.pump();
      expect(h.feed.loads, before + 1);
    }, variant: desktop);

    testWidgets('a failed next page ends the list in the retry row; a tap '
        'loads it again', (tester) async {
      final h = await pumpHome(
        tester,
        feedState: FeedData(
          items: [FeedPostItem(_post('p1'))],
          loadMoreFailed: true,
        ),
      );
      final row = find.text(_l.offline_load_more_failed);
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .first,
      );
      expect(row, findsOneWidget);
      // Scrolling to the row did not retry by itself.
      expect(h.feed.loadMores, 0);

      await tester.tap(row);
      await tester.pump();
      expect(h.feed.loadMores, 1);
    }, variant: desktop);

    testWidgets('no retry row while the next page is fine', (tester) async {
      await pumpHome(
        tester,
        feedState: FeedData(items: [FeedPostItem(_post('p1'))]),
      );
      expect(find.text(_l.offline_load_more_failed), findsNothing);
    }, variant: desktop);
  });

  // --------------------------------------------------------------- Search --
  group('Search', () {
    testWidgets('a failed search shows localized text, never the raw error, '
        'and Retry runs it again', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = _FailingSearch();
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => DabblerToastProvider(child: child!),
            theme: DabblerDesignSystemTheme.withFonts(
              DabblerDesignSystemTheme.withTokens(renderThemeBase()),
              locale: const Locale('en'),
            ),
            home: const SocialSearchScreen(),
          ),
        ),
      );
      await tester.pump();

      await container.read(searchProvider.notifier).search('football');
      await tester.pump();

      expect(find.text(_l.composer_search_failed), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(repo.queries, ['football']);

      await tester.tap(find.text(_l.feed_retry));
      await tester.pump();
      await tester.pump();
      expect(repo.queries, ['football', 'football']);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FailingSearch implements SearchRepository {
  final queries = <String>[];

  @override
  Future<Result<SearchResultBundle, Failure>> unifiedSearch({
    required String query,
    required SearchMode mode,
    int limit = 20,
  }) async {
    queries.add(query);
    return const Err(
      Failure(message: 'PostgrestException(message: boom, code: 500)'),
    );
  }
}
