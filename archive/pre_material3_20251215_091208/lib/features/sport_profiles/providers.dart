import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/sport_profile.dart';
import 'package:dabbler/data/repositories/sport_profiles_repository.dart';
import 'package:dabbler/data/repositories/sport_profiles_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

final sportProfilesRepositoryProvider = Provider<SportProfilesRepository>((
  ref,
) {
  final svc = ref.watch(supabaseServiceProvider);
  return SportProfilesRepositoryImpl(svc);
});

final mySportProfilesStreamProvider =
    StreamProvider<Result<List<SportProfile>, Failure>>((ref) {
      return ref.watch(sportProfilesRepositoryProvider).watchMySports();
    });

final mySportProfilesProvider =
    FutureProvider<Result<List<SportProfile>, Failure>>((ref) async {
      return ref.watch(sportProfilesRepositoryProvider).getMySports();
    });
