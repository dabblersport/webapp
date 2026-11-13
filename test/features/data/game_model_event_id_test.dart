import 'dart:io';

import 'package:dabbler/data/models/games/game_model.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-741 (KAN-715 R01): GameModel carries the events parent id separately
// from the games id, and keeps legacy nulls null instead of inventing values.
void main() {
  const String gameId = '11111111-1111-1111-1111-111111111111';
  const String eventId = '99999999-9999-9999-9999-999999999999';

  Map<String, dynamic> nullSharedRow() => <String, dynamic>{
    'id': gameId,
    'event_id': eventId,
    'title': null,
    'sport': null,
    'start_at': '2026-11-10T18:00:00Z',
    'end_at': null,
    'is_cancelled': null,
    'created_at': '2026-11-01T09:30:00Z',
    'updated_at': '2026-11-02T10:45:00Z',
  };

  test('null title/end/sport parses; stored values stay null', () {
    final GameModel g = GameModel.fromJson(nullSharedRow());
    expect(g.storedTitle, isNull);
    expect(g.storedEndAt, isNull);
    expect(g.storedSport, isNull);
    expect(
      g.scheduledDate,
      DateTime.utc(2026, 11, 10, 18).toLocal(),
    ); // KAN-927
    expect(g.createdAt, DateTime.utc(2026, 11, 1, 9, 30));
    expect(g.updatedAt, DateTime.utc(2026, 11, 2, 10, 45));
  });

  test('id keeps meaning games.id; eventId is the events parent id', () {
    final GameModel g = GameModel.fromJson(nullSharedRow());
    expect(g.id, gameId);
    expect(g.eventId, eventId);
    expect(g.eventId, isNot(g.id));
    expect(g.toJson()['id'], gameId);
    expect(g.toJson()['event_id'], eventId);
  });

  test('a source without event_id parses with a null eventId', () {
    final GameModel g = GameModel.fromJson(nullSharedRow()..remove('event_id'));
    expect(g.id, gameId);
    expect(g.eventId, isNull);
  });

  test('stored values are kept when present', () {
    final GameModel g = GameModel.fromJson(
      nullSharedRow()
        ..['title'] = 'Friday 5s'
        ..['sport'] = 'padel'
        ..['end_at'] = '2026-11-10T19:30:00Z',
    );
    expect(g.storedTitle, 'Friday 5s');
    expect(g.storedSport, 'padel');
    expect(
      g.storedEndAt,
      DateTime.utc(2026, 11, 10, 19, 30).toLocal(),
    ); // KAN-927
  });

  test('copyWith keeps eventId and the stored values', () {
    final GameModel g = GameModel.fromJson(
      nullSharedRow(),
    ).copyWith(currentPlayers: 3);
    expect(g.id, gameId);
    expect(g.eventId, eventId);
    expect(g.storedTitle, isNull);
    expect(g.storedEndAt, isNull);
    expect(g.storedSport, isNull);
  });

  test('no direct write to a shared column is issued from GameModel', () {
    final String model = File(
      'lib/data/models/games/game_model.dart',
    ).readAsStringSync();
    expect(model.contains('Supabase'), isFalse);
    expect(model.contains('.from('), isFalse);

    // The model's write maps are never sent: nothing in lib/ calls them.
    final RegExp sends = RegExp(r'\.(toCreateJson|toUpdateJson)\(\)');
    for (final FileSystemEntity f in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      expect(sends.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });
}
