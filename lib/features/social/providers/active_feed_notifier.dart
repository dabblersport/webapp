import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'active_item.dart';

export 'active_item.dart';

// =============================================================================
// ACTIVE FEED STATE
// =============================================================================

/// Active feed state as a sealed union. [ActiveFeedData] is the loaded steady
/// state. Base getters keep widget read sites stable.
sealed class ActiveFeedState {
  const ActiveFeedState();

  List<ActiveItem> get events => const [];
  bool get isLoading => false;
  bool get isLoadingMore => false;
  bool get hasMore => false;
  String? get error => null;
}

final class ActiveFeedLoading extends ActiveFeedState {
  const ActiveFeedLoading();

  @override
  bool get isLoading => true;
  @override
  bool get hasMore => true;
}

final class ActiveFeedFailure extends ActiveFeedState {
  const ActiveFeedFailure(this.message);

  final String message;

  @override
  String? get error => message;
}

final class ActiveFeedData extends ActiveFeedState {
  const ActiveFeedData({
    required this.events,
    this.hasMore = true,
    this.loadingMore = false,
  });

  @override
  final List<ActiveItem> events;
  @override
  final bool hasMore;

  final bool loadingMore;
  @override
  bool get isLoadingMore => loadingMore;

  ActiveFeedData copyWith({
    List<ActiveItem>? events,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ActiveFeedData(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

// =============================================================================
// ACTIVE FEED NOTIFIER
// =============================================================================

/// KAN-957: the Home Active tab, read from the `active_stream` RPC. The
/// server filters by [ActiveFilter] (event types and city) and pages by the
/// last row's (event_at, event_type, entity_id).
///
/// NOT autoDispose — caches across tab switches.
class ActiveFeedNotifier extends StateNotifier<ActiveFeedState> {
  /// [cache] / [accountId] (KAN-605): the unfiltered first page is shown from
  /// the on-device cache at once; [load] refreshes it.
  ActiveFeedNotifier(
    this._db, {
    bool autoLoad = false,
    OfflineCache? cache,
    String? accountId,
    ActiveFilter Function()? filter,
  }) : _cache = cache,
       _accountId = accountId,
       _filter = filter ?? (() => const ActiveFilter()),
       super(const ActiveFeedLoading()) {
    _hydrated = _hydrate();
    if (autoLoad) ensureLoaded();
  }

  final SupabaseClient _db;
  final OfflineCache? _cache;
  final String? _accountId;
  final ActiveFilter Function() _filter;
  static const String _cacheKey = 'feed.active.stream';
  late final Future<void> _hydrated;
  bool _networkLoaded = false;

  static const int _pageSize = 20;
  // First page fills to about a screenful, at most 4 extra pages (KAN-955).
  static const int _firstPageFill = 10;
  static const int _firstPageWalkCap = 4;

  /// Bumped by every [load]; an answer to an older load is dropped.
  int _generation = 0;

  bool get _cacheOn => _cache != null && _accountId != null;

  Future<void> _hydrate() async {
    if (!_cacheOn || _filter().isActive) return;
    final hit = await _cache!.read(_accountId!, _cacheKey);
    if (hit == null || !mounted || state is ActiveFeedData) return;
    try {
      final events = <ActiveItem>[
        for (final j in (hit.payload as List))
          ?ActiveItem.fromRow(Map<String, dynamic>.from(j as Map)),
      ];
      if (events.isEmpty) return;
      state = ActiveFeedData(
        events: events,
        hasMore: events.length >= _pageSize,
      );
    } catch (_) {
      // A cached shape that no longer parses is the same as no cache.
    }
  }

  /// Loads the first page only if not yet loaded.
  Future<void> ensureLoaded() async {
    await _hydrated;
    if (_networkLoaded) return;
    if (state is ActiveFeedData && !_cacheOn) return;
    await load();
  }

  /// The filters changed: the rows on screen belong to the old ones, so the
  /// list goes back to its skeleton and reloads.
  Future<void> refilter() async {
    if (!mounted) return;
    state = const ActiveFeedLoading();
    await load();
  }

  /// Force-reload from the first page. A reload over rows keeps them on
  /// screen while it runs and when it fails (KAN-605).
  Future<void> load() async {
    if (!mounted) return;
    final generation = ++_generation;
    final filter = _filter();
    if (state is! ActiveFeedData) state = const ActiveFeedLoading();

    final started = DateTime.now();
    final first = await _fetch(filter, after: null);
    if (!mounted || generation != _generation) return;

    if (first case Err(error: final err)) {
      if (state is! ActiveFeedData) state = ActiveFeedFailure(err.message);
      return;
    }
    final page = (first as Ok<_ActivePage, Failure>).value;
    final events = [...page.items];
    var hasMore = page.raw >= _pageSize;
    // KAN-955: a full page can lose rows that do not parse and leave a list
    // too short to scroll; read on until about a screenful is there.
    for (
      var walk = 0;
      walk < _firstPageWalkCap &&
          hasMore &&
          events.isNotEmpty &&
          events.length < _firstPageFill;
      walk++
    ) {
      final next = await _fetch(filter, after: events.last);
      if (!mounted || generation != _generation) return;
      if (next is! Ok<_ActivePage, Failure>) break;
      final seen = events.map((e) => e.id).toSet();
      events.addAll(next.value.items.where((e) => !seen.contains(e.id)));
      hasMore = next.value.raw >= _pageSize;
    }

    _networkLoaded = true;
    state = ActiveFeedData(events: events, hasMore: hasMore);
    if (_cacheOn && !filter.isActive) {
      _cache!.write(_accountId!, _cacheKey, [
        for (final e in events) e.toRow(),
      ], requestStartedAt: started);
    }
  }

  /// Appends the next page, keyed on the last row.
  Future<void> loadMore() async {
    final data = state;
    if (data is! ActiveFeedData ||
        data.loadingMore ||
        !data.hasMore ||
        data.events.isEmpty ||
        !mounted) {
      return;
    }
    final generation = _generation;
    state = data.copyWith(loadingMore: true);
    final result = await _fetch(_filter(), after: data.events.last);
    if (!mounted || generation != _generation) return;

    final current = state;
    if (current is! ActiveFeedData) return;

    result.fold((_) => state = current.copyWith(loadingMore: false), (page) {
      final existing = current.events.map((e) => e.id).toSet();
      final fresh = page.items.where((e) => !existing.contains(e.id)).toList();
      state = current.copyWith(
        events: [...current.events, ...fresh],
        loadingMore: false,
        hasMore: page.raw >= _pageSize && fresh.isNotEmpty,
      );
    });
  }

  Future<Result<_ActivePage, Failure>> _fetch(
    ActiveFilter filter, {
    required ActiveItem? after,
  }) => Result.guard(() async {
    final rows = await _db
        .rpc(
          SupabaseConfig.activeStreamRpc,
          params: <String, dynamic>{
            'p_event_types': filter.type?.eventTypes,
            'p_city': filter.city,
            'p_limit': _pageSize,
            'p_before': after?.eventAt.toUtc().toIso8601String(),
            'p_before_type': after?.eventType,
            'p_before_entity': after?.entityId,
          },
        )
        .timeout(kRequestTimeout);
    final list = rows as List<dynamic>;
    return (
      raw: list.length,
      items: <ActiveItem>[
        for (final r in list)
          ?ActiveItem.fromRow(Map<String, dynamic>.from(r as Map)),
      ],
    );
  }, (e) => Failure.from(e));
}

/// One RPC page: the rows that parsed, and how many the server sent (which
/// is what says whether another page exists).
typedef _ActivePage = ({int raw, List<ActiveItem> items});

// =============================================================================
// PROVIDERS
// =============================================================================

/// The Active tab's filters. Not autoDispose: they persist across tab
/// switches until "Reset filters".
final activeFilterProvider = StateProvider<ActiveFilter>(
  (ref) => const ActiveFilter(),
);

final activeFeedProvider =
    StateNotifierProvider<ActiveFeedNotifier, ActiveFeedState>((ref) {
      final notifier = ActiveFeedNotifier(
        Supabase.instance.client,
        autoLoad: false,
        cache: ref.watch(offlineCacheProvider),
        accountId: ref.watch(cacheAccountIdProvider),
        filter: () => ref.read(activeFilterProvider),
      );
      ref.listen<ActiveFilter>(activeFilterProvider, (prev, next) {
        if (prev != next) notifier.refilter();
      });
      return notifier;
    });
