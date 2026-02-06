import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/squad.dart';
import 'package:dabbler/data/models/squad_invite.dart';
import 'package:dabbler/data/models/squad_join_request.dart';
import 'package:dabbler/data/models/squad_link_token.dart';
import 'package:dabbler/data/models/squad_member.dart';
import '../../data/repositories/squads_repository.dart';
import '../../data/repositories/squads_repository_impl.dart';

typedef SquadCardsArgs = ({String? squadId, int? limit, int? offset});

final squadsRepositoryProvider = Provider.autoDispose<SquadsRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return SquadsRepositoryImpl(svc);
});

// My owned squads
final myOwnedSquadsProvider =
    FutureProvider.autoDispose<Result<List<Squad>, Failure>>((ref) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.listMyOwnedSquads();
    });

// Squad by id
final squadByIdProvider = FutureProvider.autoDispose
    .family<Result<Squad, Failure>, String>((ref, id) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.getSquadById(id);
    });

// Members
final squadMembersProvider = FutureProvider.autoDispose
    .family<Result<List<SquadMember>, Failure>, String>((ref, squadId) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.listMembers(squadId);
    });

final squadMembersStreamProvider = StreamProvider.autoDispose
    .family<Result<List<SquadMember>, Failure>, String>((ref, squadId) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.membersStream(squadId);
    });

// Invites
final mySquadInvitesProvider =
    FutureProvider.autoDispose<Result<List<SquadInvite>, Failure>>((ref) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.listMyInvites();
    });

final squadInvitesProvider = FutureProvider.autoDispose
    .family<Result<List<SquadInvite>, Failure>, String>((ref, squadId) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.listSquadInvites(squadId);
    });

// Join requests
final myJoinRequestsProvider =
    FutureProvider.autoDispose<Result<List<SquadJoinRequest>, Failure>>((ref) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.listMyJoinRequests();
    });

final squadJoinRequestsProvider = FutureProvider.autoDispose
    .family<Result<List<SquadJoinRequest>, Failure>, String>((ref, squadId) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.listJoinRequestsForSquad(squadId);
    });

// Link tokens (read-only)
final activeLinkTokensProvider = FutureProvider.autoDispose
    .family<Result<List<SquadLinkToken>, Failure>, String>((ref, squadId) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.activeLinkTokensForSquad(squadId);
    });

// Views (maps)
final squadCardsProvider = FutureProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>, Failure>, SquadCardsArgs>((
      ref,
      args,
    ) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.squadCards(
        squadId: args.squadId,
        limit: args.limit,
        offset: args.offset,
      );
    });

final squadDetailViewProvider = FutureProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>, Failure>, String>((
      ref,
      squadId,
    ) {
      final repo = ref.watch(squadsRepositoryProvider);
      return repo.squadDetail(squadId);
    });
