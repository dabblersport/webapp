import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/user_circle.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

import 'user_circles_repository.dart';

class UserCirclesRepositoryImpl implements UserCirclesRepository {
  UserCirclesRepositoryImpl(this._svc);

  final SupabaseService _svc;

  SupabaseClient get _db => _svc.client;

  String? get _uid => _db.auth.currentUser?.id;

  // ── listCircles ────────────────────────────────────────────────────────────

  @override
  Future<Result<List<UserCircle>, Failure>> listCircles({
    required String ownerProfileId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const Err(AuthFailure(message: 'Not authenticated'));
    }
    try {
      // Fetch circles with member counts via a sub-select or count.
      final rows = await _db
          .from('circles')
          .select('id, name, owner_profile_id, created_at')
          .eq('owner_profile_id', ownerProfileId)
          .order('created_at', ascending: false);

      // Fetch member counts for all circles in one query.
      final circleIds = rows
          .map((r) => r['id'] as String)
          .toList(growable: false);

      Map<String, int> memberCounts = {};
      if (circleIds.isNotEmpty) {
        final countRows = await _db
            .from('circle_members')
            .select('circle_id')
            .inFilter('circle_id', circleIds);

        for (final row in countRows) {
          final cId = row['circle_id'] as String?;
          if (cId != null) memberCounts[cId] = (memberCounts[cId] ?? 0) + 1;
        }
      }

      final circles = rows.map((r) {
        final id = r['id'] as String;
        return UserCircle(
          id: id,
          name: r['name'] as String,
          ownerProfileId: r['owner_profile_id'] as String,
          memberCount: memberCounts[id] ?? 0,
          createdAt: r['created_at'] != null
              ? DateTime.tryParse(r['created_at'] as String)
              : null,
        );
      }).toList();

      return Ok(circles);
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }

  // ── createCircle ───────────────────────────────────────────────────────────

  @override
  Future<Result<UserCircle, Failure>> createCircle({
    required String ownerProfileId,
    required String name,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const Err(AuthFailure(message: 'Not authenticated'));
    }
    try {
      final rows = await _db
          .from('circles')
          .insert({'name': name.trim(), 'owner_profile_id': ownerProfileId})
          .select('id, name, owner_profile_id, created_at')
          .single();

      // Ensure the owner is a member of their own circle (idempotent).
      await _db.from('circle_members').upsert({
        'circle_id': rows['id'] as String,
        'member_profile_id': ownerProfileId,
      }, onConflict: 'circle_id,member_profile_id');

      return Ok(
        UserCircle(
          id: rows['id'] as String,
          name: rows['name'] as String,
          ownerProfileId: rows['owner_profile_id'] as String,
          createdAt: rows['created_at'] != null
              ? DateTime.tryParse(rows['created_at'] as String)
              : null,
        ),
      );
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }

  // ── updateCircle ───────────────────────────────────────────────────────────

  @override
  Future<Result<UserCircle, Failure>> updateCircle(
    String circleId, {
    required String ownerProfileId,
    required String name,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const Err(AuthFailure(message: 'Not authenticated'));
    }
    try {
      final rows = await _db
          .from('circles')
          .update({'name': name.trim()})
          .eq('id', circleId)
          .eq('owner_profile_id', ownerProfileId)
          .select('id, name, owner_profile_id, created_at')
          .single();

      return Ok(
        UserCircle(
          id: rows['id'] as String,
          name: rows['name'] as String,
          ownerProfileId: rows['owner_profile_id'] as String,
          createdAt: rows['created_at'] != null
              ? DateTime.tryParse(rows['created_at'] as String)
              : null,
        ),
      );
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }

  // ── deleteCircle ───────────────────────────────────────────────────────────

  @override
  Future<Result<void, Failure>> deleteCircle(
    String circleId, {
    required String ownerProfileId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const Err(AuthFailure(message: 'Not authenticated'));
    }
    try {
      await _db
          .from('circles')
          .delete()
          .eq('id', circleId)
          .eq('owner_profile_id', ownerProfileId);
      return const Ok(null);
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }

  // ── getCircleMembers ───────────────────────────────────────────────────────

  @override
  Future<Result<List<CircleMember>, Failure>> getCircleMembers(
    String circleId,
  ) async {
    try {
      // Join with profiles to get display info.
      final rows = await _db
          .from('circle_members')
          .select(
            'member_profile_id, added_at, '
            'profiles:member_profile_id(user_id, display_name, username, avatar_url)',
          )
          .eq('circle_id', circleId)
          .order('added_at', ascending: false);

      final members = rows.map((r) {
        final profile = r['profiles'] as Map<String, dynamic>?;
        return CircleMember(
          profileId: r['member_profile_id'] as String,
          userId: profile?['user_id'] as String?,
          displayName: profile?['display_name'] as String?,
          username: profile?['username'] as String?,
          avatarUrl: profile?['avatar_url'] as String?,
          addedAt: r['added_at'] != null
              ? DateTime.tryParse(r['added_at'] as String)
              : null,
        );
      }).toList();

      return Ok(members);
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }

  // ── addMember ──────────────────────────────────────────────────────────────

  @override
  Future<Result<void, Failure>> addMember(
    String circleId,
    String memberProfileId, {
    String? memberUserId,
  }) async {
    try {
      await _db.from('circle_members').upsert({
        'circle_id': circleId,
        'member_profile_id': memberProfileId,
      }, onConflict: 'circle_id,member_profile_id');
      return const Ok(null);
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }

  // ── removeMember ───────────────────────────────────────────────────────────

  @override
  Future<Result<void, Failure>> removeMember(
    String circleId,
    String memberProfileId,
  ) async {
    try {
      await _db
          .from('circle_members')
          .delete()
          .eq('circle_id', circleId)
          .eq('member_profile_id', memberProfileId);
      return const Ok(null);
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }

  // ── getFollowers ───────────────────────────────────────────────────────────

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> getFollowers({
    required String ownerProfileId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const Err(AuthFailure(message: 'Not authenticated'));
    }

    try {
      // Source of truth for follower recency is the follow relationship.
      // This mirrors the logic in profile providers (profile_follows + join).
      final rows = await _db
          .from('profile_follows')
          .select(
            'created_at, '
            'profiles!fk_follower_profile('
            'id, user_id, display_name, username, avatar_url, '
            'verified, persona_type, is_active'
            ')',
          )
          .eq('following_profile_id', ownerProfileId)
          .order('created_at', ascending: false);

      return Ok(rows.cast<Map<String, dynamic>>());
    } catch (e) {
      return Err(_svc.mapPostgrestError(e));
    }
  }
}
