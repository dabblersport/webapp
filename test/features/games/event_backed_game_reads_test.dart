// KAN-715: the composer "Link a game" search (PostRepositoryImpl.searchGames)
// and the organiser sport-profile hosted metrics read v_game_card, never
// public.games, with their filters server-side.
import 'dart:convert';

import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/sport_profile_view_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

void main() {
  late List<http.Request> seen;

  http.Response json(http.Request r, Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
    request: r,
  );

  Iterable<http.Request> at(String path) =>
      seen.where((r) => r.url.path == path);

  setUp(() => seen = []);

  test(
    'composer game search reads v_game_card, sport from sport_key',
    () async {
      final client = buildTestSupabaseClient((r) async {
        seen.add(r);
        if (r.url.path == '/rest/v1/v_game_card') {
          return json(r, [
            {
              'id': 'g1',
              'title': null,
              'sport': null,
              'game_type': 'pickup',
              'start_at': '2026-11-10T18:00:00Z',
              'end_at': null,
            },
          ]);
        }
        return json(r, <dynamic>[]);
      });
      final repo = PostRepositoryImpl(
        SupabaseService(client, SupabaseErrorMapper()),
      );

      final rows = (await repo.searchGames('fri')).requireValue;

      expect(at('/rest/v1/games'), isEmpty);
      final q = at('/rest/v1/v_game_card').single.url.queryParametersAll;
      expect(q['select'], [
        'id,title,sport:sport_key,game_type,start_at,end_at',
      ]);
      expect(q['title'], ['ilike.%fri%']);
      expect(q['is_cancelled'], ['eq.false']);
      expect(q['order']!.single, startsWith('start_at.desc'));
      expect(q['limit'], ['20']);
      expect(rows.single['id'], 'g1');
      expect(rows.single['title'], isNull);
      expect(rows.single['sport'], isNull);
      expect(rows.single['end_at'], isNull);
    },
  );

  test('organiser hosted rows read v_game_card by profile and sport', () async {
    final client = buildTestSupabaseClient((r) async {
      seen.add(r);
      if (r.url.path == '/rest/v1/v_game_card') {
        return json(r, [
          {'id': 'g1', 'is_cancelled': false, 'start_at': null},
        ]);
      }
      return json(r, <dynamic>[]);
    });
    const args = SportProfileRouteArgs(
      profileId: 'prof-org',
      userId: 'user-1',
      displayName: 'Org',
      personaType: 'organiser',
      sportId: 'sport-1',
      sportKey: 'padel',
      sportName: 'Padel',
    );

    final rows = await fetchHostedGameRows(supabase: client, args: args);

    expect(at('/rest/v1/games'), isEmpty);
    final q = at('/rest/v1/v_game_card').single.url.queryParametersAll;
    expect(q['select'], ['id,is_cancelled,start_at']);
    expect(q['creator_profile_id'], ['eq.prof-org']);
    expect(q['sport_id'], ['eq.sport-1']);
    expect(rows.single['id'], 'g1');
  });
}
