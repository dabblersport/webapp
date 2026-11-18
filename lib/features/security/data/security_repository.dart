// KAN-1003 (W2-F6): the KAN-985 security RPCs. The ledger is server-written
// (T-020); every call is an RPC. A refusal keeps the server's SQLSTATE as
// Failure.code: 42501 confirm from the sign-in's own device, 22023 already
// signed out / the current device, P0002 not found.

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Failure securityFailure(Object error) {
  final base = Failure.from(error);
  if (error is PostgrestException) {
    return Failure(
      category: base.category,
      message: error.message,
      cause: error,
      code: error.code ?? error.message,
    );
  }
  return base;
}

abstract class SecurityRepository {
  /// The caller's own sign-ins, newest first.
  Future<Result<List<SecuritySignIn>, Failure>> signIns();

  /// "This was me".
  Future<Result<void, Failure>> confirm(String signInId);

  /// "Not me" / Sign out: signs out that one device only.
  Future<Result<void, Failure>> notMe(String signInId);
}

class SupabaseSecurityRepository implements SecurityRepository {
  SupabaseSecurityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<SecuritySignIn>, Failure>> signIns() =>
      guardWithTimeout(() async {
        final rows = await _client.rpc(
          SupabaseConfig.rpcSecuritySignInsFn,
          params: {'p_limit': 50},
        );
        return [
          for (final r in (rows as List? ?? const []))
            SecuritySignIn.fromJson(Map<String, dynamic>.from(r as Map)),
        ];
      }, mapError: securityFailure);

  @override
  Future<Result<void, Failure>> confirm(String signInId) =>
      guardWithTimeout(() async {
        await _client.rpc(
          SupabaseConfig.rpcSecurityConfirmSignInFn,
          params: {'p_sign_in_id': signInId},
        );
      }, mapError: securityFailure);

  @override
  Future<Result<void, Failure>> notMe(String signInId) =>
      guardWithTimeout(() async {
        await _client.rpc(
          SupabaseConfig.rpcSecurityNotMeFn,
          params: {'p_sign_in_id': signInId},
        );
      }, mapError: securityFailure);
}

final securityRepositoryProvider = Provider<SecurityRepository>(
  (ref) => SupabaseSecurityRepository(ref.watch(supabaseClientProvider)),
);
