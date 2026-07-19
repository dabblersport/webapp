import 'package:flutter_test/flutter_test.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';

void main() {
  const fullArgs = SportProfileRouteArgs(
    profileId: 'profile-1',
    userId: 'user-1',
    displayName: 'Jane Doe',
    personaType: 'player',
    sportId: 'sport-1',
    sportKey: 'football',
    sportName: 'Football',
    avatarUrl: 'https://example.com/a.png?size=64&fmt=webp',
    sportEmoji: '⚽',
  );

  group('SportProfileRouteArgs query round-trip', () {
    test('full args survive to/from query parameters', () {
      final rebuilt = SportProfileRouteArgs.fromQueryParameters(
        fullArgs.toQueryParameters(),
      );
      expect(rebuilt, fullArgs);
    });

    test('round-trip survives Uri encoding (spaces, emoji, url params)', () {
      final uri = Uri(
        path: '/profile/sport',
        queryParameters: fullArgs.toQueryParameters(),
      );
      final parsed = Uri.parse(uri.toString());
      final rebuilt = SportProfileRouteArgs.fromQueryParameters(
        parsed.queryParameters,
      );
      expect(rebuilt, fullArgs);
    });

    test('empty display fields are omitted and degrade gracefully', () {
      const minimal = SportProfileRouteArgs(
        profileId: 'profile-1',
        userId: 'user-1',
        displayName: '',
        personaType: 'organiser',
        sportId: 'sport-1',
        sportKey: 'table_tennis',
        sportName: 'Table Tennis',
      );
      final query = minimal.toQueryParameters();
      expect(query.containsKey('displayName'), isFalse);
      expect(query.containsKey('avatarUrl'), isFalse);
      expect(query.containsKey('sportEmoji'), isFalse);

      final rebuilt = SportProfileRouteArgs.fromQueryParameters(query);
      expect(rebuilt, minimal);
    });

    test('sportName falls back to title-cased sportKey', () {
      final query = fullArgs.toQueryParameters()..remove('sportName');
      query['sportKey'] = 'table_tennis';
      final rebuilt = SportProfileRouteArgs.fromQueryParameters(query);
      expect(rebuilt!.sportName, 'Table Tennis');
    });

    test('missing required params return null', () {
      for (final key in ['profileId', 'userId', 'sportId', 'sportKey']) {
        final query = fullArgs.toQueryParameters()..remove(key);
        expect(
          SportProfileRouteArgs.fromQueryParameters(query),
          isNull,
          reason: 'missing $key should be rejected',
        );
      }
    });

    test('invalid persona returns null', () {
      final query = fullArgs.toQueryParameters();
      for (final persona in ['', 'admin', 'PLAYER']) {
        query['persona'] = persona;
        expect(SportProfileRouteArgs.fromQueryParameters(query), isNull);
      }
      final missing = fullArgs.toQueryParameters()..remove('persona');
      expect(SportProfileRouteArgs.fromQueryParameters(missing), isNull);
    });
  });
}
