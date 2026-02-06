import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/profile.dart';
import '../../data/repositories/username_repository.dart';
import '../../data/repositories/username_repository_impl.dart';

final usernameRepositoryProvider = Provider.autoDispose<UsernameRepository>((
  ref,
) {
  final svc = ref.watch(supabaseServiceProvider);
  return UsernameRepositoryImpl(svc);
});

// availability
final usernameAvailabilityProvider = FutureProvider.autoDispose
    .family<Result<bool, Failure>, String>((ref, username) {
      final repo = ref.watch(usernameRepositoryProvider);
      return repo.isAvailable(username);
    });

// exact fetch
final profileByUsernameProvider = FutureProvider.autoDispose
    .family<Result<Profile, Failure>, String>((ref, username) {
      final repo = ref.watch(usernameRepositoryProvider);
      return repo.getByUsername(username);
    });

// search
final usernameSearchProvider = FutureProvider.autoDispose
    .family<
      Result<List<Profile>, Failure>,
      ({String query, int limit, int offset})
    >((ref, args) {
      final repo = ref.watch(usernameRepositoryProvider);
      return repo.search(
        query: args.query,
        limit: args.limit,
        offset: args.offset,
      );
    });

// set for profile id
final setUsernameForProfileProvider = FutureProvider.autoDispose
    .family<Result<Profile, Failure>, ({String profileId, String username})>((
      ref,
      args,
    ) {
      final repo = ref.watch(usernameRepositoryProvider);
      return repo.setUsernameForProfile(
        profileId: args.profileId,
        username: args.username,
      );
    });

// set for my profile type
final setMyUsernameForTypeProvider = FutureProvider.autoDispose
    .family<Result<Profile, Failure>, ({String profileType, String username})>((
      ref,
      args,
    ) {
      final repo = ref.watch(usernameRepositoryProvider);
      return repo.setMyUsernameForType(
        profileType: args.profileType,
        username: args.username,
      );
    });

// stream my profile of a type
final myProfileTypeStreamProvider = StreamProvider.autoDispose
    .family<Result<Profile, Failure>, String>((ref, profileType) {
      final repo = ref.watch(usernameRepositoryProvider);
      return repo.myProfileTypeStream(profileType);
    });
