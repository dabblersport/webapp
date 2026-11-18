// KAN-1002 (W2-F5): the lifecycle read and the organiser's calls (KAN-995).
// A refusal keeps the server's message as Failure.code (not_organiser,
// not_started_yet, already_closed, cancelled, event_not_found, ...).

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart'
    show attendanceFailure;
import 'package:dabbler/features/lifecycle/domain/lifecycle_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class LifecycleRepository {
  /// rpc_event_lifecycle_read: the state as the server sees it.
  Future<Result<LifecycleView, Failure>> read(String eventId);

  /// rpc_event_start: the optional Start. Repeating it is idempotent.
  Future<Result<void, Failure>> start(String eventId);

  /// rpc_event_confirm_end with [played] true ('played') or false
  /// ('did_not_happen').
  Future<Result<void, Failure>> confirmEnd(
    String eventId, {
    required bool played,
  });
}

class SupabaseLifecycleRepository implements LifecycleRepository {
  SupabaseLifecycleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<LifecycleView, Failure>> read(String eventId) =>
      guardWithTimeout(() async {
        final data = await _client.rpc(
          SupabaseConfig.rpcEventLifecycleReadFn,
          params: {'p_event_id': eventId},
        );
        return LifecycleView.fromJson(Map<String, dynamic>.from(data as Map));
      }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> start(String eventId) =>
      guardWithTimeout(() async {
        await _client.rpc(
          SupabaseConfig.rpcEventStartFn,
          params: {'p_event_id': eventId},
        );
      }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> confirmEnd(
    String eventId, {
    required bool played,
  }) => guardWithTimeout(() async {
    await _client.rpc(
      SupabaseConfig.rpcEventConfirmEndFn,
      params: {
        'p_event_id': eventId,
        'p_outcome': played ? 'played' : 'did_not_happen',
      },
    );
  }, mapError: attendanceFailure);
}

final lifecycleRepositoryProvider = Provider<LifecycleRepository>(
  (ref) => SupabaseLifecycleRepository(ref.watch(supabaseClientProvider)),
);
