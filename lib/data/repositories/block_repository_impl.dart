import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'base_repository.dart';
import 'block_repository.dart';

/// Unified implementation of user-level blocking backed by the `user_blocks` table.
/// All IDs are auth.users.id — never profile IDs.
class BlockRepositoryImpl extends BaseRepository implements BlockRepository {
  const BlockRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<Result<void, Failure>> blockUser(String targetUserId) async {
    return guard<void>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');
      if (uid == targetUserId) throw Exception('Cannot block yourself');

      // Server-side RPC handles insert into user_blocks + removes follows/friendships
      await _db.rpc('rpc_block_user', params: {'p_peer': targetUserId});
    });
  }

  @override
  Future<Result<void, Failure>> unblockUser(String targetUserId) async {
    return guard<void>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      await _db.rpc('rpc_unblock_user', params: {'p_peer': targetUserId});
    });
  }

  @override
  Future<Result<List<String>, Failure>> getBlockedUserIds() async {
    return guard<List<String>>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      // Get users I blocked
      final blockedByMe = await _db
          .from('user_blocks')
          .select('blocked_user_id')
          .eq('blocker_user_id', uid);

      // Get users who blocked me
      final blockedMe = await _db
          .from('user_blocks')
          .select('blocker_user_id')
          .eq('blocked_user_id', uid);

      final ids = <String>{
        ...(blockedByMe as List).map((r) => r['blocked_user_id'] as String),
        ...(blockedMe as List).map((r) => r['blocker_user_id'] as String),
      };

      return ids.toList();
    });
  }

  @override
  Future<Result<bool, Failure>> isBlocked(String otherUserId) async {
    return guard<bool>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      // Check if I blocked them
      final byMe = await _db
          .from('user_blocks')
          .select('id')
          .eq('blocker_user_id', uid)
          .eq('blocked_user_id', otherUserId)
          .maybeSingle();
      if (byMe != null) return true;

      // Check if they blocked me
      final byThem = await _db
          .from('user_blocks')
          .select('id')
          .eq('blocker_user_id', otherUserId)
          .eq('blocked_user_id', uid)
          .maybeSingle();
      return byThem != null;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>>
  getBlockedUsersWithProfiles() async {
    return guard<List<Map<String, dynamic>>>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      // Fetch users I have actively blocked (not users who blocked me)
      final rows = await _db
          .from('user_blocks')
          .select('blocked_user_id, created_at')
          .eq('blocker_user_id', uid)
          .order('created_at', ascending: false);

      if ((rows as List).isEmpty) return [];

      final blockedIds = rows
          .map((r) => r['blocked_user_id'] as String)
          .toList();

      // Fetch profile details
      final profiles = await _db
          .from('profiles')
          .select('user_id, display_name, username, avatar_url')
          .inFilter('user_id', blockedIds);

      final profileMap = <String, Map<String, dynamic>>{
        for (final p in (profiles as List)) p['user_id'] as String: p,
      };

      return blockedIds.map((id) {
        final profile = profileMap[id];
        return {
          'user_id': id,
          'display_name': profile?['display_name'] ?? 'Unknown',
          'username': profile?['username'] ?? '',
          'avatar_url': profile?['avatar_url'],
          'blocked_at': rows.firstWhere(
            (r) => r['blocked_user_id'] == id,
          )['created_at'],
        };
      }).toList();
    });
  }
}
