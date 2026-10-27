import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/ratings/domain/rating_aggregate.dart';

/// Reads a player's rating aggregate (KAN-666). The server decides the
/// visibility threshold: below it there is no row, and this returns null.
abstract class RatingAggregateRepository {
  Future<Result<RatingAggregate?, Failure>> aggregateFor(String userId);
}

class SupabaseRatingAggregateRepository implements RatingAggregateRepository {
  SupabaseRatingAggregateRepository(this._client);

  /// `docs/ratings-contract.md` section 3 and 4.
  static const String aggregateFn = 'rpc_get_user_rating_aggregate';
  static const String dimensionsFn = 'rpc_list_rating_dimensions';

  final SupabaseClient _client;

  @override
  Future<Result<RatingAggregate?, Failure>> aggregateFor(String userId) =>
      Result.guard(() async {
        final rows =
            await _client.rpc(aggregateFn, params: {'p_user_id': userId})
                as List;
        if (rows.isEmpty) return null;
        final dims = await _client.rpc(dimensionsFn) as List;
        final labels = <String, RatingTag>{
          for (final d in dims)
            '${(d as Map)['key']}': RatingTag(
              key: '${d['key']}',
              labelEn: '${d['label_en'] ?? d['key']}',
              labelAr: '${d['label_ar'] ?? ''}',
            ),
        };
        return RatingAggregate.fromRow(
          Map<String, dynamic>.from(rows.first as Map),
          labels,
        );
      }, Failure.from);
}
