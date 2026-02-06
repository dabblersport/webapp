import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';

abstract class BaseRepository {
  final SupabaseService svc;
  const BaseRepository(this.svc);

  /// Wrap an async operation and map common Supabase exceptions.
  Future<Result<T, Failure>> guard<T>(Future<T> Function() body) async {
    try {
      final value = await body();
      return Ok(value);
    } on PostgrestException catch (e) {
      return Err(svc.mapPostgrest(e));
    } catch (e, st) {
      return Err(svc.mapGeneric(e, st));
    }
  }
}
