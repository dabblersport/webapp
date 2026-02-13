import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/repositories/block_repository.dart';
import 'package:dabbler/data/repositories/block_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

/// Singleton BlockRepository provider.
final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return BlockRepositoryImpl(svc);
});

/// Cached set of all user IDs that are blocked in either direction.
/// Invalidate this whenever a block/unblock action occurs.
final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(blockRepositoryProvider);
  final result = await repo.getBlockedUserIds();
  return result.fold((err) => <String>{}, (ids) => ids.toSet());
});

/// Check if a specific user is blocked (bidirectional).
/// Uses the cached blockedUserIdsProvider for fast lookups.
final isUserBlockedProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  otherUserId,
) async {
  final blockedIds = await ref.watch(blockedUserIdsProvider.future);
  return blockedIds.contains(otherUserId);
});

/// Blocked users with profile details (for the management screen).
final blockedUsersWithProfilesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final repo = ref.watch(blockRepositoryProvider);
      final result = await repo.getBlockedUsersWithProfiles();
      return result.fold(
        (err) => <Map<String, dynamic>>[],
        (profiles) => profiles,
      );
    });
