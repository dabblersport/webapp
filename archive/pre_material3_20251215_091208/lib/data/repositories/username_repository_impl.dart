import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import '../models/profile.dart';
import 'username_repository.dart';

class UsernameRepositoryImpl implements UsernameRepository {
  UsernameRepositoryImpl(this.svc);

  final SupabaseService svc;

  SupabaseClient get _client => svc.client;

  @override
  Future<Result<bool, Failure>> isAvailable(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return Ok(true);
    }
    try {
      final row = await _client
          .from('profiles')
          .select('id')
          .eq('username', trimmed)
          .maybeSingle();
      return Ok(row == null);
    } catch (error) {
      return Err(
        ServerFailure(
          message: 'Failed to check username availability',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Profile, Failure>> getByUsername(String username) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('username', username.trim())
          .maybeSingle();
      if (row == null) {
        return Err(const NotFoundFailure(message: 'Username not found'));
      }
      return Ok(Profile.fromJson(Map<String, dynamic>.from(row)));
    } catch (error) {
      return Err(
        ServerFailure(
          message: 'Failed to fetch profile by username',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<Profile>, Failure>> search({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      dynamic builder = _client.from('profiles').select();
      final trimmed = query.trim();
      if (trimmed.isNotEmpty) {
        builder = builder.ilike('username', '%$trimmed%');
      }
      builder = builder
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);
      final data = await builder;
      final rows = (data as List<dynamic>)
          .map(
            (row) => Profile.fromJson(
              Map<String, dynamic>.from(row as Map<String, dynamic>),
            ),
          )
          .toList(growable: false);
      return Ok(rows);
    } catch (error) {
      return Err(
        ServerFailure(message: 'Failed to search usernames', cause: error),
      );
    }
  }

  @override
  Future<Result<Profile, Failure>> setUsernameForProfile({
    required String profileId,
    required String username,
  }) async {
    final trimmed = username.trim();
    try {
      final row = await _client
          .from('profiles')
          .update({'username': trimmed})
          .eq('id', profileId)
          .select()
          .maybeSingle();
      if (row == null) {
        return Err(
          const NotFoundFailure(message: 'Profile not found or not owned'),
        );
      }
      return Ok(Profile.fromJson(Map<String, dynamic>.from(row)));
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return Err(const ConflictFailure(message: 'Username already taken'));
      }
      return Err(
        ServerFailure(message: 'Failed to set username', cause: error),
      );
    } catch (error) {
      return Err(
        ServerFailure(message: 'Failed to set username', cause: error),
      );
    }
  }

  @override
  Future<Result<Profile, Failure>> setMyUsernameForType({
    required String profileType,
    required String username,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return Err(const AuthFailure(message: 'Not authenticated'));
    }
    final trimmed = username.trim();
    try {
      final profileRow = await _client
          .from('profiles')
          .select('id')
          .eq('user_id', uid)
          .eq('profile_type', profileType)
          .maybeSingle();
      if (profileRow == null) {
        return Err(
          NotFoundFailure(
            message: 'Profile of type $profileType not found for current user',
          ),
        );
      }
      final profileMap = Map<String, dynamic>.from(profileRow);
      final profileId = profileMap['id'] as String;
      final row = await _client
          .from('profiles')
          .update({'username': trimmed})
          .eq('id', profileId)
          .select()
          .maybeSingle();
      if (row == null) {
        return Err(
          const NotFoundFailure(message: 'Profile not found after update'),
        );
      }
      return Ok(Profile.fromJson(Map<String, dynamic>.from(row)));
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return Err(const ConflictFailure(message: 'Username already taken'));
      }
      return Err(
        ServerFailure(message: 'Failed to update username', cause: error),
      );
    } catch (error) {
      return Err(
        ServerFailure(message: 'Failed to update username', cause: error),
      );
    }
  }

  @override
  Stream<Result<Profile, Failure>> myProfileTypeStream(
    String profileType,
  ) async* {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      yield Err(const AuthFailure(message: 'Not authenticated'));
      return;
    }
    try {
      // Query once instead of streaming for now
      final data = await _client
          .from('profiles')
          .select()
          .eq('user_id', uid)
          .eq('profile_type', profileType)
          .maybeSingle();

      if (data == null) {
        yield Err(const NotFoundFailure(message: 'Profile not found'));
        return;
      }

      final map = Map<String, dynamic>.from(data);
      yield Ok(Profile.fromJson(map));
    } catch (error) {
      yield Err(ServerFailure(message: 'Failed to get profile', cause: error));
    }
  }
}
