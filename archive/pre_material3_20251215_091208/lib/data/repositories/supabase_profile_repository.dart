import 'package:fpdart/fpdart.dart';
import 'package:riverpod/riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import '../models/profile/user_profile.dart';
import 'profile_repository.dart';
import '../../features/misc/data/datasources/supabase_error_mapper.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';

/// Supabase-backed implementation of the core profile repository.
///
/// Feature code that needs to read or write profile data from Supabase
/// should prefer going through this repository (or its domain wrapper)
/// instead of reaching for `Supabase.instance.client` directly. This keeps
/// the mapping between the `profiles` table and [UserProfile] centralized
/// and makes it easier to evolve the schema safely.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({
    required SupabaseService service,
    required SupabaseErrorMapper errorMapper,
  }) : _service = service,
       _errorMapper = errorMapper;

  final SupabaseService _service;
  final SupabaseErrorMapper _errorMapper;

  static const String _table = 'profiles';

  /// Column projection used for all profile fetch/upsert operations.
  ///
  /// This list is kept in sync with [UserProfile.fromJson]. If you add or
  /// remove profile fields that should be available to the app, update both
  /// this constant and the factory in `user_profile.dart`.
  static const String _baseProfileColumns =
      'id, user_id, username, display_name, avatar_url, created_at, updated_at, bio, age, city, country, phone_number, email, gender, profile_type, intention, preferred_sport, interests, language, verified, is_active, geo_lat, geo_lng';

  @override
  Future<Either<Failure, UserProfile>> fetchProfile(String userId) async {
    try {
      final response = await _service
          .from(_table)
          .select(_baseProfileColumns)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return left(
          SupabaseNotFoundFailure(
            message: 'Profile not found for user $userId',
          ),
        );
      }

      return right(UserProfile.fromJson(response));
    } catch (error, stackTrace) {
      return left(_errorMapper.map(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> upsertProfile(
    UserProfile profile,
  ) async {
    try {
      final response = await _service
          .from(_table)
          .upsert(profile.toJson(), onConflict: 'user_id')
          .select(_baseProfileColumns)
          .single();

      return right(UserProfile.fromJson(response));
    } catch (error, stackTrace) {
      return left(_errorMapper.map(error, stackTrace: stackTrace));
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final mapper = ref.watch(supabaseErrorMapperProvider);
  return SupabaseProfileRepository(service: service, errorMapper: mapper);
});
