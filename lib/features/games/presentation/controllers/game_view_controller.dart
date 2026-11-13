import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/features/games/presentation/controllers/join_action_toast.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/core/utils/instant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class GameRosterEntry {
  const GameRosterEntry({
    required this.profileId,
    required this.userId,
    required this.role,
    required this.displayName,
    this.avatarUrl,
    this.username,
  });

  final String profileId;
  final String userId;
  final String role; // host | player | sub | spectator
  final String displayName;
  final String? avatarUrl;
  final String? username;

  bool get isHost => role == 'host';

  factory GameRosterEntry.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>? ?? {};
    return GameRosterEntry(
      profileId: j['profile_id'] as String,
      userId: j['user_id'] as String,
      role: j['role'] as String? ?? 'player',
      displayName:
          profile['display_name'] as String? ??
          profile['username'] as String? ??
          'Player',
      avatarUrl: profile['avatar_url'] as String?,
      username: profile['username'] as String?,
    );
  }
}

class GameWaitlistEntry {
  const GameWaitlistEntry({
    required this.profileId,
    required this.userId,
    required this.position,
    required this.displayName,
    this.avatarUrl,
  });

  final String profileId;
  final String userId;
  final int position;
  final String displayName;
  final String? avatarUrl;

  factory GameWaitlistEntry.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>? ?? {};
    return GameWaitlistEntry(
      profileId: j['profile_id'] as String,
      userId: j['user_id'] as String,
      position: j['position'] as int? ?? 0,
      displayName:
          profile['display_name'] as String? ??
          profile['username'] as String? ??
          'Player',
      avatarUrl: profile['avatar_url'] as String?,
    );
  }
}

class GameJoinRequestEntry {
  const GameJoinRequestEntry({
    required this.id,
    required this.profileId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.username,
  });

  final String id;
  final String profileId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? username;

  factory GameJoinRequestEntry.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>? ?? {};
    return GameJoinRequestEntry(
      id: j['id'] as String,
      profileId: j['from_profile_id'] as String,
      userId: j['from_user_id'] as String,
      displayName:
          profile['display_name'] as String? ??
          profile['username'] as String? ??
          'Player',
      avatarUrl: profile['avatar_url'] as String?,
      username: profile['username'] as String?,
    );
  }
}

class GameView {
  const GameView({
    required this.id,
    required this.title,
    required this.gameType,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.benchSlots,
    required this.totalSlots,
    required this.rosterCount,
    required this.listingVisibility,
    required this.joinPolicy,
    required this.allowSpectators,
    required this.allowsWaitlist,
    required this.isCancelled,
    required this.joiningRule,
    required this.costCover,
    this.minSkill,
    this.maxSkill,
    this.rules = const {},
    this.sportId,
    this.sportKey,
    this.sportNameEn,
    this.variantNameEn,
    this.creatorProfileId,
    this.creatorUsername,
    this.creatorDisplayName,
    this.creatorAvatarUrl,
    this.areaName,
    this.venueName,
    this.venueSpaceName,
    this.venueId,
    this.seriesId,
    this.seriesFrequency,
    this.seriesEndsOn,
  });

  final String id;
  final String title;
  final String gameType;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final int benchSlots;
  final int totalSlots;
  final int rosterCount;
  final String listingVisibility;
  final String joinPolicy;
  final bool allowSpectators;
  final bool allowsWaitlist;
  final bool isCancelled;
  final String joiningRule;
  final String costCover;
  final int? minSkill;
  final int? maxSkill;
  final Map<String, dynamic> rules;
  final String? sportId;
  final String? sportKey;
  final String? sportNameEn;
  final String? variantNameEn;
  final String? creatorProfileId;
  final String? creatorUsername;
  final String? creatorDisplayName;
  final String? creatorAvatarUrl;
  final String? areaName;
  final String? venueName;
  final String? venueSpaceName;
  final String? venueId;

  /// KAN-698: set only for a game that belongs to a recurring series. Read from
  /// `v_game_card`, which any viewer of the card can see.
  final String? seriesId;

  /// `weekly` or `biweekly`; null for a one-off game.
  final String? seriesFrequency;
  final DateTime? seriesEndsOn;

  bool get isSeries => seriesId != null;

  int get spotsLeft => (capacity - rosterCount).clamp(0, capacity);
  bool get isFull => spotsLeft == 0;
  bool get isPublic => listingVisibility == 'public';
  bool get isFree => joiningRule == 'free';

  String get statusLabel {
    if (isCancelled) return 'Cancelled';
    final now = DateTime.now();
    if (startAt.isAfter(now)) return 'Upcoming';
    if (endAt.isAfter(now)) return 'Live';
    return 'Ended';
  }

  factory GameView.fromJson(Map<String, dynamic> j) {
    // KAN-927: timestamptz -> viewer-local.
    final startAt = parseInstantLocal(j['start_at'])!;
    final endAt = parseInstantLocal(j['end_at']);
    return GameView(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Untitled Game',
      gameType: j['game_type'] as String? ?? 'casual',
      startAt: startAt,
      // KAN-749: an events-backed row may carry no end yet.
      endAt: endAt ?? startAt,
      capacity: j['capacity'] as int? ?? 0,
      benchSlots: j['bench_slots'] as int? ?? 0,
      totalSlots: j['total_slots'] as int? ?? 0,
      rosterCount: j['roster_count'] as int? ?? 0,
      listingVisibility: j['listing_visibility'] as String? ?? 'public',
      joinPolicy: j['join_policy'] as String? ?? 'open',
      allowSpectators: j['allow_spectators'] as bool? ?? false,
      allowsWaitlist: j['allows_waitlist'] as bool? ?? false,
      isCancelled: j['is_cancelled'] as bool? ?? false,
      joiningRule: j['joining_rule'] as String? ?? 'free',
      costCover: j['cost_cover'] as String? ?? 'free',
      minSkill: j['min_skill'] as int?,
      maxSkill: j['max_skill'] as int?,
      rules: j['rules'] as Map<String, dynamic>? ?? {},
      sportId: j['sport_id'] as String?,
      sportKey: j['sport_key'] as String?,
      sportNameEn: j['sport_name_en'] as String?,
      variantNameEn: j['variant_name_en'] as String?,
      creatorProfileId: j['creator_profile_id'] as String?,
      creatorUsername: j['creator_username'] as String?,
      creatorDisplayName: j['creator_display_name'] as String?,
      creatorAvatarUrl: j['creator_avatar_url'] as String?,
      areaName: j['area_name'] as String?,
      venueName: j['venue_name'] as String?,
      venueSpaceName: j['venue_space_name'] as String?,
      venueId: j['venue_id'] as String?,
      seriesId: j['series_id'] as String?,
      seriesFrequency: j['series_frequency'] as String?,
      seriesEndsOn: j['series_ends_on'] == null
          ? null
          : DateTime.parse(j['series_ends_on'] as String),
    );
  }
}

// ─── Join action result ────────────────────────────────────────────────────

enum JoinActionResult {
  joined,
  waitlisted,
  requestSubmitted,
  left,
  cancelledRequest,
}

// ─── State ────────────────────────────────────────────────────────────────────

class GameViewState {
  const GameViewState({
    this.game,
    this.roster = const [],
    this.waitlist = const [],
    this.pendingRequests = const [],
    this.hasPendingRequest = false,
    this.isLoading = false,
    this.isActing = false,
    this.error,
    this.lastAction,
  });

  final GameView? game;
  final List<GameRosterEntry> roster;
  final List<GameWaitlistEntry> waitlist;

  /// Pending join requests — RLS returns all of them to the host, and only
  /// the viewer's own row to everyone else.
  final List<GameJoinRequestEntry> pendingRequests;
  final bool hasPendingRequest;
  final bool isLoading;
  final bool isActing;
  final String? error;
  final JoinActionResult? lastAction;

  bool get hasGame => game != null;

  GameViewState copyWith({
    GameView? game,
    List<GameRosterEntry>? roster,
    List<GameWaitlistEntry>? waitlist,
    List<GameJoinRequestEntry>? pendingRequests,
    bool? hasPendingRequest,
    bool? isLoading,
    bool? isActing,
    String? error,
    JoinActionResult? lastAction,
    bool clearError = false,
    bool clearAction = false,
  }) {
    return GameViewState(
      game: game ?? this.game,
      roster: roster ?? this.roster,
      waitlist: waitlist ?? this.waitlist,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
      isLoading: isLoading ?? this.isLoading,
      isActing: isActing ?? this.isActing,
      error: clearError ? null : error ?? this.error,
      lastAction: clearAction ? null : lastAction ?? this.lastAction,
    );
  }
}

// ─── Realtime seam ────────────────────────────────────────────────────────────

/// One postgres-change listener: every change on [table] whose [column]
/// equals the game id.
typedef GameViewListener = ({String table, String column});

/// Opens/closes the game view's realtime channel. Production uses
/// [SupabaseGameViewRealtime]; tests inject a recorder (KAN-749).
abstract class GameViewRealtime {
  Object open(
    String channelName,
    List<GameViewListener> listeners,
    String value,
    void Function() onChange,
  );

  Future<void> close(Object channel);
}

class SupabaseGameViewRealtime implements GameViewRealtime {
  const SupabaseGameViewRealtime(this._db);
  final SupabaseClient _db;

  @override
  Object open(
    String channelName,
    List<GameViewListener> listeners,
    String value,
    void Function() onChange,
  ) {
    final channel = _db.channel(channelName);
    for (final l in listeners) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: l.table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: l.column,
          value: value,
        ),
        // The payload is ignored: a change only triggers a reload.
        callback: (_) => onChange(),
      );
    }
    return channel..subscribe();
  }

  @override
  Future<void> close(Object channel) =>
      _db.removeChannel(channel as RealtimeChannel);
}

// ─── Controller ───────────────────────────────────────────────────────────────

class GameViewController extends StateNotifier<GameViewState> {
  GameViewController({
    required SupabaseClient supabase,
    required this.gameId,
    required this.currentUserId,
    OfflineCache? cache,
    String? accountId,
    // Test seam only; production passes nothing.
    GameViewRealtime? realtime,
    AppLocalizations Function()? l10n,
  }) : _db = supabase,
       _l10n = l10n,
       _realtime = realtime ?? SupabaseGameViewRealtime(supabase),
       _cache = cache,
       _accountId = accountId,
       super(const GameViewState()) {
    _hydrate();
    _load();
    _subscribeToChanges();
  }

  final SupabaseClient _db;
  final GameViewRealtime _realtime;

  /// The app's strings in the current locale, for the join refusal copy
  /// (KAN-930). Null keeps the server's code as the error.
  final AppLocalizations Function()? _l10n;
  final String gameId;
  final String? currentUserId;

  /// KAN-939: the join-link token the viewer arrived with (`?lt=`), sent as
  /// `p_link_token` so a link-policy game can be joined. Set by the screen.
  String? linkToken;

  // KAN-605: a game the viewer opened is shown from the on-device cache first
  // and refreshed in the background.
  final OfflineCache? _cache;
  final String? _accountId;
  bool get _cacheOn => _cache != null && _accountId != null;
  String get _gameKey => 'game.detail.$gameId';
  String get _rosterKey => 'game.roster.$gameId';

  Future<void> _hydrate() async {
    if (!_cacheOn) return;
    final game = await _cache!.read(_accountId!, _gameKey);
    final roster = await _cache.read(_accountId, _rosterKey);
    if (!mounted || state.game != null || game == null) return;
    try {
      state = state.copyWith(
        game: GameView.fromJson(Map<String, dynamic>.from(game.payload as Map)),
        roster: roster == null
            ? null
            : [
                for (final r in (roster.payload as List))
                  GameRosterEntry.fromJson(Map<String, dynamic>.from(r as Map)),
              ],
      );
    } catch (_) {
      // A cached shape that no longer parses is the same as no cache.
    }
  }

  Object? _channel;
  Timer? _refreshDebounce;

  Future<void> refresh() => _load();

  /// Re-establish realtime and reload. The OS suspends websockets while the
  /// app is backgrounded, so changes made meanwhile (e.g. the host approving
  /// a join request) are silently missed — call this on app resume.
  Future<void> resync() async {
    final channel = _channel;
    if (channel != null) {
      _channel = null;
      await _realtime.close(channel);
    }
    if (!mounted) return;
    _subscribeToChanges();
    await _load();
  }

  /// Live-updates the screen when the game's event/game row, roster,
  /// waitlist, or join requests change. Realtime enforces each table's
  /// SELECT RLS per subscriber, so viewers only receive events for rows they
  /// can already read. Events just trigger a debounced reload — the payload
  /// is never read, and the fetch queries stay the single source of truth.
  /// A game's events row has `id == gameId` (KAN-711).
  void _subscribeToChanges() {
    if (!mounted) return;
    // KAN-749: one channel per controller — never stack a second one.
    final old = _channel;
    _channel = null;
    if (old != null) unawaited(_realtime.close(old));
    _channel = _realtime.open(
      'game_view_$gameId',
      const [
        (table: SupabaseConfig.gameRosterTable, column: 'game_id'),
        (table: SupabaseConfig.gameWaitlistTable, column: 'game_id'),
        (table: SupabaseConfig.gameJoinRequestsTable, column: 'game_id'),
        // KAN-864: no games entry. Every game field (capacity, skill, ...)
        // lives on events (KAN-710) and every games write routes its shared
        // values to events first (KAN-712), so the events entry covers edits.
        (table: SupabaseConfig.eventsTable, column: 'id'),
      ],
      gameId,
      _scheduleRealtimeRefresh,
    );
  }

  /// Coalesces bursts of change events (approve = request update + roster
  /// insert) into a single reload. A no-op once disposed.
  void _scheduleRealtimeRefresh() {
    if (!mounted) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(DabblerMotion.debounceSearch, () {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(_realtime.close(channel));
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await Future.wait([
        _fetchGame(),
        _fetchRoster(),
        _fetchWaitlist(),
        _fetchPendingRequests(),
      ]);
      await _checkPendingRequest();
    } finally {
      // KAN-749: a load that outlives the controller writes nothing.
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _fetchGame() async {
    final started = DateTime.now();
    try {
      final row =
          await _db
              .from(SupabaseConfig.vGameCardTable)
              .select()
              .eq('id', gameId)
              .maybeSingle()
              .timeout(kRequestTimeout) ??
          await _fetchGameByLink();
      if (row == null) throw StateError('game_not_visible');
      if (!mounted) return;
      state = state.copyWith(game: GameView.fromJson(row));
      if (_cacheOn) {
        _cache!.write(_accountId!, _gameKey, row, requestStartedAt: started);
      }
    } catch (e) {
      // KAN-605: a failed refresh behind cached data is silent.
      if (mounted && state.game == null) {
        state = state.copyWith(error: 'Failed to load game');
      }
    }
  }

  /// KAN-939: a link-policy game v_game_card hides from a non-member is read
  /// through the holder's token instead; null without a token or a valid one.
  Future<Map<String, dynamic>?> _fetchGameByLink() async {
    final token = linkToken;
    if (token == null) return null;
    final rows =
        await _db
                .rpc(
                  SupabaseConfig.rpcGameCardByLinkFn,
                  params: {'p_game_id': gameId, 'p_link_token': token},
                )
                .timeout(kRequestTimeout)
            as List;
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
  }

  Future<void> _fetchRoster() async {
    final started = DateTime.now();
    try {
      final rows = await _db
          .from(SupabaseConfig.gameRosterTable)
          .select(
            'profile_id, user_id, role, profiles(display_name, username, avatar_url)',
          )
          .eq('game_id', gameId)
          .eq('status', 'active')
          .order('joined_at')
          .timeout(kRequestTimeout);
      if (_cacheOn) {
        _cache!.write(_accountId!, _rosterKey, rows, requestStartedAt: started);
      }
      if (!mounted) return;
      state = state.copyWith(
        roster: (rows as List)
            .map((r) => GameRosterEntry.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> _fetchWaitlist() async {
    try {
      final rows = await _db
          .from(SupabaseConfig.gameWaitlistTable)
          .select(
            'profile_id, user_id, position, profiles(display_name, username, avatar_url)',
          )
          .eq('game_id', gameId)
          .order('position');
      if (!mounted) return;
      state = state.copyWith(
        waitlist: (rows as List)
            .map((r) => GameWaitlistEntry.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> _fetchPendingRequests() async {
    try {
      final rows = await _db
          .from(SupabaseConfig.gameJoinRequestsTable)
          .select(
            'id, from_profile_id, from_user_id, profiles(display_name, username, avatar_url)',
          )
          .eq('game_id', gameId)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      if (!mounted) return;
      state = state.copyWith(
        pendingRequests: (rows as List)
            .map(
              (r) => GameJoinRequestEntry.fromJson(r as Map<String, dynamic>),
            )
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> _checkPendingRequest() async {
    if (currentUserId == null) return;
    try {
      final row = await _db
          .from(SupabaseConfig.gameJoinRequestsTable)
          .select('id')
          .eq('game_id', gameId)
          .eq('from_user_id', currentUserId!)
          .eq('status', 'pending')
          .maybeSingle();
      if (!mounted) return;
      state = state.copyWith(hasPendingRequest: row != null);
    } catch (_) {}
  }

  // ── Derived booleans the screen needs ─────────────────────────────────────

  bool get isHost =>
      state.roster.any((r) => r.userId == currentUserId && r.isHost);

  bool get isOnRoster => state.roster.any((r) => r.userId == currentUserId);

  bool get isOnWaitlist => state.waitlist.any((r) => r.userId == currentUserId);

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> joinGame() async {
    if (currentUserId == null) return;
    final joinStartedAt = DateTime.now();
    state = state.copyWith(isActing: true, clearError: true);

    try {
      final rows =
          await _db.rpc(
                SupabaseConfig.rpcJoinGameFn,
                params: {
                  'p_actor_type': 'player',
                  'p_game_id': gameId,
                  'p_link_token': ?linkToken,
                },
              )
              as List;

      if (rows.isEmpty) {
        state = state.copyWith(isActing: false, error: 'Unexpected response');
        return;
      }

      final result = rows.first['result'] as String?;
      JoinActionResult action;
      switch (result) {
        case 'joined':
          action = JoinActionResult.joined;
          break;
        case 'waitlisted':
          action = JoinActionResult.waitlisted;
          break;
        case 'request_submitted':
          action = JoinActionResult.requestSubmitted;
          break;
        default:
          action = JoinActionResult.joined;
      }

      if (action == JoinActionResult.joined) {
        final sportType =
            state.game?.sportKey ?? state.game?.sportId ?? 'unknown';
        unawaited(
          const AnalyticsService().trackGameJoined(
            gameId: gameId,
            sportType: sportType,
            joinMethod: state.game?.joinPolicy ?? 'unknown',
            timeToJoin: DateTime.now().difference(joinStartedAt).inMilliseconds,
          ),
        );
        unawaited(
          const AnalyticsService().trackGameConfirmed(
            gameId: gameId,
            sportType: sportType,
          ),
        );
      }

      await _load();
      state = state.copyWith(isActing: false, lastAction: action);
    } catch (e) {
      final l = _l10n?.call();
      final msg = l != null && e is PostgrestException
          ? joinRefusalMessage(l, e.message.replaceAll('P0001: ', ''))
          : _extractRpcError(e);
      state = state.copyWith(isActing: false, error: msg);
    }
  }

  Future<void> leaveGame() async {
    if (currentUserId == null) return;
    state = state.copyWith(isActing: true, clearError: true);

    try {
      await _db.rpc(
        SupabaseConfig.rpcLeaveGameFn,
        params: {'p_actor_type': 'player', 'p_game_id': gameId},
      );
      await _load();
      state = state.copyWith(
        isActing: false,
        lastAction: JoinActionResult.left,
      );
    } catch (e) {
      state = state.copyWith(isActing: false, error: _extractRpcError(e));
    }
  }

  Future<void> cancelJoinRequest() async {
    if (currentUserId == null) return;
    state = state.copyWith(isActing: true, clearError: true);

    try {
      await _db
          .from(SupabaseConfig.gameJoinRequestsTable)
          .update({'status': 'cancelled'})
          .eq('game_id', gameId)
          .eq('from_user_id', currentUserId!)
          .eq('status', 'pending');
      await _load();
      state = state.copyWith(
        isActing: false,
        lastAction: JoinActionResult.cancelledRequest,
      );
    } catch (e) {
      state = state.copyWith(isActing: false, error: _extractRpcError(e));
    }
  }

  /// Host approves or denies a pending join request. Approval puts the
  /// requester on the roster (or the waitlist when the game is full).
  Future<void> decideJoinRequest(String requestId, bool approve) async {
    if (currentUserId == null) return;
    state = state.copyWith(isActing: true, clearError: true);

    try {
      await _db.rpc(
        SupabaseConfig.rpcDecideJoinRequestFn,
        params: {'p_request_id': requestId, 'p_approve': approve},
      );
      await _load();
      state = state.copyWith(isActing: false);
    } catch (e) {
      state = state.copyWith(isActing: false, error: _extractRpcError(e));
    }
  }

  /// Creator removes an active player from the roster. The player's row is
  /// marked 'kicked', they get an in-app/push notification, and the first
  /// waitlisted player is promoted into the freed slot.
  Future<void> removePlayer(String profileId) async {
    if (currentUserId == null) return;
    state = state.copyWith(isActing: true, clearError: true);

    try {
      await _db.rpc(
        SupabaseConfig.rpcRemovePlayerFn,
        params: {'p_game_id': gameId, 'p_profile_id': profileId},
      );
      await _load();
      state = state.copyWith(isActing: false);
    } catch (e) {
      state = state.copyWith(isActing: false, error: _extractRpcError(e));
    }
  }

  String _extractRpcError(Object e) {
    if (e is PostgrestException) {
      // RPC raises with message field
      final msg = e.message.replaceAll('P0001: ', '');
      return switch (msg) {
        'not_host' => 'Only the game creator can do that.',
        'player_not_on_roster' => 'This player is no longer on the roster.',
        'cannot_remove_host' => 'The creator cannot be removed.',
        _ => msg,
      };
    }
    return e.toString();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final gameViewControllerProvider = StateNotifierProvider.family
    .autoDispose<GameViewController, GameViewState, String>((ref, gameId) {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      return GameViewController(
        supabase: supabase,
        gameId: gameId,
        currentUserId: currentUserId,
        cache: ref.watch(offlineCacheProvider),
        accountId: ref.watch(cacheAccountIdProvider),
        l10n: () => lookupAppLocalizations(ref.read(localeProvider)),
      );
    });
