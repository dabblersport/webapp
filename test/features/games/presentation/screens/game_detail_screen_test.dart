import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';
import 'package:dabbler/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:dabbler/features/profile/domain/repositories/profile_repository.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/features/games/presentation/controllers/game_detail_controller.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_detail_screen.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/player.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockProfileRepository extends Mock implements ProfileRepository {
  @override
  Future<Either<Failure, UserProfile>> getProfile(
    String userId, {
    String? profileType,
    bool filterActive = true,
    String? profileId,
  }) async {
    return Right(UserProfile(
      id: 'profile-123',
      userId: userId,
      displayName: 'Test User',
      profileType: 'player',
      personaType: 'player',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }
}

Player _buildPlayer({required String id, required String userId}) {
  final now = DateTime(2024, 1, 1);
  return Player(
    id: id,
    playerId: userId,
    gameId: 'game_1',
    status: PlayerStatus.confirmed,
    teamAssignment: TeamAssignment.unassigned,
    playerName: 'Test Player',
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    position: null,
    playerAvatar: null,
    playerPhone: null,
    playerEmail: null,
    checkedInAt: null,
    cancelledAt: null,
    checkInCode: null,
    isOrganizer: false,
    playerRating: null,
    ratedAt: null,
    ratingComment: null,
    hasPaid: false,
    amountPaid: null,
    paidAt: null,
  );
}

Game _buildGame() {
  final now = DateTime(2024, 1, 1);
  return Game(
    id: 'game_1',
    title: 'Evening Pickup',
    description: 'Friendly run for local players.',
    sport: 'basketball',
    venueId: null,
    scheduledDate: DateTime(2024, 2, 1),
    startTime: '18:00',
    endTime: '19:30',
    minPlayers: 4,
    maxPlayers: 10,
    currentPlayers: 4,
    organizerId: 'organizer_1',
    skillLevel: 'intermediate',
    pricePerPlayer: 15,
    currency: 'USD',
    status: GameStatus.upcoming,
    isPublic: true,
    allowsWaitlist: true,
    checkInEnabled: false,
    cancellationDeadline: null,
    createdAt: now,
    updatedAt: now,
  );
}

GameDetailState _buildState({
  required Game game,
  required List<Player> players,
  JoinGameStatus status = JoinGameStatus.canJoin,
}) {
  return GameDetailState(
    game: game,
    players: players,
    waitlistedPlayers: const [],
    isLoading: false,
    isLoadingPlayers: false,
    isLoadingVenue: false,
    joinStatus: status,
  );
}

void main() {
  const userId = 'user-123';
  final game = _buildGame();
  final params = GameDetailParams(gameId: game.id, currentUserId: userId);

  testWidgets('Join/Leave CTA reflects provider state changes', (tester) async {
    final initialState = _buildState(game: game, players: const []);
    final stateProvider = StateProvider<GameDetailState>((ref) => initialState);

    final mockProfile = UserProfile(
      id: 'profile-123',
      userId: userId,
      displayName: 'Test User',
      profileType: 'player',
      personaType: 'player',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockRepo = MockProfileRepository();
    final getProfileUseCase = GetProfileUseCase(mockRepo);

    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        profileControllerProvider.overrideWith((ref) => ProfileController(
              getProfileUseCase: getProfileUseCase,
            )..state = ProfileState(profile: mockProfile)),
        gameDetailStateProvider(
          params,
        ).overrideWith((ref) => ref.watch(stateProvider)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: GameDetailScreen(gameId: game.id)),
      ),
    );

    expect(find.text('Join Game'), findsOneWidget);

    container.read(stateProvider.notifier).state = _buildState(
      game: game,
      players: [_buildPlayer(id: 'player-1', userId: userId)],
      status: JoinGameStatus.alreadyJoined,
    );
    await tester.pump();

    expect(find.text('Leave'), findsOneWidget);
  });
}
