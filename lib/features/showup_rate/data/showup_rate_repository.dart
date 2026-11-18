import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/showup_rate/domain/showup_rate.dart';

/// Reads a user's show-up rate from `rpc_showup_rate` (KAN-994).
abstract class ShowUpRateRepository {
  Future<Result<ShowUpRate, Failure>> rateFor(String userId);
}

class SupabaseShowUpRateRepository implements ShowUpRateRepository {
  SupabaseShowUpRateRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<ShowUpRate, Failure>> rateFor(String userId) =>
      Result.guard(() async {
        final Object? row = await _client.rpc(
          SupabaseConfig.rpcShowUpRate,
          params: {'p_user_id': userId},
        );
        return ShowUpRate.fromJson(Map<String, dynamic>.from(row! as Map));
      }, Failure.from);
}
