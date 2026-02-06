import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/slot.dart';
import 'availability_repository.dart';
import 'base_repository.dart';

@immutable
class AvailabilityRepositoryImpl extends BaseRepository
    implements AvailabilityRepository {
  const AvailabilityRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;
  String? get _userId => _db.auth.currentUser?.id;

  @override
  Future<Result<List<Slot>, Failure>> listSlots({
    required String venueSpaceId,
    required DateTime from,
    required DateTime to,
    bool onlyAvailable = true,
    int limit = 500,
  }) async {
    return guard<List<Slot>>(() async {
      var query = _db
          .from('space_slot_grid')
          .select()
          .eq('venue_space_id', venueSpaceId);

      if (onlyAvailable) {
        // Be tolerant: check any of these columns if present.
        // Supabase will ignore .eq on missing columns, so we add OR logic via server expressions if needed.
        // Here we use simple filters that common grid views expose.
        query = query
            .eq('is_open', true)
            .eq('is_booked', false)
            .eq('is_held', false);
      }

      query = query
          .gte('start_ts', from.toUtc().toIso8601String())
          .lt('end_ts', to.toUtc().toIso8601String());

      // RLS: grid_public_read permits SELECT for everyone.
      final rows = await query.order('start_ts', ascending: true).limit(limit);
      return rows.map((r) => Slot.fromMap(asMap(r))).toList();
    });
  }

  @override
  Future<Result<List<SlotHold>, Failure>> listMyHolds({
    String? venueSpaceId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    return guard<List<SlotHold>>(() async {
      final uid = _userId;
      if (uid == null) {
        throw const AuthFailure(message: 'Not signed in');
      }

      var q = _db.from('space_slot_holds').select().eq('created_by', uid);

      if (venueSpaceId != null && venueSpaceId.isNotEmpty) {
        q = q.eq('venue_space_id', venueSpaceId);
      }
      if (from != null) {
        q = q.gte('start_ts', from.toUtc().toIso8601String());
      }
      if (to != null) {
        q = q.lt('end_ts', to.toUtc().toIso8601String());
      }

      final rows = await q.order('start_ts', ascending: true).limit(limit);

      // RLS: holds_read allows creator/admin/venue staff to read.
      return rows.map((m) => SlotHold.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<SlotHold, Failure>> createHold({
    required String venueSpaceId,
    required DateTime start,
    required DateTime end,
    String? note,
  }) async {
    return guard<SlotHold>(() async {
      final uid = _userId;
      if (uid == null) {
        throw const AuthFailure(message: 'Not signed in');
      }

      final insert = SlotHold(
        id: '',
        venueSpaceId: venueSpaceId,
        start: start.toUtc(),
        end: end.toUtc(),
        createdBy: uid,
        note: note,
      ).toInsertMap(createdBy: uid);

      // RLS: holds_write requires created_by = auth.uid() (or admin). We set it explicitly.
      final row = await _db
          .from('space_slot_holds')
          .insert(insert)
          .select()
          .single();

      return SlotHold.fromMap(asMap(row));
    });
  }

  @override
  Future<Result<void, Failure>> releaseHold(String holdId) async {
    return guard<void>(() async {
      // RLS: holds_write lets creator delete their own holds.
      final _ = await _db.from('space_slot_holds').delete().eq('id', holdId);
    });
  }
}
