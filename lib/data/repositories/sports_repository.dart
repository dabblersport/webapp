import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/repositories/base_repository.dart';

/// Repository for loading sports from `public.sports`.
class SportsRepository extends BaseRepository {
  SportsRepository(super.svc);

  /// All active sports, ordered by name_en.
  Future<Result<List<Sport>, Failure>> getActiveSports() => guard(() async {
    final rows = await svc.client
        .from('sports')
        .select()
        .eq('is_active', true)
        .order('name_en');
    return rows.map((r) => Sport.fromMap(r)).toList();
  });

  /// Active sports whose popularity_countries array contains [countryCode].
  /// Falls back to all active sports when countryCode is null or unmatched.
  Future<Result<List<Sport>, Failure>> getActiveSportsForCountry(
    String? countryCode,
  ) =>
      guard(() async {
        if (countryCode == null || countryCode.isEmpty) {
          return (await getActiveSports()).fold(
            (err) => throw Exception(err.message),
            (sports) => sports,
          );
        }

        final rows = await svc.client
            .from('sports')
            .select()
            .eq('is_active', true)
            .contains('popularity_countries', [countryCode])
            .order('name_en');

        // Fall back to all active sports if no results for this country
        if (rows.isEmpty) {
          final fallback = await svc.client
              .from('sports')
              .select()
              .eq('is_active', true)
              .order('name_en');
          return fallback.map((r) => Sport.fromMap(r)).toList();
        }

        return rows.map((r) => Sport.fromMap(r)).toList();
      });
}
