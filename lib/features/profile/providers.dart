import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile.dart';
import '../../data/repositories/profiles_repository.dart';
import '../../data/repositories/profiles_repository_impl.dart';
import '../../core/data/supabase_remote_data_source.dart';

final profilesRepositoryProvider = Provider<ProfilesRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return ProfilesRepositoryImpl(svc);
});

final myProfileStreamProvider = StreamProvider<Result<Profile?, Failure>>((
  ref,
) {
  return ref.watch(profilesRepositoryProvider).watchMyProfile();
});
