import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      displayName: profile['display_name'] as String? ??
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
      displayName: profile['display_name'] as String? ??
          profile['username'] as String? ??
          'Player',
      avatarUrl: profile['avatar_url'] as String?,
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
    this.creatorUserId,
    this.creatorUsername,
    this.creatorDisplayName,
    this.creatorAvatarUrl,
    this.areaName,
    this.venueName,
    this.venueSpaceName,
    this.venueId,
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
  final String? creatorUserId;
  final String? creatorUsername;
  final String? creatorDisplayName;
  final String? creatorAvatarUrl;
  final String? areaName;
  final String? venueName;
  final String? venueSpaceName;
  final String? venueId;

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
    return GameView(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Untitled Game',
      gameType: j['game_type'] as String? ?? 'casual',
      startAt: DateTime.parse(j['start_at'] as String),
      endAt: DateTime.parse(j['end_at'] as String),
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
      creatorUserId: j['creator_user_id'] as String?,
      creatorUsername: j['creator_username'] as String?,
      creatorDisplayName: j['creator_display_name'] as String?,
      creatorAvatarUrl: j['creator_avatar_url'] as String?,
      areaName: j['area_name'] as String?,
      venueName: j['venue_name'] as String?,
      venueSpaceName: j['venue_space_name'] as String?,
      venueId: j['venue_id'] as String?,
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
    this.hasPendingRequest = false,
    this.isLoading = false,
    this.isActing = false,
    this.error,
    this.lastAction,
  });

  final GameView? game;
  final List<GameRosterEntry> roster;
  final List<GameWaitlistEntry> waitlist;
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
      hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
      isLoading: isLoading ?? this.isLoading,
      isActing: isActing ?? this.isActing,
      error: clearError ? null : error ?? this.error,
      lastAction: clearAction ? null : lastAction ?? this.lastAction,
    );
  }
}

// ─── Controller ───────────────────────────────────────────────────────────────

class GameViewController extends StateNotifier<GameViewState> {
  GameViewController({
    required SupabaseClient supabase,
    required this.gameId,
    required this.currentUserId,
  })  : _db = supabase,
        super(const GameViewState()) {
    _load();
  }

  final SupabaseClient _db;
  final String gameId;
  final String? currentUserId;

  Future<void> refresh() => _load();

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await Future.wait([_fetchGame(), _fetchRoster(), _fetchWaitlist()]);
      await _checkPendingRequest();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _fetchGame() async {
    try {
      final row = await _db
          .from('v_game_card')
          .select()
          .eq('id', gameId)
          .single();
      state = state.copyWith(game: GameView.fromJson(row));
    } catch (e) {
      state = state.copyWith(error: 'Failed to load game');
    }
  }

  Future<void> _fetchRoster() async {
    try {
      final rows = await _db
          .from('game_roster')
          .select('profile_id, user_id, role, profiles(display_name, username, avatar_url)')
          .eq('game_id', gameId)
          .eq('status', 'active')
          .order('joined_at');
      state = state.copyWith(
        roster: (rows as List).map((r) => GameRosterEntry.fromJson(r as Map<String, dynamic>)).toList(),
      );
    } catch (_) {}
  }

  Future<void> _fetchWaitlist() async {
    try {
      final rows = await _db
          .from('game_waitlist')
          .select('profile_id, user_id, position, profiles(display_name, username, avatar_url)')
          .eq('game_id', gameId)
          .order('position');
      state = state.copyWith(
        waitlist: (rows as List).map((r) => GameWaitlistEntry.fromJson(r as Map<String, dynamic>)).toList(),
      );
    } catch (_) {}
  }

  Future<void> _checkPendingRequest() async {
    if (currentUserId == null) return;
    try {
      final row = await _db
          .from('game_join_requests')
          .select('id')
          .eq('game_id', gameId)
          .eq('from_user_id', currentUserId!)
          .eq('status', 'pending')
          .maybeSingle();
      state = state.copyWith(hasPendingRequest: row != null);
    } catch (_) {}
  }

  // ── Derived booleans the screen needs ─────────────────────────────────────

  bool get isHost => state.roster.any(
        (r) => r.userId == currentUserId && r.isHost,
      );

  bool get isOnRoster => state.roster.any((r) => r.userId == currentUserId);

  bool get isOnWaitlist =>
      state.waitlist.any((r) => r.userId == currentUserId);

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> joinGame() async {
    if (currentUserId == null) return;
    state = state.copyWith(isActing: true, clearError: true);

    try {
      final rows = await _db.rpc('rpc_join_game', params: {
        'p_actor_type': 'player',
        'p_game_id': gameId,
      }) as List;

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

      await _load();
      state = state.copyWith(isActing: false, lastAction: action);
    } catch (e) {
      final msg = _extractRpcError(e);
      state = state.copyWith(isActing: false, error: msg);
    }
  }

  Future<void> leaveGame() async {
    if (currentUserId == null) return;
    state = state.copyWith(isActing: true, clearError: true);

    try {
      await _db.rpc('rpc_leave_game', params: {
        'p_actor_type': 'player',
        'p_game_id': gameId,
      });
      await _load();
      state = state.copyWith(isActing: false, lastAction: JoinActionResult.left);
    } catch (e) {
      state = state.copyWith(isActing: false, error: _extractRpcError(e));
    }
  }

  Future<void> cancelJoinRequest() async {
    if (currentUserId == null) return;
    state = state.copyWith(isActing: true, clearError: true);

    try {
      await _db
          .from('game_join_requests')
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

  String _extractRpcError(Object e) {
    if (e is PostgrestException) {
      // RPC raises with message field
      return e.message.replaceAll('P0001: ', '');
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
  );
});
