import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

import '../models/friend_edge.dart';
import '../models/friendship.dart';
import 'friends_repository.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this.svc);

  final SupabaseService svc;

  SupabaseClient get _db => svc.client;

  String? get _currentUserId => _db.auth.currentUser?.id;

  Future<Result<List<Map<String, dynamic>>, Failure>> _fallbackInbox() async {
    final myId = _currentUserId;
    if (myId == null || myId.isEmpty) {
      return Err(const AuthFailure(message: 'Not authenticated'));
    }

    try {
      final rows = await _db
          .from('friendships')
          .select(
            'user_id, peer_user_id, requested_by, status, created_at, updated_at',
          )
          .eq('peer_user_id', myId)
          .eq('status', 'pending')
          .neq('requested_by', myId)
          .order('created_at', ascending: false);

      final payload = rows
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);

      final senderIds = payload
          .map((row) => row['user_id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (senderIds.isEmpty) return Ok(payload);

      final profilesRows = await _db
          .from('profiles')
          .select('user_id, display_name, avatar_url, username')
          .inFilter('user_id', senderIds);

      final profilesById = <String, Map<String, dynamic>>{};
      for (final dynamic row in profilesRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['user_id'];
        if (id is String && id.isNotEmpty) {
          profilesById[id] = map;
        }
      }

      final withProfiles = payload
          .map((row) {
            final id = row['user_id'];
            final peerProfile = (id is String) ? profilesById[id] : null;
            return {
              ...row,
              if (peerProfile != null) 'peer_profile': peerProfile,
            };
          })
          .toList(growable: false);

      return Ok(withProfiles);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  Future<Result<List<Map<String, dynamic>>, Failure>> _fallbackOutbox() async {
    final myId = _currentUserId;
    if (myId == null || myId.isEmpty) {
      return Err(const AuthFailure(message: 'Not authenticated'));
    }

    try {
      final rows = await _db
          .from('friendships')
          .select(
            'user_id, peer_user_id, requested_by, status, created_at, updated_at',
          )
          .eq('user_id', myId)
          .eq('status', 'pending')
          .eq('requested_by', myId)
          .order('created_at', ascending: false);

      final payload = rows
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);

      final peerIds = payload
          .map((row) => row['peer_user_id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (peerIds.isEmpty) return Ok(payload);

      final profilesRows = await _db
          .from('profiles')
          .select('user_id, display_name, avatar_url, username')
          .inFilter('user_id', peerIds);

      final profilesById = <String, Map<String, dynamic>>{};
      for (final dynamic row in profilesRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['user_id'];
        if (id is String && id.isNotEmpty) {
          profilesById[id] = map;
        }
      }

      final withProfiles = payload
          .map((row) {
            final id = row['peer_user_id'];
            final peerProfile = (id is String) ? profilesById[id] : null;
            return {
              ...row,
              if (peerProfile != null) 'peer_profile': peerProfile,
            };
          })
          .toList(growable: false);

      return Ok(withProfiles);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on RLS policy `friendships_insert_requester`.
  @override
  Future<Result<void, Failure>> sendFriendRequest(String peerUserId) async {
    try {
      await _db.rpc(
        'rpc_friend_request_send',
        params: {'p_peer_profile_id': peerUserId},
      );
      return Ok(null);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on RLS policy `friendships_update_parties`.
  @override
  Future<Result<void, Failure>> acceptFriendRequest(String peerUserId) async {
    try {
      await _db.rpc(
        'rpc_friend_request_accept',
        params: {'p_peer_profile_id': peerUserId},
      );
      return Ok(null);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on RLS policy `friendships_update_parties`.
  @override
  Future<Result<void, Failure>> rejectFriendRequest(String peerUserId) async {
    try {
      await _db.rpc(
        'rpc_friend_request_reject',
        params: {'p_peer_profile_id': peerUserId},
      );
      return Ok(null);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on RLS policy `friendships_update_parties`.
  @override
  Future<Result<void, Failure>> removeFriend(String peerUserId) async {
    try {
      await _db.rpc(
        'rpc_friend_remove',
        params: {'p_peer_profile_id': peerUserId},
      );
      return Ok(null);
    } on PostgrestException catch (error) {
      if ((error.code == '42883') ||
          ((error.details as String?)?.toLowerCase().contains(
                'rpc_friend_remove',
              ) ??
              false)) {
        try {
          await _db.rpc('rpc_friend_unfriend', params: {'p_peer': peerUserId});
          return Ok(null);
        } catch (fallbackError) {
          return Err(svc.mapPostgrestError(fallbackError));
        }
      }
      return Err(svc.mapPostgrestError(error));
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on RLS policy `friendships_select_parties`.
  @override
  Future<Result<List<Friendship>, Failure>> listFriendships() async {
    try {
      final rows = await _db
          .from('friendships')
          .select()
          .order('updated_at', ascending: false);
      final friendships = rows
          .map(
            (dynamic row) =>
                Friendship.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
      return Ok(friendships);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on stored procedure RLS visibility (typically `friendships_select_parties`).
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> inbox() async {
    try {
      final rows = await _db.rpc('rpc_friend_requests_inbox');
      if (rows is List) {
        final payload = rows
            .map((dynamic row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        return Ok(payload);
      }
      return Err(const ServerFailure(message: 'Unexpected inbox payload'));
    } on PostgrestException catch (error) {
      // Function missing (e.g. migration not applied).
      if (error.code == '42883') {
        return _fallbackInbox();
      }
      // Ambiguous column reference inside the RPC (often caused by RETURNS TABLE
      // output params shadowing unqualified column names). Fall back to direct
      // queries until the migration is applied.
      if (error.code == '42702' ||
          error.message.toLowerCase().contains('column reference') &&
              error.message.toLowerCase().contains('is ambiguous')) {
        return _fallbackInbox();
      }
      // If the RPC is mis-deployed with an unexpected return type, avoid
      // surfacing a fatal error to the UI; fall back to a direct table query.
      if (error.message.toLowerCase().contains(
        'structure of query does not match function result type',
      )) {
        return _fallbackInbox();
      }
      return Err(svc.mapPostgrestError(error));
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on stored procedure RLS visibility (typically `friendships_select_parties`).
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> outbox() async {
    try {
      final rows = await _db.rpc('rpc_friend_requests_outbox');
      if (rows is List) {
        final payload = rows
            .map((dynamic row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        return Ok(payload);
      }
      return Err(const ServerFailure(message: 'Unexpected outbox payload'));
    } on PostgrestException catch (error) {
      // Function missing (e.g. migration not applied).
      if (error.code == '42883') {
        return _fallbackOutbox();
      }
      // Ambiguous column reference inside the RPC (often caused by RETURNS TABLE
      // output params shadowing unqualified column names). Fall back to direct
      // queries until the migration is applied.
      if (error.code == '42702' ||
          error.message.toLowerCase().contains('column reference') &&
              error.message.toLowerCase().contains('is ambiguous')) {
        return _fallbackOutbox();
      }
      // If the RPC is mis-deployed with an unexpected return type, avoid
      // surfacing a fatal error to the UI; fall back to a direct table query.
      if (error.message.toLowerCase().contains(
        'structure of query does not match function result type',
      )) {
        return _fallbackOutbox();
      }
      return Err(svc.mapPostgrestError(error));
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Relies on RLS policy `friend_edges_read`.
  @override
  Future<Result<List<FriendEdge>, Failure>> listFriendEdges() async {
    try {
      final rows = await _db
          .from('friend_edges')
          .select()
          .order('created_at', ascending: false);
      final edges = rows
          .map(
            (dynamic row) =>
                FriendEdge.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
      return Ok(edges);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  // NOTE: blockUser/unblockUser removed — use BlockRepository from block_providers.dart

  /// Get friendship status with a user
  @override
  Future<Result<String, Failure>> getFriendshipStatus(String peerUserId) async {
    try {
      final status = await _db.rpc(
        'rpc_get_friendship_status',
        params: {'p_peer_profile_id': peerUserId},
      );
      return Ok(status as String);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Get friendship status as stream with Supabase realtime
  @override
  Stream<Result<String, Failure>> getFriendshipStatusStream(
    String peerUserId,
  ) async* {
    final currentUserId = svc.authUserId();
    if (currentUserId == null) {
      yield Err(const ServerFailure(message: 'User not authenticated'));
      return;
    }

    final controller = StreamController<Result<String, Failure>>();

    // Emit initial status
    final initialStatus = await getFriendshipStatus(peerUserId);
    controller.add(initialStatus);

    // Create unique channel name
    final channelName = 'friendship_${currentUserId}_$peerUserId';

    // Subscribe to realtime changes
    final subscription = _db
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) async {
            // Refetch status on any change
            final newStatus = await getFriendshipStatus(peerUserId);
            if (!controller.isClosed) {
              controller.add(newStatus);
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
              'Realtime: friendship channel timed out for $channelName',
            );
          }
        });

    // Handle cleanup
    controller.onCancel = () async {
      await _db.removeChannel(subscription);
      await controller.close();
    };

    yield* controller.stream;
  }

  /// Get list of friends
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> getFriends() async {
    try {
      final userId = svc.authUserId();
      if (userId == null) {
        return Err(const AuthFailure(message: 'User not authenticated'));
      }

      // Use the stable Circle view for the friends list.
      // This avoids server-side failures from broken/overloaded rpc_get_friends
      // definitions (e.g. "structure of query does not match function result type").
      // v_circle is scoped to auth.uid() via its definition + RLS.
      final rows = await _db.from('v_circle').select();
      final raw = rows.cast<Map<String, dynamic>>();
      if (raw.isEmpty) return Ok(const []);

      String? asString(dynamic v) {
        if (v == null) return null;
        if (v is String) return v;
        return v.toString();
      }

      // v_circle is expected to include one or both of:
      // - friend_user_id (auth user UUID)
      // - friend_profile_id (profiles.id)
      final friendUserIds = <String>{};
      final friendProfileIds = <String>{};

      for (final row in raw) {
        final friendUserId = asString(
          row['friend_user_id'] ??
              row['friendUserId'] ??
              row['peer_user_id'] ??
              row['user_id'],
        );
        final friendProfileId = asString(
          row['friend_profile_id'] ??
              row['friendProfileId'] ??
              row['profile_id'],
        );
        if (friendUserId != null &&
            friendUserId.trim().isNotEmpty &&
            friendUserId != userId) {
          friendUserIds.add(friendUserId);
        }
        if (friendProfileId != null && friendProfileId.trim().isNotEmpty) {
          friendProfileIds.add(friendProfileId);
        }
      }

      final profilesByUserId = <String, Map<String, dynamic>>{};
      final profilesByProfileId = <String, Map<String, dynamic>>{};

      Future<void> mergeProfiles(List<dynamic> profiles) async {
        for (final p in profiles) {
          final profile = Map<String, dynamic>.from(p as Map);
          final uid = asString(profile['user_id']);
          final pid = asString(profile['id']);
          if (uid != null) profilesByUserId[uid] = profile;
          if (pid != null) profilesByProfileId[pid] = profile;
        }
      }

      // Best-effort enrichment: fetch profile details for friend IDs.
      if (friendUserIds.isNotEmpty) {
        final profiles = await _db
            .from('profiles')
            .select('id, user_id, display_name, username, avatar_url, verified')
            .inFilter('user_id', friendUserIds.toList());
        await mergeProfiles(profiles);
      }

      if (friendProfileIds.isNotEmpty) {
        final profiles = await _db
            .from('profiles')
            .select('id, user_id, display_name, username, avatar_url, verified')
            .inFilter('id', friendProfileIds.toList());
        await mergeProfiles(profiles);
      }

      Map<String, dynamic>? normalizeRow(Map<String, dynamic> row) {
        final friendUserId = asString(
          row['friend_user_id'] ??
              row['friendUserId'] ??
              row['peer_user_id'] ??
              row['user_id'],
        );
        final friendProfileId = asString(
          row['friend_profile_id'] ??
              row['friendProfileId'] ??
              row['profile_id'],
        );

        // Guard: some views may include a row for the current user.
        if (friendUserId != null && friendUserId == userId) return null;

        final profile =
            (friendUserId != null ? profilesByUserId[friendUserId] : null) ??
            (friendProfileId != null
                ? profilesByProfileId[friendProfileId]
                : null);

        // Guard: if the resolved profile maps to the current user, exclude it.
        if (asString(profile?['user_id']) == userId) return null;

        final displayName =
            asString(
              profile?['display_name'] ??
                  profile?['full_name'] ??
                  row['display_name'] ??
                  row['full_name'] ??
                  profile?['username'] ??
                  row['username'],
            ) ??
            'Unknown User';

        return <String, dynamic>{
          ...row,
          // canonical keys used across UI widgets
          'user_id':
              asString(profile?['user_id'] ?? friendUserId) ?? friendUserId,
          'profile_id':
              asString(profile?['id'] ?? friendProfileId) ?? friendProfileId,
          'display_name': displayName,
          'username': asString(profile?['username'] ?? row['username']),
          'avatar_url': asString(profile?['avatar_url'] ?? row['avatar_url']),
          'verified':
              (profile?['verified'] as bool?) ??
              (row['verified'] as bool?) ??
              false,
        };
      }

      return Ok(
        raw
            .map(normalizeRow)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Get friend suggestions based on mutual friends
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> getFriendSuggestions({
    int limit = 20,
  }) async {
    try {
      final rows = await _db.rpc(
        'rpc_get_friend_suggestions',
        params: {'p_limit': limit},
      );
      if (rows is List) {
        final suggestions = rows
            .map((dynamic row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        return Ok(suggestions);
      }
      return Err(
        const ServerFailure(message: 'Unexpected suggestions payload'),
      );
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> listProfiles({
    int limit = 200,
  }) async {
    try {
      final currentUserId = _db.auth.currentUser?.id;

      var query = _db
          .from('profiles')
          .select('user_id, display_name, username, avatar_url, created_at')
          .eq('is_active', true);

      if (currentUserId != null && currentUserId.isNotEmpty) {
        query = query.neq('user_id', currentUserId);
      }

      final List<dynamic> rows = await query
          .order('created_at', ascending: false, nullsFirst: false)
          .limit(limit);

      final profiles = rows
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      return Ok(profiles);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }

  /// Search for users by name or username
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    try {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const Ok([]);

      final currentUserId = _db.auth.currentUser?.id;
      final like = '%$trimmed%';

      var q = _db
          .from('profiles')
          .select('user_id, display_name, username, avatar_url, created_at')
          .eq('is_active', true)
          .or('display_name.ilike.$like,username.ilike.$like');

      if (currentUserId != null && currentUserId.isNotEmpty) {
        q = q.neq('user_id', currentUserId);
      }

      final List<dynamic> rows = await q
          .order('created_at', ascending: false)
          .limit(limit);

      final results = rows
          .map((dynamic row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      return Ok(results);
    } catch (error) {
      return Err(svc.mapPostgrestError(error));
    }
  }
}
