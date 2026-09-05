import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../../core/data/supabase_remote_data_source.dart';

abstract class BaseRepository {
  final SupabaseService svc;
  const BaseRepository(this.svc);

  bool _isJwtExpired(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final details = (e.details ?? '').toString().toLowerCase();
    return msg.contains('jwt expired') ||
        msg.contains('invalid jwt') ||
        e.code == 'PGRST303' ||
        details.contains('unauthorized');
  }

  /// Wrap an async operation and map common Supabase exceptions.
  Future<Result<T, Failure>> guard<T>(Future<T> Function() body) async {
    try {
      final value = await body();
      return Ok(value);
    } on PostgrestException catch (e) {
      // If the access token expired, try refreshing once and retry the call.
      // This avoids the app getting stuck in a "JWT expired" state until reinstall.
      if (_isJwtExpired(e)) {
        try {
          await svc.client.auth.refreshSession();
          final value = await body();
          return Ok(value);
        } catch (_) {
          // Fall through to mapped error below.
        }
      }
      return Err(svc.mapPostgrest(e));
    } catch (e, st) {
      return Err(svc.mapGeneric(e, st));
    }
  }
}
