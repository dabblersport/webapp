import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/display_name_rules.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import '../models/profile.dart';
import 'display_name_repository.dart';

class DisplayNameRepositoryImpl implements DisplayNameRepository {
  DisplayNameRepositoryImpl(this.svc);

  final SupabaseService svc;

  SupabaseClient get _db => svc.client;

  @override
  Future<Result<bool, Failure>> isAvailable(String displayName) async {
    try {
      final norm = DisplayNameRules.normalize(displayName);
      final row = await _db
          .from('profiles')
          .select('id')
          .eq('display_name_norm', norm)
          .maybeSingle();
      return Ok(row == null);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  @override
  Future<Result<List<Profile>, Failure>> search({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var request = _db.from('profiles').select();
      final trimmedQuery = query.trim();
      if (trimmedQuery.isNotEmpty) {
        request = request.ilike('display_name', '%$trimmedQuery%');
      }
      final response = await request
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final profiles = rows.map(Profile.fromJson).toList();
      return Ok(profiles);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  @override
  Future<Result<Profile, Failure>> setDisplayNameForProfile({
    required String profileId,
    required String displayName,
  }) async {
    if (!DisplayNameRules.isLengthValid(displayName)) {
      return Err(
        const ValidationFailure(message: 'Display name must be 2–50 chars.'),
      );
    }

    try {
      final patch = {
        'display_name': displayName.trim(),
        'display_name_norm': DisplayNameRules.normalize(displayName),
      };
      final response = await _db
          .from('profiles')
          .update(patch)
          .eq('id', profileId)
          .select()
          .maybeSingle();
      if (response == null) {
        return Err(
          const NotFoundFailure(message: 'Profile not found or not owned'),
        );
      }
      final row = Map<String, dynamic>.from(response as Map);
      return Ok(Profile.fromJson(row));
    } on PostgrestException catch (error) {
      final code = error.code;
      if (code == '23505') {
        return Err(
          const ConflictFailure(message: 'Display name already in use'),
        );
      }
      if (code == '23514') {
        return Err(
          const ValidationFailure(
            message:
                'Display name violates server rules or conflicts with username',
          ),
        );
      }
      return Err(svc.mapPostgrestError(error));
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  @override
  Future<Result<Profile, Failure>> setMyDisplayNameForType({
    required String profileType,
    required String displayName,
  }) async {
    if (!DisplayNameRules.isLengthValid(displayName)) {
      return Err(
        const ValidationFailure(message: 'Display name must be 2–50 chars.'),
      );
    }

    final uid = svc.authUserId();
    if (uid == null) {
      return Err(const AuthFailure(message: 'Not signed in'));
    }

    try {
      final existing = await _db
          .from('profiles')
          .select('id')
          .eq('user_id', uid)
          .eq('profile_type', profileType)
          .maybeSingle();
      if (existing == null) {
        return Err(
          NotFoundFailure(
            message: 'Profile of type $profileType not found for current user',
          ),
        );
      }
      final profileRow = Map<String, dynamic>.from(existing as Map);
      final profileId = profileRow['id'] as String;
      final response = await _db
          .from('profiles')
          .update({
            'display_name': displayName.trim(),
            'display_name_norm': DisplayNameRules.normalize(displayName),
          })
          .eq('id', profileId)
          .select()
          .maybeSingle();
      if (response == null) {
        return Err(
          const NotFoundFailure(message: 'Profile not found after update'),
        );
      }
      final row = Map<String, dynamic>.from(response as Map);
      return Ok(Profile.fromJson(row));
    } on PostgrestException catch (error) {
      final code = error.code;
      if (code == '23505') {
        return Err(
          const ConflictFailure(message: 'Display name already in use'),
        );
      }
      if (code == '23514') {
        return Err(
          const ValidationFailure(
            message:
                'Display name violates server rules or conflicts with username',
          ),
        );
      }
      return Err(svc.mapPostgrestError(error));
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  @override
  Stream<Result<Profile, Failure>> myProfileTypeStream(
    String profileType,
  ) async* {
    final uid = svc.authUserId();
    if (uid == null) {
      yield Err(const AuthFailure(message: 'Not signed in'));
      return;
    }

    Future<Result<Profile, Failure>> fetch() async {
      try {
        final response = await _db
            .from('profiles')
            .select()
            .eq('user_id', uid)
            .eq('profile_type', profileType)
            .maybeSingle();
        if (response == null) {
          return Err(const NotFoundFailure(message: 'Profile not found'));
        }
        final row = Map<String, dynamic>.from(response as Map);
        return Ok(Profile.fromJson(row));
      } catch (error) {
        return Err(svc.mapPostgrestError(error));
      }
    }

    try {
      yield await fetch();

      final stream = _db.from('profiles').stream(primaryKey: ['id']);

      await for (final _ in stream) {
        yield await fetch();
      }
    } catch (error) {
      yield Err(svc.mapPostgrest(error as PostgrestException));
    }
  }
}
