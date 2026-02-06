import 'package:dabbler/core/fp/failure.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/squad.dart';
import 'package:dabbler/data/models/squad_invite.dart';
import 'package:dabbler/data/models/squad_join_request.dart';
import 'package:dabbler/data/models/squad_member.dart';
import 'package:dabbler/data/models/friend_edge.dart';
import 'package:dabbler/data/models/friendship.dart';
import 'package:dabbler/data/repositories/friends_repository.dart';
import 'package:dabbler/data/repositories/friends_repository_impl.dart';
import 'package:dabbler/data/repositories/squads_repository.dart';
import 'package:dabbler/data/repositories/squads_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final squadsRepositoryProvider = Provider<SquadsRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return SquadsRepositoryImpl(svc);
});

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return FriendsRepositoryImpl(svc);
});

final mySquadsProvider = FutureProvider<Result<List<Squad>, Failure>>((ref) {
  final repo = ref.watch(squadsRepositoryProvider);
  return repo.mySquads();
});

final mySquadsStreamProvider = StreamProvider<Result<List<Squad>, Failure>>((
  ref,
) {
  final repo = ref.watch(squadsRepositoryProvider);
  return repo.mySquadsStream();
});

final squadMembersProvider =
    StreamProvider.family<Result<List<SquadMember>, Failure>, String>((
      ref,
      squadId,
    ) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.membersStream(squadId);
    });

final mySquadInvitesProvider =
    FutureProvider<Result<List<SquadInvite>, Failure>>((ref) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.mySquadInvites();
    });

final squadInvitesProvider =
    FutureProvider.family<Result<List<SquadInvite>, Failure>, String>((
      ref,
      squadId,
    ) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.squadInvites(squadId);
    });

final squadJoinRequestsProvider =
    FutureProvider.family<Result<List<SquadJoinRequest>, Failure>, String>((
      ref,
      squadId,
    ) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.squadJoinRequests(squadId);
    });

class CreateSquadParams {
  const CreateSquadParams({
    required this.sport,
    required this.name,
    this.bio,
    this.logoUrl,
    this.listingVisibility = 'public',
    this.joinPolicy = 'request',
    this.maxMembers,
    this.city,
  });

  final String sport;
  final String name;
  final String? bio;
  final String? logoUrl;
  final String listingVisibility;
  final String joinPolicy;
  final int? maxMembers;
  final String? city;
}

final createSquadProvider =
    FutureProvider.family<Result<String, Failure>, CreateSquadParams>((
      ref,
      params,
    ) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.createSquad(
        sport: params.sport,
        name: params.name,
        bio: params.bio,
        logoUrl: params.logoUrl,
        listingVisibility: params.listingVisibility,
        joinPolicy: params.joinPolicy,
        maxMembers: params.maxMembers,
        city: params.city,
      );
    });

final sendFriendRequestProvider =
    FutureProvider.family<Result<void, Failure>, String>((ref, peerUserId) {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.sendFriendRequest(peerUserId);
    });

final acceptFriendRequestProvider =
    FutureProvider.family<Result<void, Failure>, String>((ref, peerUserId) {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.acceptFriendRequest(peerUserId);
    });

final rejectFriendRequestProvider =
    FutureProvider.family<Result<void, Failure>, String>((ref, peerUserId) {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.rejectFriendRequest(peerUserId);
    });

final removeFriendProvider =
    FutureProvider.family<Result<void, Failure>, String>((ref, peerUserId) {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.removeFriend(peerUserId);
    });

final blockUserProvider = FutureProvider.family<Result<void, Failure>, String>((
  ref,
  peerUserId,
) {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.blockUser(peerUserId);
});

final unblockUserProvider =
    FutureProvider.family<Result<void, Failure>, String>((ref, peerUserId) {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.unblockUser(peerUserId);
    });

final friendshipsProvider = FutureProvider<Result<List<Friendship>, Failure>>((
  ref,
) {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.listFriendships();
});

final friendEdgesProvider = FutureProvider<Result<List<FriendEdge>, Failure>>((
  ref,
) {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.listFriendEdges();
});

final inboxProvider =
    FutureProvider<Result<List<Map<String, dynamic>>, Failure>>((ref) {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.inbox();
    });

final outboxProvider =
    FutureProvider<Result<List<Map<String, dynamic>>, Failure>>((ref) {
      final repo = ref.watch(friendsRepositoryProvider);
      return repo.outbox();
    });
