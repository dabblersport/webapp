// KAN-1014: the organiser's ban list and lifting a ban.

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/bans/domain/ban_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BansRepository {
  Future<Result<List<OrganiserBan>, Failure>> listMyBans();
  Future<Result<void, Failure>> liftBan(String banId);
}

class SupabaseBansRepository implements BansRepository {
  const SupabaseBansRepository(this._db);
  final SupabaseClient _db;

  @override
  Future<Result<List<OrganiserBan>, Failure>> listMyBans() =>
      Result.guard(() async {
        final data = await _db.rpc(SupabaseConfig.rpcListMyBansFn);
        return [
          for (final row in (data as List? ?? const []))
            OrganiserBan.fromJson(Map<String, dynamic>.from(row as Map)),
        ];
      }, (e) => Failure.from(e));

  @override
  Future<Result<void, Failure>> liftBan(String banId) => Result.guard(() async {
    await _db.rpc(SupabaseConfig.rpcLiftBanFn, params: {'p_ban_id': banId});
  }, (e) => Failure.from(e));
}

final bansRepositoryProvider = Provider<BansRepository>(
  (ref) => SupabaseBansRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in organiser's bans, newest first. Invalidate after a change.
final myBansProvider = FutureProvider.autoDispose<List<OrganiserBan>>((
  ref,
) async {
  final r = await ref.watch(bansRepositoryProvider).listMyBans();
  return r.fold((f) => throw f, (bans) => bans);
});
