import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/data/repositories/public_activity_repository.dart';
import 'package:dabbler/features/activities/data/datasources/activity_feed_datasource.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/domain/activity_log_merge.dart';

/// State of the Home bell → Activity log (KAN-852).
///
/// [activities] is the merged, de-duplicated, newest-first list of both
/// sources. Each source keeps its own paging and its own error, so one failing
/// never hides the other's rows.
class ActivityLogState {
  const ActivityLogState({
    this.activities = const <ActivityFeedEvent>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSearchingOlder = false,
    this.loaded = false,
    this.feedError,
    this.socialError,
    this.category = 'all',
    this.query = '',
    this.feedCursor,
    this.feedHasMore = true,
    this.socialOffset = 0,
    this.socialHasMore = true,
  });

  final List<ActivityFeedEvent> activities;
  final bool isLoading;
  final bool isLoadingMore;

  /// KAN-875: true only while the search loop is loading older pages for a
  /// query with no match. Separate from [isLoadingMore].
  final bool isSearchingOlder;

  /// True once a first load has finished (whatever its outcome).
  final bool loaded;
  final String? feedError;
  final String? socialError;
  final String category;

  /// KAN-874: the search text, applied after [category]. Blank = no search.
  final String query;
  final DateTime? feedCursor;
  final bool feedHasMore;
  final int socialOffset;
  final bool socialHasMore;

  String? get error => feedError ?? socialError;
  bool get hasMore => feedHasMore || socialHasMore;

  /// Category first, then search. [activities] stays the full list, so the
  /// Last 7 days statistics (read from it) never see the query.
  List<ActivityFeedEvent> get filteredActivities =>
      searchActivityLog(filterActivityLog(activities, category), query);

  /// A genuinely empty log: every source answered, and answered nothing.
  bool get isEmpty => loaded && error == null && activities.isEmpty;

  static const Object _keep = Object();

  ActivityLogState copyWith({
    List<ActivityFeedEvent>? activities,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSearchingOlder,
    bool? loaded,
    Object? feedError = _keep,
    Object? socialError = _keep,
    String? category,
    String? query,
    Object? feedCursor = _keep,
    bool? feedHasMore,
    int? socialOffset,
    bool? socialHasMore,
  }) => ActivityLogState(
    activities: activities ?? this.activities,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isSearchingOlder: isSearchingOlder ?? this.isSearchingOlder,
    loaded: loaded ?? this.loaded,
    feedError: identical(feedError, _keep)
        ? this.feedError
        : feedError as String?,
    socialError: identical(socialError, _keep)
        ? this.socialError
        : socialError as String?,
    category: category ?? this.category,
    query: query ?? this.query,
    feedCursor: identical(feedCursor, _keep)
        ? this.feedCursor
        : feedCursor as DateTime?,
    feedHasMore: feedHasMore ?? this.feedHasMore,
    socialOffset: socialOffset ?? this.socialOffset,
    socialHasMore: socialHasMore ?? this.socialHasMore,
  );
}

class ActivityLogController extends StateNotifier<ActivityLogState> {
  ActivityLogController({
    required ActivityFeedDatasource feed,
    required PublicActivityRepository social,
    required Future<String?> Function() profileId,
  }) : _feed = feed,
       _social = social,
       _profileId = profileId,
       super(const ActivityLogState());

  final ActivityFeedDatasource _feed;
  final PublicActivityRepository _social;
  final Future<String?> Function() _profileId;

  static const int feedPageSize = 50;
  static const int socialPageSize = 20;

  /// KAN-875: most loadMore() pages one search loop run may request.
  static const int searchOlderPageCap = 20;

  /// Bumped to cancel a running search loop; a loop whose token no longer
  /// matches never writes state again.
  int _searchGen = 0;

  /// The loadMore() the search loop is awaiting, so a fresh loop can wait for
  /// it instead of seeing isLoadingMore and stopping.
  Future<void>? _searchPage;

  /// First page of both sources. Also the Retry and pull-to-refresh action.
  Future<void> load() async {
    _searchGen++;
    state = ActivityLogState(
      isLoading: true,
      category: state.category,
      query: state.query,
    );
    final results = await Future.wait(<Future<_Page>>[
      _fetchFeed(null),
      _fetchSocial(0),
    ]);
    if (!mounted) return;
    _apply(results[0], results[1], const <ActivityFeedEvent>[]);
    state = state.copyWith(isLoading: false, loaded: true);
    if (_queryHasNoMatch) unawaited(_searchOlder());
  }

  Future<void> refresh() => load();

  /// Next page of every source that still has one. A source that failed on
  /// its first page is retried from the start.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    final ActivityLogState s = state;
    final results = await Future.wait(<Future<_Page>>[
      s.feedHasMore ? _fetchFeed(s.feedCursor) : Future.value(_Page.done()),
      s.socialHasMore
          ? _fetchSocial(s.socialOffset)
          : Future.value(_Page.done()),
    ]);
    if (!mounted) return;
    _apply(results[0], results[1], s.activities);
    state = state.copyWith(isLoadingMore: false);
    // A query may have started while this independently requested page was
    // in flight. Resume its search once the page has finished.
    if (!state.isSearchingOlder && _queryHasNoMatch && state.error == null) {
      unawaited(_searchOlder());
    }
  }

  /// Selects a chip. `all` restores the full list.
  void changeCategory(String? category) {
    state = state.copyWith(category: category ?? 'all');
    if (!state.isSearchingOlder && _queryHasNoMatch) {
      unawaited(_searchOlder());
    }
  }

  /// KAN-874: sets the search text. The category is kept.
  void changeQuery(String query) {
    _searchGen++;
    state = state.copyWith(query: query, isSearchingOlder: false);
    if (_queryHasNoMatch) unawaited(_searchOlder());
  }

  @override
  void dispose() {
    _searchGen++;
    super.dispose();
  }

  /// KAN-875: an active (non-blank) query whose category + search result is
  /// empty on a log that has finished its first load.
  bool get _queryHasNoMatch =>
      state.loaded &&
      state.query.trim().isNotEmpty &&
      state.filteredActivities.isEmpty;

  /// KAN-875: loads older pages through [loadMore] while the active query has
  /// no match, at most [searchOlderPageCap] pages per run. Ends on a match,
  /// on `!hasMore`, on an error (which [loadMore] has already surfaced), or on
  /// cancellation (a new [_searchGen]); a cancelled run never writes state.
  Future<void> _searchOlder() async {
    final int gen = ++_searchGen;
    bool live() => mounted && gen == _searchGen;
    state = state.copyWith(isSearchingOlder: true);
    int pages = 0;
    while (pages < searchOlderPageCap) {
      final Future<void>? inFlight = _searchPage;
      if (inFlight != null) await inFlight;
      if (!live()) return;
      if (!_queryHasNoMatch || !state.hasMore || state.error != null) break;
      // A load or an outside loadMore is running: loadMore() would no-op.
      if (state.isLoading || state.isLoadingMore) break;
      final Future<void> page = loadMore();
      _searchPage = page;
      pages++;
      await page;
      if (identical(_searchPage, page)) _searchPage = null;
      if (!live()) return;
      if (state.error != null) break;
    }
    state = state.copyWith(isSearchingOlder: false);
  }

  void _apply(_Page feed, _Page social, List<ActivityFeedEvent> existing) {
    final List<ActivityFeedEvent> merged = mergeActivityLog(
      existing,
      <ActivityFeedEvent>[...feed.items, ...social.items],
    );
    state = state.copyWith(
      activities: merged,
      feedError: feed.error,
      socialError: social.error,
      feedHasMore: feed.hasMore,
      socialHasMore: social.hasMore,
      feedCursor: feed.cursor ?? state.feedCursor,
      socialOffset: state.socialOffset + social.rawCount,
    );
  }

  Future<_Page> _fetchFeed(DateTime? cursor) async {
    final Result<List<ActivityFeedEvent>, Failure> r = await Result.guard(
      () => _feed.getActivityFeed(
        period: 'all',
        limit: feedPageSize,
        cursor: cursor,
      ),
      (e) => Failure.from(e),
    );
    return r.fold((f) => _Page.failed(f.message), (items) {
      // The RPC filters `happened_at < cursor`, so the next cursor is the
      // oldest timestamp seen — not the last row, which the RPC orders by
      // time bucket first.
      DateTime? oldest;
      for (final ActivityFeedEvent e in items) {
        if (oldest == null || e.happenedAt.isBefore(oldest)) {
          oldest = e.happenedAt;
        }
      }
      return _Page(
        items: items,
        hasMore: items.length >= feedPageSize,
        cursor: oldest,
        rawCount: items.length,
      );
    });
  }

  Future<_Page> _fetchSocial(int offset) async {
    final Result<String?, Failure> id = await Result.guard(
      _profileId,
      (e) => Failure.from(e),
    );
    if (id is Err<String?, Failure>) return _Page.failed(id.error.message);
    final String? profileId = (id as Ok<String?, Failure>).value;
    if (profileId == null) return _Page.done();
    final Result<List<PublicActivity>, Failure> r = await _social
        .fetchUserActivities(
          profileId: profileId,
          limit: socialPageSize,
          offset: offset,
        );
    return r.fold(
      (f) => _Page.failed(f.message),
      (items) => _Page(
        items: items.map(activityFromPublic).toList(),
        hasMore: items.length >= socialPageSize,
        rawCount: items.length,
      ),
    );
  }
}

class _Page {
  const _Page({
    this.items = const <ActivityFeedEvent>[],
    this.hasMore = false,
    this.error,
    this.cursor,
    this.rawCount = 0,
  });

  factory _Page.failed(String message) => _Page(error: message, hasMore: true);

  /// A source with nothing (more) to fetch.
  factory _Page.done() => const _Page();

  final List<ActivityFeedEvent> items;
  final bool hasMore;
  final String? error;
  final DateTime? cursor;
  final int rawCount;
}
