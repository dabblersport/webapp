import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/games/venue.dart';
import 'package:dabbler/data/models/games/player.dart';
import '../../domain/usecases/join_game_usecase.dart';
import '../../domain/repositories/games_repository.dart';
import '../../domain/repositories/venues_repository.dart';
import 'package:dabbler/data/models/joinability_rule.dart';
import '../../../../data/repositories/joinability_repository.dart';

enum JoinGameStatus {
  canJoin,
  waitlisted,
  alreadyJoined,
  gameFull,
  gameStarted,
  gameEnded,
  notEligible,
  requested, // Join request has been sent and is pending approval
}

class WeatherInfo {
  final String condition; // sunny, cloudy, rainy, etc.
  final int temperature; // in Celsius
  final String description;
  final String iconUrl;
  final int humidity;
  final double windSpeed;
  final int uvIndex;

  const WeatherInfo({
    required this.condition,
    required this.temperature,
    required this.description,
    required this.iconUrl,
    required this.humidity,
    required this.windSpeed,
    required this.uvIndex,
  });
}

class GameDetailState {
  final Game? game;
  final Venue? venue;
  final List<Player> players;
  final List<Player> waitlistedPlayers;
  final bool isLoading;
  final bool isLoadingVenue;
  final bool isLoadingPlayers;
  final bool isJoining;
  final String? error;
  final String? joinMessage;
  final JoinGameStatus joinStatus;
  final JoinabilityDecision? joinabilityDecision;
  final bool isOrganizer;
  final WeatherInfo? weather;
  final bool isLoadingWeather;
  final DateTime? lastUpdated;
  final Timer? realtimeTimer;

  const GameDetailState({
    this.game,
    this.venue,
    this.players = const [],
    this.waitlistedPlayers = const [],
    this.isLoading = false,
    this.isLoadingVenue = false,
    this.isLoadingPlayers = false,
    this.isJoining = false,
    this.error,
    this.joinMessage,
    this.joinStatus = JoinGameStatus.canJoin,
    this.joinabilityDecision,
    this.isOrganizer = false,
    this.weather,
    this.isLoadingWeather = false,
    this.lastUpdated,
    this.realtimeTimer,
  });

  bool get hasGame => game != null;
  bool get hasVenue => venue != null;
  bool get hasWeather => weather != null;
  bool get isAnyLoading =>
      isLoading || isLoadingVenue || isLoadingPlayers || isLoadingWeather;

  int get totalPlayers => players.length;
  int get spotsRemaining =>
      game != null ? (game!.maxPlayers - totalPlayers) : 0;
  bool get isGameFull => spotsRemaining <= 0;

  double get fillPercentage =>
      game != null ? (totalPlayers / game!.maxPlayers) : 0.0;
  bool get hasMinimumPlayers =>
      game != null ? (totalPlayers >= game!.minPlayers) : false;

  Duration? get timeUntilStart {
    if (game == null) return null;
    final startDateTime = _combineDateTime(
      game!.scheduledDate,
      game!.startTime,
    );
    final now = DateTime.now();
    if (startDateTime.isBefore(now)) return null;
    return startDateTime.difference(now);
  }

  bool get canStillJoin {
    if (game == null) return false;
    final startDateTime = _combineDateTime(
      game!.scheduledDate,
      game!.startTime,
    );
    return DateTime.now().isBefore(
      startDateTime.subtract(const Duration(minutes: 15)),
    );
  }

  DateTime _combineDateTime(DateTime date, String time) {
    final timeParts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  GameDetailState copyWith({
    Game? game,
    Venue? venue,
    List<Player>? players,
    List<Player>? waitlistedPlayers,
    bool? isLoading,
    bool? isLoadingVenue,
    bool? isLoadingPlayers,
    bool? isJoining,
    String? error,
    String? joinMessage,
    JoinGameStatus? joinStatus,
    JoinabilityDecision? joinabilityDecision,
    bool? isOrganizer,
    WeatherInfo? weather,
    bool? isLoadingWeather,
    DateTime? lastUpdated,
    Timer? realtimeTimer,
  }) {
    return GameDetailState(
      game: game ?? this.game,
      venue: venue ?? this.venue,
      players: players ?? this.players,
      waitlistedPlayers: waitlistedPlayers ?? this.waitlistedPlayers,
      isLoading: isLoading ?? this.isLoading,
      isLoadingVenue: isLoadingVenue ?? this.isLoadingVenue,
      isLoadingPlayers: isLoadingPlayers ?? this.isLoadingPlayers,
      isJoining: isJoining ?? this.isJoining,
      error: error,
      joinStatus: joinStatus ?? this.joinStatus,
      joinabilityDecision: joinabilityDecision ?? this.joinabilityDecision,
      isOrganizer: isOrganizer ?? this.isOrganizer,
      weather: weather ?? this.weather,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      realtimeTimer: realtimeTimer ?? this.realtimeTimer,
    );
  }
}

class GameDetailController extends StateNotifier<GameDetailState> {
  final JoinGameUseCase _joinGameUseCase;
  final GamesRepository _gamesRepository;
  final VenuesRepository _venuesRepository;
  final JoinabilityRepository _joinabilityRepository;
  final String gameId;
  final String? currentUserId;

  GameDetailController({
    required JoinGameUseCase joinGameUseCase,
    required GamesRepository gamesRepository,
    required VenuesRepository venuesRepository,
    required JoinabilityRepository joinabilityRepository,
    required this.gameId,
    this.currentUserId,
  }) : _joinGameUseCase = joinGameUseCase,
       _gamesRepository = gamesRepository,
       _venuesRepository = venuesRepository,
       _joinabilityRepository = joinabilityRepository,
       super(const GameDetailState()) {
    _initializeGameDetail();
  }

  /// Initialize and load all game details
  Future<void> _initializeGameDetail() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load game details concurrently
      await Future.wait([_loadGameDetails(), _loadGamePlayers()]);

      // Load venue details if game has a venue
      if (state.game?.venueId != null) {
        await _loadVenueDetails();

        // Load weather if venue has location
        if (state.venue != null) {
          await _loadWeatherInfo();
        }
      }

      // Determine join status
      await _updateJoinStatus();

      // Start real-time updates
      _startRealtimeUpdates();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load game details: $e',
      );
    }
  }

  /// Refresh all game data
  Future<void> refresh() async {
    await _initializeGameDetail();
  }

  /// Load game basic details
  Future<void> _loadGameDetails() async {
    try {
      final result = await _gamesRepository.getGame(gameId);

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load game: ${failure.message}',
          );
        },
        (game) {
          state = state.copyWith(
            game: game,
            isOrganizer: currentUserId == game.organizerId,
            isLoading: false,
            lastUpdated: DateTime.now(),
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load game details: $e',
      );
    }
  }

  /// Load venue details
  Future<void> _loadVenueDetails() async {
    if (state.game?.venueId == null) return;

    state = state.copyWith(isLoadingVenue: true);

    try {
      final result = await _venuesRepository.getVenue(state.game!.venueId!);

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoadingVenue: false,
            error: 'Failed to load venue: ${failure.message}',
          );
        },
        (venue) {
          state = state.copyWith(venue: venue, isLoadingVenue: false);
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingVenue: false,
        error: 'Failed to load venue details: $e',
      );
    }
  }

  /// Load current players and waitlisted players
  Future<void> _loadGamePlayers() async {
    state = state.copyWith(isLoadingPlayers: true);

    try {
      final result = await _gamesRepository.getGamePlayers(gameId);

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoadingPlayers: false,
            error: 'Failed to load players',
          );
        },
        (allPlayers) {
          // Split players into confirmed and waitlisted
          final confirmedPlayers = allPlayers
              .where((p) => p.status == PlayerStatus.confirmed)
              .toList();
          final waitlistedPlayers = allPlayers
              .where((p) => p.status == PlayerStatus.waitlisted)
              .toList();

          state = state.copyWith(
            players: confirmedPlayers,
            waitlistedPlayers: waitlistedPlayers,
            isLoadingPlayers: false,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingPlayers: false,
        error: 'Failed to load players: $e',
      );
    }
  }

  /// Load weather information for the game
  Future<void> _loadWeatherInfo() async {
    if (state.venue == null || state.game == null) return;

    state = state.copyWith(isLoadingWeather: true);

    try {
      // For now, weather feature is disabled
      // final result = await _weatherService.getWeather(
      //   latitude: state.venue!.latitude,
      //   longitude: state.venue!.longitude,
      //   date: state.game!.scheduledDate,
      // );

      state = state.copyWith(
        weather: null, // Weather feature disabled
        isLoadingWeather: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingWeather: false,
        error: 'Failed to load weather: $e',
      );
    }
  }

  /// Join the game
  Future<void> joinGame() async {
    if (currentUserId == null ||
        state.joinStatus == JoinGameStatus.alreadyJoined) {
      return;
    }

    state = state.copyWith(isJoining: true, error: null);

    try {
      final result = await _joinGameUseCase(
        JoinGameParams(gameId: gameId, playerId: currentUserId!),
      );

      result.fold(
        (failure) {
          state = state.copyWith(isJoining: false, error: failure.message);
        },
        (joinResult) async {
          // Refresh game data to get updated player list and counts
          await _loadGameDetails();
          await _loadGamePlayers();
          await _updateJoinStatus();

          // Set success message based on waitlist status or request status
          String? successMessage;

          // Check if a request was created (for request join policy)
          final updatedStatus = state.joinStatus;
          if (updatedStatus == JoinGameStatus.requested) {
            successMessage =
                'Join request sent! The organizer will review your request.';
          } else if (joinResult.isOnWaitlist) {
            final positionText = joinResult.position != null
                ? ' (Position #${joinResult.position})'
                : '';
            successMessage =
                'Added to waitlist$positionText. You will be notified if a spot becomes available.';
          } else {
            // For request policy, check if we just sent a request
            final game = state.game;
            if (game is GameModel && game.joinPolicy == 'request') {
              successMessage =
                  'Join request sent! The organizer will review your request.';
            } else {
              successMessage = joinResult.message.isNotEmpty
                  ? joinResult.message
                  : 'Successfully joined the game!';
            }
          }

          state = state.copyWith(
            isJoining: false,
            error: null,
            joinMessage: successMessage,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isJoining: false,
        error: 'Failed to join game: $e',
      );
    }
  }

  /// Leave the game
  Future<void> leaveGame() async {
    if (currentUserId == null) return;

    state = state.copyWith(isJoining: true, error: null);

    try {
      // final result = await _leaveGameUseCase(LeaveGameParams(
      //   gameId: gameId,
      //   playerId: currentUserId!,
      // ));

      await Future.delayed(const Duration(milliseconds: 500));

      // Mock success - refresh data
      await _loadGamePlayers();
      await _updateJoinStatus();

      state = state.copyWith(isJoining: false);
    } catch (e) {
      state = state.copyWith(
        isJoining: false,
        error: 'Failed to leave game: $e',
      );
    }
  }

  /// Cancel a pending join request
  Future<void> cancelJoinRequest() async {
    if (currentUserId == null) return;

    state = state.copyWith(isJoining: true, error: null);

    try {
      final result = await _gamesRepository.cancelJoinRequest(
        gameId,
        currentUserId!,
      );

      result.fold(
        (failure) {
          state = state.copyWith(isJoining: false, error: failure.message);
        },
        (cancelled) async {
          // Always refresh status to update UI, even if request wasn't found
          // (it might have been approved/denied already, or never existed)
          await _updateJoinStatus();

          if (cancelled) {
            state = state.copyWith(
              isJoining: false,
              error: null,
              joinMessage: 'Join request cancelled',
            );
          } else {
            // No request found - might have been already processed or doesn't exist
            // Treat as success (idempotent) and just refresh the UI
            state = state.copyWith(
              isJoining: false,
              error: null,
              joinMessage: null,
            );
          }
        },
      );
    } catch (e) {
      state = state.copyWith(
        isJoining: false,
        error: 'Failed to cancel join request: $e',
      );
    }
  }

  /// Update join status based on current state
  Future<void> _updateJoinStatus() async {
    if (currentUserId == null || state.game == null) {
      state = state.copyWith(
        joinStatus: JoinGameStatus.notEligible,
        joinabilityDecision: null,
      );
      return;
    }

    final game = state.game!;
    final alreadyJoined = state.players.any((p) => p.playerId == currentUserId);

    // Check for pending join request
    bool alreadyRequested = false;
    try {
      final hasRequest = await _gamesRepository.hasPendingJoinRequest(
        gameId,
        currentUserId!,
      );
      alreadyRequested = hasRequest.fold((_) => false, (has) => has);
    } catch (e) {}

    // Determine if approval is required based on join_policy
    // GameModel has joinPolicy, but Game doesn't - check if it's GameModel
    String? joinPolicy;
    if (game is GameModel) {
      joinPolicy = game.joinPolicy;
    }
    final requiresApproval = joinPolicy == 'request';

    final inputs = JoinabilityInputs(
      ownerId: game.organizerId,
      visibility: game.isPublic ? 'public' : 'hidden',
      viewerId: currentUserId,
      viewerIsAdmin: false,
      areSyncedWithOwner: true,
      joinWindowOpen: game.status == GameStatus.upcoming && state.canStillJoin,
      requiresInvite: false,
      viewerInvited: true,
      requiresApproval: requiresApproval,
      alreadyJoined: alreadyJoined,
      alreadyRequested: alreadyRequested,
      rosterCount: state.players.length,
      rosterCap: game.maxPlayers,
      waitlistEnabled: game.allowsWaitlist,
      waitlistCount: state.waitlistedPlayers.length,
      waitlistCap: 0,
    );

    final decisionResult = _joinabilityRepository.evaluate(inputs);

    decisionResult.fold(
      (failure) {
        state = state.copyWith(
          joinStatus: JoinGameStatus.notEligible,
          joinabilityDecision: null,
          error: failure.message,
        );
      },
      (decision) {
        state = state.copyWith(
          joinStatus: _mapJoinabilityToStatus(decision),
          joinabilityDecision: decision,
          error: null,
        );
      },
    );
  }

  JoinGameStatus _mapJoinabilityToStatus(JoinabilityDecision decision) {
    if (decision.canLeave) {
      return JoinGameStatus.alreadyJoined;
    }
    // Check if already requested (this is handled by alreadyRequested flag)
    if (decision.reason == JoinabilityReason.alreadyRequested) {
      return JoinGameStatus.requested;
    }
    // If can request, return canJoin but UI will check canRequest to show "Request to Join"
    if (decision.canRequest) {
      return JoinGameStatus
          .canJoin; // UI will check canRequest to show "Request to Join"
    }
    if (decision.canJoin) {
      return JoinGameStatus.canJoin;
    }
    if (decision.reason == JoinabilityReason.approvalRequired) {
      return JoinGameStatus
          .canJoin; // UI will check canRequest to show "Request to Join"
    }
    if (decision.canWaitlist ||
        decision.reason == JoinabilityReason.rosterFullWaitlistAvailable) {
      return JoinGameStatus.waitlisted;
    }

    switch (decision.reason) {
      case JoinabilityReason.rosterFull:
        return JoinGameStatus.gameFull;
      case JoinabilityReason.windowClosed:
        return JoinGameStatus.gameStarted;
      case JoinabilityReason.approvalRequired:
      case JoinabilityReason.alreadyJoined:
      case JoinabilityReason.viewerIsOwner:
      case JoinabilityReason.notLoggedIn:
      case JoinabilityReason.hiddenToViewer:
      case JoinabilityReason.circleNotSynced:
      case JoinabilityReason.inviteRequired:
      case JoinabilityReason.alreadyRequested:
      case JoinabilityReason.unknownVisibility:
        return JoinGameStatus.notEligible;
      case JoinabilityReason.adminOverride:
      case JoinabilityReason.ok:
        return decision.canJoin
            ? JoinGameStatus.canJoin
            : JoinGameStatus.notEligible;
      case JoinabilityReason.rosterFullWaitlistAvailable:
        return JoinGameStatus.waitlisted;
    }
  }

  /// Start real-time updates
  void _startRealtimeUpdates() {
    // Cancel existing timer
    state.realtimeTimer?.cancel();

    // Start new timer for periodic updates
    final timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadGamePlayers();
        _updateJoinStatus(); // Fire and forget - async call
      } else {
        timer.cancel();
      }
    });

    state = state.copyWith(realtimeTimer: timer);
  }

  /// Stop real-time updates
  void _stopRealtimeUpdates() {
    state.realtimeTimer?.cancel();
    state = state.copyWith(realtimeTimer: null);
  }

  /// Share game details
  Future<String> getShareableGameInfo() async {
    if (state.game == null) return '';

    final game = state.game!;
    final venue = state.venue;

    final buffer = StringBuffer();
    buffer.writeln('🏀 ${game.title}');
    buffer.writeln('🗓️ ${_formatDate(game.scheduledDate)}');
    buffer.writeln('🕐 ${game.startTime} - ${game.endTime}');
    buffer.writeln('👥 ${state.totalPlayers}/${game.maxPlayers} players');

    if (venue != null) {
      buffer.writeln('📍 ${venue.name}');
      buffer.writeln('   ${venue.shortAddress}');
    }

    if (game.pricePerPlayer > 0) {
      buffer.writeln(
        '💰 \$${game.pricePerPlayer.toStringAsFixed(2)} per player',
      );
    }

    buffer.writeln('\nJoin us on Dabbler! 🎯');

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  void dispose() {
    _stopRealtimeUpdates();
    super.dispose();
  }
}
