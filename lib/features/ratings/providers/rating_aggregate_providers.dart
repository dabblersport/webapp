import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/ratings/data/rating_aggregate_repository.dart';
import 'package:dabbler/features/ratings/domain/rating_aggregate.dart';

final ratingAggregateRepositoryProvider = Provider<RatingAggregateRepository>(
  (ref) => SupabaseRatingAggregateRepository(Supabase.instance.client),
);

/// The aggregate for a user id, or null when the server returns none (below
/// the threshold) or the read fails. Null means: render nothing.
final ratingAggregateProvider = FutureProvider.autoDispose
    .family<RatingAggregate?, String>((ref, userId) async {
      final result = await ref
          .watch(ratingAggregateRepositoryProvider)
          .aggregateFor(userId);
      return result.fold((_) => null, (a) => a);
    });
