import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

// =============================================================================
// ACTIVE FEED STATE
// =============================================================================

/// Represents one event from the `v_active_feed` view.
///
/// The raw map is preserved so that each event card can access all fields,
/// including custom columns specific to each [eventType].
class ActiveEvent {
  const ActiveEvent(this.data);
  final Map<String, dynamic> data;

  String get id => data['id']?.toString() ?? '';
  String get eventType => data['event_type']?.toString() ?? '';
  DateTime get createdAt {
    final raw = data['created_at'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  // Convenience accessors used across cards.
  int get joinCount => (data['join_count'] as num?)?.toInt() ?? 0;
  String? get gameId => data['game_id']?.toString();
  String? get postId => data['post_id']?.toString();
  String? get userId => data['user_id']?.toString();
  String? get profileId => data['profile_id']?.toString();
  String? get displayName => data['display_name']?.toString();
  String? get avatarUrl => data['avatar_url']?.toString();
  String? get gameTitle => data['game_title']?.toString();
  String? get sport => data['sport']?.toString();
  String? get venueName => data['venue_name']?.toString();
  String? get body => data['body']?.toString();
  double? get score => (data['score'] as num?)?.toDouble();
  Map<String, dynamic>? get metadata {
    final raw = data['metadata'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}

// =============================================================================

class ActiveFeedState {
  const ActiveFeedState({
    this.events = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loaded = false,
  });

  final List<ActiveEvent> events;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final bool loaded;

  ActiveFeedState copyWith({
    List<ActiveEvent>? events,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _sentinel,
    bool? loaded,
  }) {
    return ActiveFeedState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
      loaded: loaded ?? this.loaded,
    );
  }

  static const Object _sentinel = Object();
}

// =============================================================================
// ACTIVE FEED NOTIFIER
// =============================================================================

/// Manages paginated, cached data from the `v_active_feed` Supabase view.
///
/// Events are sorted by score DESC. Does NOT mix with the Post feed logic.
/// NOT autoDispose — caches across tab switches.
class ActiveFeedNotifier extends StateNotifier<ActiveFeedState> {
  ActiveFeedNotifier(this._db, {bool autoLoad = false})
    : super(const ActiveFeedState()) {
    if (autoLoad) ensureLoaded();
  }

  final SupabaseClient _db;
  static const int _pageSize = 20;
  int _activePage = 0;

  /// Loads the first page only if not yet loaded.
  Future<void> ensureLoaded() async {
    if (state.loaded) return;
    await load();
  }

  /// Force-reload from first page.
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    _activePage = 0;

    final result = await _fetch(limit: _pageSize, offset: 0);
    if (!mounted) return;

    result.fold(
      (err) => state = state.copyWith(isLoading: false, error: err.message),
      (events) => state = state.copyWith(
        events: events,
        isLoading: false,
        hasMore: events.length >= _pageSize,
        loaded: true,
      ),
    );
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || !mounted) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = _activePage + 1;

    final result = await _fetch(limit: _pageSize, offset: nextPage * _pageSize);
    if (!mounted) return;

    result.fold((_) => state = state.copyWith(isLoadingMore: false), (
      newEvents,
    ) {
      if (newEvents.isEmpty) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }
      _activePage = nextPage;
      final existingIds = state.events.map((e) => e.id).toSet();
      final deduped = newEvents
          .where((e) => !existingIds.contains(e.id))
          .toList();
      state = state.copyWith(
        events: [...state.events, ...deduped],
        isLoadingMore: false,
        hasMore: newEvents.length >= _pageSize && deduped.isNotEmpty,
      );
    });
  }

  Future<Result<List<ActiveEvent>, Failure>> _fetch({
    required int limit,
    required int offset,
  }) async {
    try {
      final rows = await _db
          .from('v_game_card')
          .select(
            'id, title, sport_name_en, start_at, venue_name, area_name, '
            'roster_count, capacity, creator_display_name, creator_avatar_url, created_at',
          )
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final events = (rows as List<dynamic>).map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        return ActiveEvent({
          'id': row['id'],
          'event_type': 'game_created',
          'created_at': row['created_at'],
          'game_id': row['id'],
          'game_title': row['title'],
          'sport': row['sport_name_en'],
          'venue_name': row['venue_name'] ?? row['area_name'],
          'join_count': row['roster_count'] ?? 0,
          'display_name': row['creator_display_name'],
          'avatar_url': row['creator_avatar_url'],
          'score': 0.0,
        });
      }).toList();

      return Ok(events);
    } catch (e) {
      return Err(Failure(message: e.toString()));
    }
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

final activeFeedProvider =
    StateNotifierProvider<ActiveFeedNotifier, ActiveFeedState>((ref) {
      return ActiveFeedNotifier(Supabase.instance.client, autoLoad: false);
    });
