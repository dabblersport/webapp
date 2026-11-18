import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/showup_rate/data/showup_rate_repository.dart';
import 'package:dabbler/features/showup_rate/domain/showup_rate.dart';

final showUpRateRepositoryProvider = Provider<ShowUpRateRepository>(
  (ref) => SupabaseShowUpRateRepository(Supabase.instance.client),
);

/// The server's show-up rate for a user id, or null when the read fails
/// (render nothing; never a guessed number).
final showUpRateProvider = FutureProvider.autoDispose
    .family<ShowUpRate?, String>((ref, userId) async {
      final result = await ref
          .watch(showUpRateRepositoryProvider)
          .rateFor(userId);
      return result.fold((_) => null, (r) => r);
    });
