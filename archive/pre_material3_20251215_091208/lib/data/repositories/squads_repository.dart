import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';

import '../models/squad.dart';
import '../models/squad_invite.dart';
import '../models/squad_join_request.dart';
import '../models/squad_member.dart';
import '../models/squad_link_token.dart';

/// Repository contract for Squad management.
///
/// RLS expectations:
/// - Creation uses `squads_insert_self`.
/// - Reads go through `squads_read` / `squads_read_public`.
/// - Member mutations rely on `squad_members_owner_captain_write`.
/// - Invite operations use `squad_invites_owner_write` and reads via `squad_invites_read`.
abstract class SquadsRepository {
  Future<Result<String, Failure>> createSquad({
    required String sport,
    required String name,
    String? bio,
    String? logoUrl,
    String listingVisibility = 'public',
    String joinPolicy = 'request',
    int? maxMembers,
    String? city,
  });

  Future<Result<Squad, Failure>> getSquadById(String id);

  Future<Result<List<Squad>, Failure>> listDiscoverableSquads({
    String? sport,
    String? city,
    String? search,
    int limit = 20,
    int offset = 0,
  });

  Stream<Result<List<SquadMember>, Failure>> membersStream(String squadId);

  Future<Result<String, Failure>> inviteToSquad({
    required String squadId,
    required String toProfileId,
    DateTime? expiresAt,
  });

  Future<Result<String, Failure>> respondToInvite({
    required String inviteId,
    required String action,
    required String profileId,
  });

  Future<Result<String, Failure>> requestJoin({
    required String squadId,
    required String profileId,
    String? message,
    String? linkToken,
  });

  Future<Result<String, Failure>> addMember({
    required String squadId,
    required String profileId,
    bool asCaptain = false,
  });

  Future<Result<String, Failure>> removeMember({
    required String squadId,
    required String profileId,
  });

  Future<Result<String, Failure>> setCaptain({
    required String squadId,
    required String profileId,
    required bool isCaptain,
  });

  Future<Result<List<SquadInvite>, Failure>> mySquadInvites();

  Future<Result<List<SquadInvite>, Failure>> squadInvites(String squadId);

  Future<Result<List<SquadJoinRequest>, Failure>> squadJoinRequests(
    String squadId,
  );

  Future<Result<List<Squad>, Failure>> mySquads();

  Stream<Result<List<Squad>, Failure>> mySquadsStream();

  // ----------------------- Compatibility / Extended API -----------------------
  // These methods were referenced by providers expecting a richer interface.
  // Provide adapter/stub implementations in the concrete class.

  Future<Result<List<Squad>, Failure>> listMyOwnedSquads();
  Future<Result<List<SquadMember>, Failure>> listMembers(String squadId);
  Future<Result<List<SquadInvite>, Failure>> listMyInvites();
  Future<Result<List<SquadInvite>, Failure>> listSquadInvites(String squadId);
  Future<Result<List<SquadJoinRequest>, Failure>> listMyJoinRequests();
  Future<Result<List<SquadJoinRequest>, Failure>> listJoinRequestsForSquad(
    String squadId,
  );
  Future<Result<List<SquadLinkToken>, Failure>> activeLinkTokensForSquad(
    String squadId,
  );
  Future<Result<List<Map<String, dynamic>>, Failure>> squadCards({
    String? squadId,
    int? limit,
    int? offset,
  });
  Future<Result<List<Map<String, dynamic>>, Failure>> squadDetail(
    String squadId,
  );
}
