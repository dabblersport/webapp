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
}
