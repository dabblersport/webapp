// KAN-875: while a search query has no match, the activity log controller
// keeps loading older pages (capped at 20 per loop run), stops on error, and
// is cancelled by a query change or dispose.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/data/repositories/public_activity_repository.dart';
import 'package:dabbler/features/activities/data/datasources/activity_feed_datasource.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _t0 = DateTime(2026, 11, 4, 12);

/// Serves [pages] feed pages, newest first. Every page but the last is full
/// (feedPageSize rows) so the controller sees `hasMore`; the last is short.
/// Page `p` holds a single row titled [needle] when `p == needlePage`.
/// Call number [failOnCall] (0-based) throws. With [gated], every call after
/// the first waits until [release] is called.
class FakeFeed implements ActivityFeedDatasource {
  FakeFeed({
    required this.pages,
    this.needlePage,
    this.needle = 'needle',
    this.failOnCall,
    this.gated = false,
  });

  final int pages;
  final int? needlePage;
  final String needle;
  int? failOnCall;
  final bool gated;

  final List<DateTime?> cursors = <DateTime?>[];
  final List<Completer<void>> _gates = <Completer<void>>[];

  int get calls => cursors.length;
  int get pending => _gates.where((g) => !g.isCompleted).length;

  void release() {
    for (final Completer<void> g in _gates) {
      if (!g.isCompleted) g.complete();
    }
  }

  static const int _full = ActivityLogController.feedPageSize;

  List<ActivityFeedEvent> _page(int p) {
    final int size = p == pages - 1 ? 10 : _full;
    return List<ActivityFeedEvent>.generate(size, (int i) {
      final int n = p * _full + i;
      final bool hit = p == needlePage && i == 0;
      return ActivityFeedEvent(
        id: 'e$n',
        subjectType: 'game',
        subjectId: 'g$n',
        verb: 'created',
        timeBucket: 'past',
        happenedAt: _t0.subtract(Duration(minutes: n)),
        priority: 90,
        payload: <String, dynamic>{'title': hit ? needle : 'row $n'},
      );
    });
  }

  @override
  Future<List<ActivityFeedEvent>> getActivityFeed({
    required String period,
    int limit = 50,
    DateTime? cursor,
  }) async {
    final int call = cursors.length;
    cursors.add(cursor);
    if (gated && call > 0) {
      final Completer<void> g = Completer<void>();
      _gates.add(g);
      await g.future;
    }
    if (call == failOnCall) throw Exception('feed page failed');
    final int page = cursor == null
        ? 0
        : _t0.difference(cursor).inMinutes ~/ _full + 1;
    if (page >= pages) return const <ActivityFeedEvent>[];
    return _page(page);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Social source with no rows, so only the feed pages.
class FakeSocial implements PublicActivityRepository {
  int calls = 0;

  @override
  Future<Result<List<PublicActivity>, Failure>> fetchUserActivities({
    required String profileId,
    int limit = 20,
    int offset = 0,
  }) async {
    calls++;
    return const Ok(<PublicActivity>[]);
  }

  @override
  Future<Result<List<PublicActivity>, Failure>> fetchFollowingActivities({
    int limit = 20,
    int offset = 0,
  }) async => const Ok(<PublicActivity>[]);
}

Future<void> settle() async {
  for (int i = 0; i < 500; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  ActivityLogController make(FakeFeed feed) => ActivityLogController(
    feed: feed,
    social: FakeSocial(),
    profileId: () async => 'p-me',
  );

  test('isSearchingOlder defaults to false and copyWith keeps or sets it', () {
    const ActivityLogState s = ActivityLogState();
    expect(s.isSearchingOlder, isFalse);
    expect(s.copyWith(isSearchingOlder: true).isSearchingOlder, isTrue);
    expect(
      s.copyWith(isSearchingOlder: true).copyWith().isSearchingOlder,
      isTrue,
    );
  });

  group('AC1 match on page 3', () {
    test('loads pages until the match appears and stops there', () async {
      final FakeFeed feed = FakeFeed(pages: 10, needlePage: 2);
      final ActivityLogController c = make(feed);
      await c.load();
      expect(c.state.isSearchingOlder, isFalse);
      expect(feed.calls, 1);

      final List<ActivityLogState> seen = <ActivityLogState>[];
      c.addListener(seen.add, fireImmediately: false);
      c.changeQuery('needle');
      expect(c.state.isSearchingOlder, isTrue);
      await settle();

      expect(feed.calls, 3, reason: 'page 1 by load, pages 2 and 3 by loop');
      expect(c.state.filteredActivities.map((e) => e.id), <String>['e100']);
      expect(c.state.isSearchingOlder, isFalse);
      expect(c.state.hasMore, isTrue);

      // seen[0] is changeQuery's own write (query set, loop not yet started).
      // From the loop's start, every state before the match is true, and it
      // turns false only once the match is present.
      expect(seen.first.query, 'needle');
      expect(seen.first.isSearchingOlder, isFalse);
      seen.removeAt(0);
      expect(seen.first.isSearchingOlder, isTrue);
      final int firstMatch = seen.indexWhere(
        (s) => s.filteredActivities.isNotEmpty,
      );
      expect(firstMatch, greaterThan(0));
      for (final ActivityLogState s in seen.take(firstMatch)) {
        expect(s.isSearchingOlder, isTrue);
      }
      final int off = seen.indexWhere((s) => !s.isSearchingOlder);
      expect(off, greaterThanOrEqualTo(firstMatch));
      c.dispose();
    });
  });

  group('AC2 no match', () {
    test('ends only after hasMore is false', () async {
      final FakeFeed feed = FakeFeed(pages: 4);
      final ActivityLogController c = make(feed);
      await c.load();
      final List<ActivityLogState> seen = <ActivityLogState>[];
      c.addListener(seen.add, fireImmediately: false);
      c.changeQuery('zzz');
      await settle();

      expect(feed.calls, 4);
      expect(c.state.hasMore, isFalse);
      expect(c.state.isSearchingOlder, isFalse);
      seen.removeAt(0); // changeQuery's own write, before the loop starts
      final int off = seen.indexWhere((s) => !s.isSearchingOlder);
      expect(off, greaterThan(0));
      expect(seen[off].hasMore, isFalse);
      for (final ActivityLogState s in seen.take(off)) {
        expect(s.isSearchingOlder, isTrue);
      }
      c.dispose();
    });

    test('stops after exactly 20 loop pages with hasMore still true', () async {
      final FakeFeed feed = FakeFeed(pages: 40);
      final ActivityLogController c = make(feed);
      await c.load();
      c.changeQuery('zzz');
      await settle();

      expect(feed.calls - 1, ActivityLogController.searchOlderPageCap);
      expect(feed.calls - 1, 20);
      expect(c.state.isSearchingOlder, isFalse);
      expect(c.state.hasMore, isTrue);
      expect(c.state.error, isNull);
      c.dispose();
    });
  });

  group('AC3 fetch error', () {
    test('stops the loop and surfaces the existing error unchanged', () async {
      final FakeFeed feed = FakeFeed(pages: 10, failOnCall: 2);
      final ActivityLogController c = make(feed);
      await c.load();
      c.changeQuery('zzz');
      await settle();

      expect(feed.calls, 3, reason: 'no page requested after the failure');
      expect(c.state.isSearchingOlder, isFalse);
      expect(c.state.hasMore, isTrue);

      // Reference: the same failure through a plain loadMore().
      final FakeFeed refFeed = FakeFeed(pages: 10, failOnCall: 1);
      final ActivityLogController ref = make(refFeed);
      await ref.load();
      await ref.loadMore();
      expect(c.state.feedError, isNotNull);
      expect(c.state.feedError, ref.state.feedError);
      expect(c.state.error, ref.state.error);
      expect(c.state.isLoadingMore, isFalse);

      await settle();
      expect(feed.calls, 3, reason: 'no retry');
      c.dispose();
      ref.dispose();
    });

    test('Retry (load) restarts the loop', () async {
      final FakeFeed feed = FakeFeed(pages: 10, needlePage: 3, failOnCall: 2);
      final ActivityLogController c = make(feed);
      await c.load();
      c.changeQuery('needle');
      await settle();
      expect(c.state.error, isNotNull);
      expect(c.state.isSearchingOlder, isFalse);

      feed.failOnCall = null;
      final int before = feed.calls;
      await c.load();
      await settle();
      expect(c.state.error, isNull);
      expect(c.state.isSearchingOlder, isFalse);
      expect(c.state.filteredActivities.map((e) => e.id), <String>['e150']);
      expect(feed.calls - before, 4, reason: 'load page 1, loop pages 2-4');
      c.dispose();
    });
  });

  group('AC4 cancellation', () {
    test('clearing the query mid-loop stops it with no later writes', () async {
      final FakeFeed feed = FakeFeed(pages: 10, gated: true);
      final ActivityLogController c = make(feed);
      await c.load();
      c.changeQuery('zzz');
      await settle();
      expect(feed.calls, 2);
      expect(feed.pending, 1);
      expect(c.state.isSearchingOlder, isTrue);

      c.changeQuery('');
      expect(c.state.isSearchingOlder, isFalse);

      final List<ActivityLogState> seen = <ActivityLogState>[];
      c.addListener(seen.add, fireImmediately: false);
      feed.release();
      await settle();

      expect(feed.calls, 2, reason: 'no further page requested');
      expect(c.state.isSearchingOlder, isFalse);
      // Only the in-flight loadMore() writes: its page, then isLoadingMore.
      expect(seen.length, 2);
      expect(seen.any((s) => s.isSearchingOlder), isFalse);
      c.dispose();
    });

    test('a new query mid-loop cancels the old and starts fresh', () async {
      final FakeFeed feed = FakeFeed(pages: 10, needlePage: 2, gated: true);
      final ActivityLogController c = make(feed);
      await c.load();
      c.changeQuery('zzz');
      await settle();
      expect(feed.calls, 2);

      c.changeQuery('needle');
      expect(c.state.isSearchingOlder, isTrue);
      feed.release(); // page 2 (requested by the old loop)
      await settle();
      expect(feed.calls, 3, reason: 'new loop requests page 3 only');
      feed.release();
      await settle();

      expect(feed.calls, 3);
      expect(c.state.filteredActivities.map((e) => e.id), <String>['e100']);
      expect(c.state.isSearchingOlder, isFalse);
      c.dispose();
    });

    test('dispose mid-loop stops it without writing state', () async {
      final FakeFeed feed = FakeFeed(pages: 10, gated: true);
      final ActivityLogController c = make(feed);
      await c.load();
      c.changeQuery('zzz');
      await settle();
      expect(feed.calls, 2);
      c.dispose();
      feed.release();
      await settle();
      expect(feed.calls, 2);
    });

    test('a blank query never sets isSearchingOlder', () async {
      final FakeFeed feed = FakeFeed(pages: 10);
      final ActivityLogController c = make(feed);
      await c.load();
      final List<ActivityLogState> seen = <ActivityLogState>[];
      c.addListener(seen.add, fireImmediately: false);
      c.changeQuery('   ');
      c.changeQuery('');
      c.changeCategory('me');
      await c.load();
      await settle();
      expect(seen.any((s) => s.isSearchingOlder), isFalse);
      expect(feed.calls, 2, reason: 'initial load + the explicit reload');
      c.dispose();
    });
  });

  group('triggers', () {
    test('changeCategory leaving no match starts the loop', () async {
      final FakeFeed feed = FakeFeed(pages: 10, needlePage: 2);
      final ActivityLogController c = make(feed);
      await c.load();
      c.changeCategory('me'); // no query yet: no loop
      await settle();
      expect(feed.calls, 1);
      c.changeCategory('all');
      // Query typed while a category would match nothing loaded.
      c.changeQuery('row 1');
      await settle();
      final int before = feed.calls;
      expect(c.state.filteredActivities, isNotEmpty);
      c.changeCategory('me');
      expect(c.state.isSearchingOlder, isTrue);
      await settle();
      expect(feed.calls, greaterThan(before));
      expect(c.state.isSearchingOlder, isFalse);
      c.dispose();
    });

    test('first load with an active query and no match starts it', () async {
      final FakeFeed feed = FakeFeed(pages: 10, needlePage: 2);
      final ActivityLogController c = make(feed);
      c.changeQuery('needle');
      await settle();
      expect(feed.calls, 0, reason: 'nothing loaded yet: load() drives it');
      await c.load();
      await settle();
      expect(feed.calls, 3);
      expect(c.state.filteredActivities.map((e) => e.id), <String>['e100']);
      expect(c.state.isSearchingOlder, isFalse);
      c.dispose();
    });
  });
}
