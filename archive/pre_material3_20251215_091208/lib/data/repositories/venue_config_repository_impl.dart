import 'package:meta/meta.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/venue_space.dart';
import 'base_repository.dart';
import 'venue_config_repository.dart';

@immutable
class VenueConfigRepositoryImpl extends BaseRepository
    implements VenueConfigRepository {
  const VenueConfigRepositoryImpl(super.svc);

  @override
  Future<Result<List<VenueSpace>, Failure>> listActiveSpaces({
    String? venueId,
    int limit = 100,
  }) async {
    return guard<List<VenueSpace>>(() async {
      var query = svc.from('venue_spaces').select().eq('is_active', true);

      if (venueId != null && venueId.isNotEmpty) {
        query = query.eq('venue_id', venueId);
      }

      // RLS: public read when is_active=true (policy: spaces_public_read / vspaces_read).
      final rows = await query.order('name', ascending: true).limit(limit);
      return rows.map((r) => VenueSpace.fromMap(asMap(r))).toList();
    });
  }

  @override
  Future<Result<List<OpeningHour>, Failure>> getOpeningHours(
    String venueSpaceId,
  ) async {
    return guard<List<OpeningHour>>(() async {
      // RLS: public read (hours_public_read).
      final rows = await svc
          .from('venue_opening_hours')
          .select()
          .eq('venue_space_id', venueSpaceId)
          .order('day_of_week', ascending: true);

      return rows.map((r) => OpeningHour.fromMap(asMap(r))).toList();
    });
  }

  @override
  Future<Result<List<SpacePrice>, Failure>> getActivePrices(
    String venueSpaceId,
  ) async {
    return guard<List<SpacePrice>>(() async {
      // RLS: public read but only is_active=true (prices_public_read).
      final rows = await svc
          .from('venue_price_rules')
          .select()
          .eq('venue_space_id', venueSpaceId)
          .eq('is_active', true)
          .order('amount', ascending: true);

      return rows.map((r) => SpacePrice.fromMap(asMap(r))).toList();
    });
  }

  @override
  Future<Result<VenueSpace, Failure>> upsertSpace(VenueSpace space) async {
    return guard<VenueSpace>(() async {
      // RLS: write allowed when user is venue admin/manager (spaces_manage / vspaces_write).
      final row = await svc
          .from('venue_spaces')
          .upsert(space.toInsertMap(), onConflict: 'id')
          .select()
          .single();

      return VenueSpace.fromMap(row);
    });
  }

  @override
  Future<Result<OpeningHour, Failure>> upsertOpeningHour(
    OpeningHour hour,
  ) async {
    return guard<OpeningHour>(() async {
      // RLS: write allowed when user is venue admin/manager (hours_manage).
      final row = await svc
          .from('venue_opening_hours')
          .upsert(hour.toInsertMap(), onConflict: 'id')
          .select()
          .single();

      return OpeningHour.fromMap(row);
    });
  }

  @override
  Future<Result<SpacePrice, Failure>> upsertSpacePrice(SpacePrice price) async {
    return guard<SpacePrice>(() async {
      // RLS: write allowed when user is venue admin/manager (vprices_write / prices_manage).
      final row = await svc
          .from('venue_price_rules')
          .upsert(price.toInsertMap(), onConflict: 'id')
          .select()
          .single();

      return SpacePrice.fromMap(row);
    });
  }

  @override
  Future<Result<VenueSpace, Failure>> setSpaceActive({
    required String spaceId,
    required bool isActive,
  }) async {
    return guard<VenueSpace>(() async {
      // RLS: write allowed when user is venue admin/manager.
      final row = await svc
          .from('venue_spaces')
          .update({'is_active': isActive})
          .eq('id', spaceId)
          .select()
          .single();

      return VenueSpace.fromMap(row);
    });
  }
}
