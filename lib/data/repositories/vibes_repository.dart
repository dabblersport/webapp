import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/data/repositories/base_repository.dart';

/// Repository for loading vibes from `public.vibes`.
class VibesRepository extends BaseRepository {
  VibesRepository(super.svc);

  /// All active vibes, ordered by sort_order.
  Future<Result<List<Vibe>, Failure>> getActiveVibes() => guard(() async {
    final rows = await svc.client
        .from('vibes')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return rows.map((r) => Vibe.fromMap(r)).toList();
  });
}
