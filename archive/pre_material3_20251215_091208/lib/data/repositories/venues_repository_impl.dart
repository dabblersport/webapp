import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/venue_space.dart';
import 'package:dabbler/data/repositories/base_repository.dart';
import 'package:dabbler/data/repositories/venues_repository.dart';

class VenuesRepositoryImpl extends BaseRepository implements VenuesRepository {
  VenuesRepositoryImpl(super.svc);

  static const String venuesTable = 'venues';
  static const String spacesTable = 'venue_spaces';

  @override
  Future<Result<List<Venue>, Failure>> listVenues({
    bool activeOnly = true,
    String? city,
    String? district,
    String? q,
  }) async {
    try {
      // Select with column aliases to match Venue.fromJson fields
      var query = svc
          .from(venuesTable)
          .select(
            'id,name:name_en,description:description_en,address:address_line1,city,district,lat,lng,is_active:is_active,created_at:created_at,updated_at:updated_at',
          );

      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      if (city != null) {
        query = query.eq('city', city);
      }
      if (district != null) {
        query = query.eq('district', district);
      }
      if (q != null && q.isNotEmpty) {
        // Filter on actual DB column
        query = query.ilike('name_en', '%$q%');
      }

      final response = await query.order('name_en');
      final data = List<dynamic>.from(response as List);
      final venues = data
          .map((item) => Venue.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
      return Ok(venues);
    } catch (error, stackTrace) {
      return Err(svc.mapPostgrestError(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Result<Venue, Failure>> getVenueById(String venueId) async {
    try {
      final response = await svc
          .from(venuesTable)
          .select(
            'id,name:name_en,description:description_en,address:address_line1,city,district,lat,lng,is_active:is_active,created_at:created_at,updated_at:updated_at',
          )
          .eq('id', venueId)
          .maybeSingle();
      if (response == null) {
        return Err(NotFoundFailure(message: 'Venue $venueId not found'));
      }
      return Ok(Venue.fromJson(response));
    } catch (error, stackTrace) {
      return Err(svc.mapPostgrestError(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Result<List<VenueSpace>, Failure>> listSpacesByVenue(
    String venueId, {
    bool activeOnly = true,
  }) async {
    try {
      var query = svc.from(spacesTable).select().eq('venue_id', venueId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('name');
      final data = List<dynamic>.from(response as List);
      final spaces = data
          .map((e) => VenueSpace.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
      return Ok(spaces);
    } catch (error, stackTrace) {
      return Err(svc.mapPostgrestError(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Result<VenueSpace, Failure>> getSpaceById(String spaceId) async {
    try {
      final response = await svc
          .from(spacesTable)
          .select()
          .eq('id', spaceId)
          .maybeSingle();
      if (response == null) {
        return Err(NotFoundFailure(message: 'Venue space $spaceId not found'));
      }
      return Ok(VenueSpace.fromMap(response));
    } catch (error, stackTrace) {
      return Err(svc.mapPostgrestError(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Result<List<Venue>, Failure>> nearbyVenues({
    required double lat,
    required double lng,
    double withinKm = 10,
    bool activeOnly = true,
  }) async {
    try {
      // Bounding-box approximation; a precise circular search can use an RPC with
      // haversine distance if needed in the future.
      final latInRadians = lat * math.pi / 180;
      final dLat = withinKm / 110.574;
      final cosLat = math.cos(latInRadians).abs();
      final lngDenominator = (111.320 * (cosLat < 1e-6 ? 1e-6 : cosLat));
      final dLng = withinKm / lngDenominator;

      var query =
          svc
              .from(venuesTable)
              .select(
                'id,name:name_en,description:description_en,address:address_line1,city,district,lat,lng,is_active:is_active,created_at:created_at,updated_at:updated_at',
              )
            ..gte('lat', lat - dLat)
            ..lte('lat', lat + dLat)
            ..gte('lng', lng - dLng)
            ..lte('lng', lng + dLng);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('name_en');
      final data = List<dynamic>.from(response as List);
      final venues = data
          .map((item) => Venue.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
      return Ok(venues);
    } catch (error, stackTrace) {
      return Err(svc.mapPostgrestError(error, stackTrace: stackTrace));
    }
  }

  @override
  Stream<Result<List<VenueSpace>, Failure>> watchSpacesByVenue(String venueId) {
    final controller =
        StreamController<Result<List<VenueSpace>, Failure>>.broadcast();
    RealtimeChannel? channel;

    Future<void> emitCurrent() async {
      final result = await listSpacesByVenue(venueId);
      if (!controller.isClosed) {
        controller.add(result);
      }
    }

    controller.onListen = () {
      channel = svc.client.channel('public:$spacesTable')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: spacesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'venue_id',
            value: venueId,
          ),
          callback: (payload) {
            unawaited(emitCurrent());
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: spacesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'venue_id',
            value: venueId,
          ),
          callback: (payload) {
            unawaited(emitCurrent());
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: spacesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'venue_id',
            value: venueId,
          ),
          callback: (payload) {
            unawaited(emitCurrent());
          },
        )
        ..subscribe();

      unawaited(emitCurrent());
    };

    controller.onCancel = () async {
      final currentChannel = channel;
      channel = null;
      if (currentChannel != null) {
        await currentChannel.unsubscribe();
        await svc.client.removeChannel(currentChannel);
      }
    };

    return controller.stream;
  }
}
