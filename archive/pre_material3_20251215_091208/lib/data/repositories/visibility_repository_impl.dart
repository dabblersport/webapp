import 'package:dabbler/core/fp/failure.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/result.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'base_repository.dart';
import 'visibility_repository.dart';

final visibilityRepositoryProvider = Provider<VisibilityRepository>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return VisibilityRepositoryImpl(service);
});

class VisibilityRepositoryImpl extends BaseRepository
    implements VisibilityRepository {
  VisibilityRepositoryImpl(super.svc);

  @override
  Future<Result<bool, Failure>> canViewOwner({
    required String ownerId,
    required String visibility,
  }) async {
    final viewer = svc.authUserId();
    if (viewer == null) {
      return Ok(false);
    }

    if (viewer == ownerId) {
      return Ok(true);
    }

    final adminResult = await isAdmin();
    final isViewerAdmin = adminResult.fold((_) => false, (value) => value);
    if (isViewerAdmin) {
      return Ok(true);
    }

    switch (visibility) {
      case 'public':
        return Ok(true);
      case 'hidden':
        return Ok(false);
      case 'circle':
        final syncedResult = await areSynced(ownerId);
        return syncedResult.fold((_) => Ok(false), (isSynced) => Ok(isSynced));
      default:
        return Ok(false);
    }
  }

  @override
  Future<Result<bool, Failure>> canReadRow({
    required String ownerId,
    required String visibility,
  }) {
    return canViewOwner(ownerId: ownerId, visibility: visibility);
  }

  @override
  Future<Result<bool, Failure>> areSynced(String otherUserId) async {
    final viewer = svc.authUserId();
    if (viewer == null) {
      return Ok(false);
    }

    try {
      final response = await svc.client
          .from('friendships')
          .select('status')
          .or(
            'and(user_id.eq.$viewer,peer_user_id.eq.$otherUserId),'
            'and(user_id.eq.$otherUserId,peer_user_id.eq.$viewer)',
          )
          .inFilter('status', ['accepted', 'pending'])
          .limit(1)
          .maybeSingle();

      return Ok(response != null);
    } on PostgrestException {
      return Ok(false);
    } catch (_) {
      return Ok(false);
    }
  }

  @override
  Future<Result<bool, Failure>> isAdmin() async {
    final userId = svc.authUserId();
    if (userId == null) {
      return Ok(false);
    }

    try {
      final response = await svc.client
          .from('app_admins')
          .select('user_id')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      return Ok(response != null);
    } on PostgrestException {
      return Ok(false);
    } catch (_) {
      return Ok(false);
    }
  }
}
