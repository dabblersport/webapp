import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/repositories/base_repository.dart';

/// Country code a Global user resolves to; no sport lists it in
/// popularity_countries.
const _globalCountryCode = 'GLOBAL';

/// Repository for loading sports from `public.sports`.
class SportsRepository extends BaseRepository {
  SportsRepository(super.svc);

  /// All active sports, ordered by name_en.
  Future<Result<List<Sport>, Failure>> getActiveSports() => guard(() async {
    final rows = await svc.client
        .from(SupabaseConfig.sportsTable)
        .select()
        .eq('is_active', true)
        .order('name_en');
    return rows.map((r) => Sport.fromMap(r)).toList();
  });

  /// Active sports whose popularity_countries array contains [countryCode].
  /// Returns every active sport when the country is unknown (null/empty), is
  /// the `GLOBAL` code (no sport lists it in popularity_countries), or when
  /// the country filter matches no active sport.
  Future<Result<List<Sport>, Failure>> getActiveSportsForCountry(
    String? countryCode,
  ) => guard(() async {
    Future<List<Sport>> allActive() async => (await getActiveSports()).fold(
      (err) => throw Exception(err.message),
      (sports) => sports,
    );

    if (countryCode == null ||
        countryCode.isEmpty ||
        countryCode == _globalCountryCode) {
      return allActive();
    }

    final rows = await svc.client
        .from(SupabaseConfig.sportsTable)
        .select()
        .eq('is_active', true)
        .contains('popularity_countries', [countryCode])
        .order('name_en');

    if (rows.isEmpty) return allActive();
    return rows.map((r) => Sport.fromMap(r)).toList();
  });

  /// Active challenge-eligible sports filtered by country, with fallback.
  Future<Result<List<Sport>, Failure>> getActiveChallengeSportsForCountry(
    String? countryCode,
  ) => guard(() async {
    var query = svc.client
        .from(SupabaseConfig.sportsTable)
        .select()
        .eq('is_active', true)
        .eq('is_challenge_sport', true);

    if (countryCode != null && countryCode.isNotEmpty) {
      final rows = await query
          .contains('popularity_countries', [countryCode])
          .order('name_en');
      if (rows.isNotEmpty) return rows.map((r) => Sport.fromMap(r)).toList();
    }

    // Fallback: all challenge sports regardless of country
    final fallback = await query.order('name_en');
    return fallback.map((r) => Sport.fromMap(r)).toList();
  });
}
