import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

// =============================================================================
// ACTIVE FEED STATE
// =============================================================================

/// One event from the active feed, modelled as a sealed union so each card
/// receives a typed payload and the card router switch is exhaustive.
///
/// Construct from a raw row via [ActiveEvent.fromRow], which reads `event_type`
/// once and dispatches to the matching variant. Returns `null` for an unknown
/// or malformed event type (the caller filters these out).
sealed class ActiveEvent {
  const ActiveEvent({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  static DateTime _parseCreatedAt(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  static ActiveEvent? fromRow(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final createdAt = _parseCreatedAt(data['created_at']);
    String? str(String key) => data[key]?.toString();

    switch (data['event_type']?.toString()) {
      case 'game_created':
        return GameCreatedEvent(
          id: id,
          createdAt: createdAt,
          gameId: str('game_id'),
          gameTitle: str('game_title'),
          sport: str('sport'),
          venueName: str('venue_name'),
        );
      case 'player_joined_game':
        final avatarUrls = <String>[];
        final meta = data['metadata'];
        if (meta is Map && meta['user_avatars'] is List) {
          for (final u in meta['user_avatars'] as List) {
            if (u is String && u.isNotEmpty) avatarUrls.add(u);
          }
        }
        return PlayerJoinedEvent(
          id: id,
          createdAt: createdAt,
          gameId: str('game_id'),
          gameTitle: str('game_title'),
          sport: str('sport'),
          venueName: str('venue_name'),
          joinCount: (data['join_count'] as num?)?.toInt() ?? 0,
          avatarUrls: avatarUrls,
        );
      case 'post_created':
        return PostCreatedEvent(
          id: id,
          createdAt: createdAt,
          postId: str('post_id'),
        );
      case 'user_joined':
        return NewUserEvent(
          id: id,
          createdAt: createdAt,
          profileId: str('profile_id'),
          displayName: str('display_name'),
          avatarUrl: str('avatar_url'),
          sport: str('sport'),
        );
      default:
        return null;
    }
  }
}

/// `game_created` — a newly created game (Discovery card).
final class GameCreatedEvent extends ActiveEvent {
  const GameCreatedEvent({
    required super.id,
    required super.createdAt,
    this.gameId,
    this.gameTitle,
    this.sport,
    this.venueName,
  });

  final String? gameId;
  final String? gameTitle;
  final String? sport;
  final String? venueName;
}

/// `player_joined_game` — one or more players joined a game (Live card).
///
/// NOTE: not yet produced by [ActiveFeedNotifier._fetch] (see its comment).
final class PlayerJoinedEvent extends ActiveEvent {
  const PlayerJoinedEvent({
    required super.id,
    required super.createdAt,
    this.gameId,
    this.gameTitle,
    this.sport,
    this.venueName,
    this.joinCount = 0,
    this.avatarUrls = const [],
  });

  final String? gameId;
  final String? gameTitle;
  final String? sport;
  final String? venueName;
  final int joinCount;
  final List<String> avatarUrls;
}

/// `post_created` — a new social post (rendered via the real Post layout).
///
/// NOTE: not yet produced by [ActiveFeedNotifier._fetch].
final class PostCreatedEvent extends ActiveEvent {
  const PostCreatedEvent({
    required super.id,
    required super.createdAt,
    this.postId,
  });

  final String? postId;
}

/// `user_joined` — a new user joined the platform (welcome chip).
///
/// NOTE: not yet produced by [ActiveFeedNotifier._fetch].
final class NewUserEvent extends ActiveEvent {
  const NewUserEvent({
    required super.id,
    required super.createdAt,
    this.profileId,
    this.displayName,
    this.avatarUrl,
    this.sport,
  });

  final String? profileId;
  final String? displayName;
  final String? avatarUrl;
  final String? sport;
}

// =============================================================================

/// Active feed state as a sealed union — illegal flag combinations are
/// unrepresentable. [ActiveFeedData] is the loaded steady state (its presence
/// is what `loaded` used to mean). Base getters keep widget read sites stable.
sealed class ActiveFeedState {
  const ActiveFeedState();

  List<ActiveEvent> get events => const [];
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
  final List<ActiveEvent> events;
  @override
  final bool hasMore;

  final bool loadingMore;
  @override
  bool get isLoadingMore => loadingMore;

  ActiveFeedData copyWith({
    List<ActiveEvent>? events,
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

/// Manages paginated, cached data from the `v_active_feed` Supabase view.
///
/// Events are sorted by score DESC. Does NOT mix with the Post feed logic.
/// NOT autoDispose — caches across tab switches.
class ActiveFeedNotifier extends StateNotifier<ActiveFeedState> {
  ActiveFeedNotifier(this._db, {bool autoLoad = false})
    : super(const ActiveFeedLoading()) {
    if (autoLoad) ensureLoaded();
  }

  final SupabaseClient _db;
  static const int _pageSize = 20;
  int _activePage = 0;

  /// Loads the first page only if not yet loaded.
  Future<void> ensureLoaded() async {
    if (state is ActiveFeedData) return;
    await load();
  }

  /// Force-reload from first page.
  Future<void> load() async {
    if (!mounted) return;
    state = const ActiveFeedLoading();
    _activePage = 0;

    final result = await _fetch(limit: _pageSize, offset: 0);
    if (!mounted) return;

    result.fold(
      (err) => state = ActiveFeedFailure(err.message),
      (events) => state = ActiveFeedData(
        events: events,
        hasMore: events.length >= _pageSize,
      ),
    );
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    final data = state;
    if (data is! ActiveFeedData || data.loadingMore || !data.hasMore ||
        !mounted) {
      return;
    }

    state = data.copyWith(loadingMore: true);
    final nextPage = _activePage + 1;

    final result = await _fetch(limit: _pageSize, offset: nextPage * _pageSize);
    if (!mounted) return;

    final current = state;
    if (current is! ActiveFeedData) return;

    result.fold((_) => state = current.copyWith(loadingMore: false), (
      newEvents,
    ) {
      if (newEvents.isEmpty) {
        state = current.copyWith(hasMore: false, loadingMore: false);
        return;
      }
      _activePage = nextPage;
      final existingIds = current.events.map((e) => e.id).toSet();
      final deduped = newEvents
          .where((e) => !existingIds.contains(e.id))
          .toList();
      state = current.copyWith(
        events: [...current.events, ...deduped],
        loadingMore: false,
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
          .from(SupabaseConfig.vGameCardTable)
          .select(
            'id, title, sport_name_en, start_at, venue_name, area_name, '
            'roster_count, capacity, creator_display_name, creator_avatar_url, created_at',
          )
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Only `game_created` events are produced today — this notifier queries
      // `v_game_card`. The other ActiveEvent variants exist for when the feed
      // emits richer event types; construct GameCreatedEvent directly here.
      final events = (rows as List<dynamic>).map<ActiveEvent>((r) {
        final row = Map<String, dynamic>.from(r as Map);
        return GameCreatedEvent(
          id: row['id']?.toString() ?? '',
          createdAt: ActiveEvent._parseCreatedAt(row['created_at']),
          gameId: row['id']?.toString(),
          gameTitle: row['title']?.toString(),
          sport: row['sport_name_en']?.toString(),
          venueName: (row['venue_name'] ?? row['area_name'])?.toString(),
        );
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
