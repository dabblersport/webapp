import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';

import '../../domain/models/meetup_inputs.dart';
import 'meetup_datasource.dart';

class SupabaseMeetupDataSource implements MeetupDataSource {
  SupabaseMeetupDataSource(this._client);
  final SupabaseClient _client;

  static List<Map<String, dynamic>> _rows(dynamic data) =>
      (data as List<dynamic>).cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> fetchMeetupList({
    String? sportId,
    required int limit,
    required int offset,
  }) async {
    var q = _client.from(SupabaseConfig.vMeetupListView).select();
    if (sportId != null) q = q.eq('sport_id', sportId);
    final data = await q
        .eq('is_cancelled', false)
        .order('start_at', ascending: true)
        .range(offset, offset + limit - 1);
    return _rows(data);
  }

  @override
  Future<List<Map<String, dynamic>>> nearby(
    double lat,
    double lng,
    double radius,
  ) async => _rows(
    await _client.rpc(
      SupabaseConfig.getNearbyMeetupsFn,
      params: MeetupRpcParams.nearby(lat, lng, radius),
    ),
  );

  @override
  Future<Map<String, dynamic>> card(String meetupId, String profileType) async {
    final data = await _client.rpc(
      SupabaseConfig.rpcMeetupCardFn,
      params: MeetupRpcParams.card(meetupId, profileType),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> attendees(
    String meetupId, {
    String? status,
    required int limit,
    required int offset,
  }) async => _rows(
    await _client.rpc(
      SupabaseConfig.rpcMeetupAttendeesFn,
      params: MeetupRpcParams.attendees(
        meetupId,
        status: status,
        limit: limit,
        offset: offset,
      ),
    ),
  );

  @override
  Future<Map<String, dynamic>> canRsvp(String meetupId) async {
    final data = await _client.rpc(
      SupabaseConfig.canCurrentUserRsvpMeetupFn,
      params: MeetupRpcParams.canRsvp(meetupId),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<bool> canCreate(String actorProfileId) async {
    final data = await _client.rpc(
      SupabaseConfig.canCreateMeetupFn,
      params: MeetupRpcParams.canCreate(actorProfileId),
    );
    return data == true;
  }

  @override
  Future<List<Map<String, dynamic>>> soloSports() async => _rows(
    await _client
        .from(SupabaseConfig.sportsTable)
        .select('id, sport_key, name_en, name_ar, emoji')
        .eq(SupabaseConfig.sportsCanSoloColumn, true)
        .eq('is_active', true)
        .order('name_en'),
  );

  @override
  Future<List<Map<String, dynamic>>> sportVariants(String sportId) async =>
      _rows(
        await _client
            .from(SupabaseConfig.sportVariantsTable)
            .select(
              'id, sport_id, variant_key, name_en, name_ar, required_players',
            )
            .eq('sport_id', sportId)
            .eq('is_active', true)
            .order('name_en'),
      );

  @override
  Future<String> create(
    CreateMeetupInput input, {
    required String actorType,
  }) async {
    final data = await _client.rpc(
      SupabaseConfig.rpcCreateMeetupFn,
      params: MeetupRpcParams.create(input, actorType: actorType),
    );
    return data.toString();
  }

  @override
  Future<String> rsvp(
    String meetupId,
    String action, {
    String? profileId,
  }) async {
    final data = await _client.rpc(
      SupabaseConfig.rpcMeetupRsvpFn,
      params: MeetupRpcParams.rsvp(meetupId, action, profileId: profileId),
    );
    return data.toString();
  }

  @override
  Future<void> cancel(String meetupId) async {
    await _client.rpc(
      SupabaseConfig.rpcMeetupCancelFn,
      params: MeetupRpcParams.cancel(meetupId),
    );
  }

  @override
  Future<Map<String, dynamic>> update(UpdateMeetupInput input) async {
    final data = await _client.rpc(
      SupabaseConfig.rpcMeetupUpdateFn,
      params: MeetupRpcParams.update(input),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<String> decideRequest(
    String meetupId,
    String userId,
    String decision,
  ) async {
    final data = await _client.rpc(
      SupabaseConfig.rpcMeetupDecideRequestFn,
      params: MeetupRpcParams.decideRequest(meetupId, userId, decision),
    );
    return data.toString();
  }

  @override
  Future<String> removeAttendee(String meetupId, String userId) async {
    final data = await _client.rpc(
      SupabaseConfig.rpcMeetupRemoveAttendeeFn,
      params: MeetupRpcParams.removeAttendee(meetupId, userId),
    );
    return data.toString();
  }
}
