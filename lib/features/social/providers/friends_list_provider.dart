import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/repositories/friends_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_error_mapper.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for friends repository
final friendsRepositoryProvider = Provider<FriendsRepositoryImpl>((ref) {
  final client = Supabase.instance.client;
  final errorMapper = SupabaseErrorMapper();
  final supabaseService = SupabaseService(client, errorMapper);
  return FriendsRepositoryImpl(supabaseService);
});

/// Provider to get list of friends for current user
final friendsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ref.read(friendsRepositoryProvider);
      final result = await repository.getFriends();

      return switch (result) {
        Ok(:final value) => () {
          print('DEBUG: Got ${value.length} friends from RPC');
          print('DEBUG: Friends data: $value');
          return value;
        }(),
        Err(:final error) => () {
          print('DEBUG: Error getting friends: ${error.message}');
          return <Map<String, dynamic>>[];
        }(),
        _ => <Map<String, dynamic>>[],
      };
    });

/// Provider to get list of friends for a specific user
final userFriendsListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) async {
      // For now, we can only get the current user's friends list from the RPC
      // To get another user's friends, we'd need a different RPC or public query
      // For this implementation, we'll return empty for other users
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == currentUserId) {
        final repository = ref.read(friendsRepositoryProvider);
        final result = await repository.getFriends();

        return switch (result) {
          Ok(:final value) => value,
          Err() => [],
          _ => [],
        };
      }

      // For other users, query friendships where they're a party and status is accepted
      try {
        final supabase = Supabase.instance.client;
        final friendships = await supabase
            .from('friendships')
            .select('user_id, peer_user_id')
            .or('user_id.eq.$userId,peer_user_id.eq.$userId')
            .eq('status', 'accepted');

        if (friendships.isEmpty) return [];

        // Get the IDs of their friends
        final friendIds = <String>{};
        for (final friendship in friendships) {
          final userId1 = friendship['user_id'] as String;
          final userId2 = friendship['peer_user_id'] as String;
          friendIds.add(userId1 == userId ? userId2 : userId1);
        }

        if (friendIds.isEmpty) return [];

        // Fetch profiles
        final profiles = await supabase
            .from('profiles')
            .select('user_id, display_name, avatar_url, username, verified')
            .inFilter('user_id', friendIds.toList())
            .eq('is_active', true);

        return profiles.map((p) => Map<String, dynamic>.from(p)).toList();
      } catch (e) {
        return [];
      }
    });
