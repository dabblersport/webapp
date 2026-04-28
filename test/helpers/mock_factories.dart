import 'package:mockito/annotations.dart';
import 'package:dabbler/features/auth_onboarding/domain/repositories/auth_repository.dart';
import 'package:dabbler/features/games/domain/repositories/games_repository.dart';
import 'package:dabbler/features/games/domain/repositories/bookings_repository.dart';
import 'package:dabbler/features/games/domain/repositories/venues_repository.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/authentication/user.dart';
import 'package:dabbler/data/models/authentication/auth_session.dart';

export 'mock_factories.mocks.dart';

@GenerateMocks([
  AuthRepository,
  GamesRepository,
  BookingsRepository,
  VenuesRepository,
])
void main() {}

// ---------------------------------------------------------------------------
// Shared builder helpers
// ---------------------------------------------------------------------------

final _baseNow = DateTime.now();
final _tomorrow = _baseNow.add(const Duration(days: 1));

Game makeGame({
  String id = 'game-1',
  String title = 'Test Game',
  String description = 'A test game',
  String sport = 'football',
  DateTime? scheduledDate,
  String startTime = '10:00',
  String endTime = '11:00',
  int minPlayers = 2,
  int maxPlayers = 10,
  int currentPlayers = 0,
  String organizerId = 'organizer-1',
  String skillLevel = 'beginner',
  double pricePerPlayer = 0,
  GameStatus status = GameStatus.upcoming,
  bool isPublic = true,
  bool allowsWaitlist = true,
  bool checkInEnabled = false,
  DateTime? cancellationDeadline,
}) {
  return Game(
    id: id,
    title: title,
    description: description,
    sport: sport,
    scheduledDate: scheduledDate ?? _tomorrow,
    startTime: startTime,
    endTime: endTime,
    minPlayers: minPlayers,
    maxPlayers: maxPlayers,
    currentPlayers: currentPlayers,
    organizerId: organizerId,
    skillLevel: skillLevel,
    pricePerPlayer: pricePerPlayer,
    status: status,
    isPublic: isPublic,
    allowsWaitlist: allowsWaitlist,
    checkInEnabled: checkInEnabled,
    cancellationDeadline: cancellationDeadline,
    createdAt: _baseNow,
    updatedAt: _baseNow,
  );
}

User makeUser({
  String id = 'user-1',
  String? email = 'test@example.com',
  bool isProfileComplete = false,
}) {
  final now = DateTime.now();
  return User(
    id: id,
    email: email,
    isProfileComplete: isProfileComplete,
    createdAt: now,
    updatedAt: now,
  );
}

AuthSession makeAuthSession({String userId = 'user-1'}) {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    user: makeUser(id: userId),
  );
}
