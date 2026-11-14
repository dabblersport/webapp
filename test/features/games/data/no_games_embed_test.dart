// KAN-952: public.games keeps only its game-specific columns since KAN-866
// (title, creator, time and sport live on public.events) and has RLS with no
// client policy, so a PostgREST embed of games returns nothing to the app.
// The bookings stack and VenuesRepository.getVenueBookingHistory that embedded
// `game:games(title, sport[, organizer_id])` were unreachable and were deleted.
// This pins the deletion: no client query may embed games again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no file under lib/ embeds public.games in a PostgREST select', () {
    final embed = RegExp(r'\w+\s*:\s*games\s*(!\w+)?\s*\(');
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (embed.hasMatch(lines[i])) hits.add('${entity.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: 'games embeds found: $hits');
  });

  test('the dead bookings stack stays deleted', () {
    const deleted = [
      'lib/features/games/data/datasources/bookings_datasource.dart',
      'lib/features/games/data/datasources/bookings_remote_data_source.dart',
      'lib/features/games/data/repositories/bookings_repository_impl.dart',
      'lib/features/games/presentation/controllers/bookings_controller.dart',
    ];
    for (final path in deleted) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });
}
