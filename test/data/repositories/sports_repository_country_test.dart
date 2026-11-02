import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/repositories/sports_repository.dart';

import '../../helpers/supabase_test_client.dart';

/// KAN-675: the sign-up sports picker was empty for Global users because the
/// country filter returned no rows. Every active sport must come back for
/// GLOBAL, for a code that matches nothing, and for no country at all.
Map<String, dynamic> _sport(String id, String name) => {
  'id': id,
  'name_en': name,
  'name_ar': null,
  'sport_key': name.toLowerCase(),
  'emoji': null,
  'category': null,
  'color_code': null,
};

void main() {
  late List<http.Request> sent;

  SportsRepository build(
    List<Map<String, dynamic>> Function(http.Request) rowsFor,
  ) {
    sent = [];
    final client = buildTestSupabaseClient((request) async {
      sent.add(request);
      return jsonListResponse(rowsFor(request), request: request);
    });
    return SportsRepository(SupabaseService(client, SupabaseErrorMapper()));
  }

  final all = [_sport('1', 'Football'), _sport('2', 'Padel')];
  bool filtered(http.Request r) =>
      r.url.queryParameters.containsKey('popularity_countries');
  List<String> names(Result<List<Sport>, Failure> result) =>
      result.fold((_) => <String>[], (s) => s.map((e) => e.nameEn).toList());

  test('GLOBAL returns all active sports without the country filter', () async {
    final repo = build((r) => filtered(r) ? [] : all);

    final result = await repo.getActiveSportsForCountry('GLOBAL');

    expect(result.isSuccess, isTrue);
    expect(names(result), ['Football', 'Padel']);
    expect(sent.any(filtered), isFalse);
  });

  test(
    'a country code that matches no sport returns all active sports',
    () async {
      final repo = build((r) => filtered(r) ? [] : all);

      final result = await repo.getActiveSportsForCountry('ZZ');

      expect(names(result), ['Football', 'Padel']);
      expect(sent.where(filtered), hasLength(1));
    },
  );

  test('a matched country keeps only its sports', () async {
    final repo = build((r) => filtered(r) ? [_sport('2', 'Padel')] : all);

    final result = await repo.getActiveSportsForCountry('AE');

    expect(names(result), ['Padel']);
  });

  test('null and empty country return all active sports', () async {
    final repo = build((r) => all);

    for (final code in [null, '']) {
      final result = await repo.getActiveSportsForCountry(code);
      expect(names(result), ['Football', 'Padel']);
    }
  });
}
