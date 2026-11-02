import 'dart:convert';

import 'package:dabbler/core/offline/game_codec.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a game survives encode, JSON and decode', () {
    final g = Game(
      id: 'g1',
      title: 'Five-a-side',
      description: 'd',
      sport: 'football',
      venueName: 'Court 1',
      scheduledDate: DateTime.utc(2026, 11, 2),
      startTime: '18:00',
      endTime: '19:00',
      minPlayers: 6,
      maxPlayers: 10,
      currentPlayers: 4,
      organizerId: 'u1',
      skillLevel: 'mixed',
      pricePerPlayer: 12.5,
      status: GameStatus.upcoming,
      isPublic: true,
      allowsWaitlist: false,
      checkInEnabled: false,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 2),
    );
    final back = decodeGames(jsonDecode(jsonEncode(encodeGames([g]))));
    expect(back, hasLength(1));
    final b = back.single;
    expect(b.id, 'g1');
    expect(b.venueId, isNull);
    expect(b.venueName, 'Court 1');
    expect(b.scheduledDate.toUtc(), g.scheduledDate);
    expect(b.pricePerPlayer, 12.5);
    expect(b.status, GameStatus.upcoming);
    expect(b.cancellationDeadline, isNull);
  });
}
