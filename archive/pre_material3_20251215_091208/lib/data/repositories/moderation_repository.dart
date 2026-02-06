import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

abstract class ModerationRepository {
  /// Quick admin check via RPC. Cache at call-site if you like; repo stays stateless.
  Future<Result<bool, Failure>> isAdmin();

  // ----- Flags (read-only, admin) -----
  Future<Result<List<Map<String, dynamic>>, Failure>> listFlags({
    int limit = 50,
    int offset = 0,
    Map<String, dynamic>? where, // optional simple filters
  });

  // ----- Tickets (admin) -----
  Future<Result<List<Map<String, dynamic>>, Failure>> listTickets({
    int limit = 50,
    int offset = 0,
    Map<String, dynamic>? where,
  });

  /// Insert a ticket row. Caller provides the map with correct columns.
  Future<Result<Map<String, dynamic>, Failure>> createTicket(
    Map<String, dynamic> values,
  );

  /// Patch a ticket by id (string or uuid in text form).
  Future<Result<Map<String, dynamic>, Failure>> updateTicket(
    String id,
    Map<String, dynamic> patch,
  );

  /// Optional convenience to close/resolve tickets if the schema has a status field.
  Future<Result<int, Failure>> setTicketStatus(String id, String status);

  // ----- Actions (admin) -----
  Future<Result<List<Map<String, dynamic>>, Failure>> listActions({
    int limit = 50,
    int offset = 0,
    Map<String, dynamic>? where,
  });

  Future<Result<Map<String, dynamic>, Failure>> recordAction(
    Map<String, dynamic> values,
  );

  // ----- Ban terms (admin) -----
  Future<Result<List<Map<String, dynamic>>, Failure>> listBanTerms({
    int limit = 100,
    int offset = 0,
    Map<String, dynamic>? where,
  });

  /// Upsert by unique constraint (caller supplies keys present in DB).
  Future<Result<Map<String, dynamic>, Failure>> upsertBanTerm(
    Map<String, dynamic> values,
  );

  Future<Result<int, Failure>> deleteBanTerm(String id);
}
