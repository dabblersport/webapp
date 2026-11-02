import 'package:dabbler/data/models/games/game.dart';

/// JSON-safe encoding of a [Game] for the on-device cache (KAN-655).
Map<String, Object?> encodeGame(Game g) => {
  'id': g.id,
  'title': g.title,
  'description': g.description,
  'sport': g.sport,
  'venueId': g.venueId,
  'venueName': g.venueName,
  'scheduledDate': g.scheduledDate.toIso8601String(),
  'startTime': g.startTime,
  'endTime': g.endTime,
  'minPlayers': g.minPlayers,
  'maxPlayers': g.maxPlayers,
  'currentPlayers': g.currentPlayers,
  'organizerId': g.organizerId,
  'skillLevel': g.skillLevel,
  'pricePerPlayer': g.pricePerPlayer,
  'currency': g.currency,
  'status': g.status.name,
  'isPublic': g.isPublic,
  'allowsWaitlist': g.allowsWaitlist,
  'checkInEnabled': g.checkInEnabled,
  'cancellationDeadline': g.cancellationDeadline?.toIso8601String(),
  'createdAt': g.createdAt.toIso8601String(),
  'updatedAt': g.updatedAt.toIso8601String(),
};

Game decodeGame(Map<String, dynamic> m) => Game(
  id: m['id'] as String,
  title: m['title'] as String,
  description: m['description'] as String,
  sport: m['sport'] as String,
  venueId: m['venueId'] as String?,
  venueName: m['venueName'] as String?,
  scheduledDate: DateTime.parse(m['scheduledDate'] as String),
  startTime: m['startTime'] as String,
  endTime: m['endTime'] as String,
  minPlayers: m['minPlayers'] as int,
  maxPlayers: m['maxPlayers'] as int,
  currentPlayers: m['currentPlayers'] as int,
  organizerId: m['organizerId'] as String,
  skillLevel: m['skillLevel'] as String,
  pricePerPlayer: (m['pricePerPlayer'] as num).toDouble(),
  currency: m['currency'] as String,
  status: GameStatus.values.byName(m['status'] as String),
  isPublic: m['isPublic'] as bool,
  allowsWaitlist: m['allowsWaitlist'] as bool,
  checkInEnabled: m['checkInEnabled'] as bool,
  cancellationDeadline: m['cancellationDeadline'] == null
      ? null
      : DateTime.parse(m['cancellationDeadline'] as String),
  createdAt: DateTime.parse(m['createdAt'] as String),
  updatedAt: DateTime.parse(m['updatedAt'] as String),
);

List<Map<String, Object?>> encodeGames(List<Game> games) =>
    games.map(encodeGame).toList();

List<Game> decodeGames(Object? json) => (json as List)
    .map((e) => decodeGame(Map<String, dynamic>.from(e as Map)))
    .toList();
