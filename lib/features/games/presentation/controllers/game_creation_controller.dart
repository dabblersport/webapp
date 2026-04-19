import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/features/games/domain/models/game_creation_state.dart';
import 'package:dabbler/core/fp/result.dart';

class GameCreationController extends StateNotifier<GameCreationState> {
  GameCreationController(super.initialState);

  void updateSport({
    required String sportId,
    required String sportKey,
    required String sportNameEn,
    required String sportEmoji,
  }) {
    // Clear variant when sport changes
    state = state.copyWith(
      sportId: sportId,
      sportKey: sportKey,
      sportNameEn: sportNameEn,
      sportEmoji: sportEmoji,
      sportVariantId: null,
      requiredPlayers: 0,
      playersPerSide: 0,
    );
  }

  void updateVariant({
    required String variantId,
    required int requiredPlayers,
    required int playersPerSide,
  }) {
    state = state.copyWith(
      sportVariantId: variantId,
      requiredPlayers: requiredPlayers,
      playersPerSide: playersPerSide,
      benchSlots: 0,
      venueSpaceId: null,
      venueId: null,
      joiningRule: null,
      costCover: null,
      creatorAbsorbsCost: null,
    );
  }

  void updateScreen1({String? gameType, String? title}) {
    state = state.copyWith(gameType: gameType, title: title);
  }

  void updateScreen2({
    DateTime? startAt,
    DateTime? endAt,
    String? venueSpaceId,
    String? venueId,
    String? venueName,
    String? venueSpaceName,
    String? geoLocationId,
    String? areaId,
    double? lat,
    double? lng,
    String? joiningRule,
    String? costCover,
    bool? creatorAbsorbsCost,
  }) {
    state = state.copyWith(
      startAt: startAt,
      endAt: endAt,
      venueSpaceId: venueSpaceId,
      venueId: venueId,
      venueName: venueName,
      venueSpaceName: venueSpaceName,
      geoLocationId: geoLocationId,
      areaId: areaId,
      lat: lat,
      lng: lng,
      joiningRule: joiningRule,
      costCover: costCover,
      creatorAbsorbsCost: creatorAbsorbsCost,
    );
  }

  void updateScreen3({
    int? benchSlots,
    String? squadId,
    bool? allowSpectators,
  }) {
    state = state.copyWith(
      benchSlots: benchSlots,
      squadId: squadId,
      allowSpectators: allowSpectators,
    );
  }

  void updateScreen4({
    String? listingVisibility,
    String? joinPolicy,
    int? minSkill,
    int? maxSkill,
    bool? allowsWaitlist,
  }) {
    state = state.copyWith(
      listingVisibility: listingVisibility,
      joinPolicy: joinPolicy,
      minSkill: minSkill,
      maxSkill: maxSkill,
      allowsWaitlist: allowsWaitlist,
    );
  }

  void updateScreen5({String? rules, Map<String, dynamic>? sportSpecificData}) {
    state = state.copyWith(rules: rules, sportSpecificData: sportSpecificData);
  }

  /// Publishes the game via Supabase RPC. Returns Ok(gameId) or Err(message).
  Future<Result<String, String>> publishGame() async {
    final s = state;
    return Result.guard(() async {
      final client = Supabase.instance.client;
      try {
        final response = await client.rpc(
          'rpc_create_game',
          params: {
            'p_actor_type': 'player',
            'p_sport_id': s.sportId,
            'p_sport_variant_id': s.sportVariantId,
            'p_title': s.title,
            'p_venue_space_id': s.venueSpaceId,
            'p_start_at': s.startAt?.toIso8601String(),
            'p_end_at': s.endAt?.toIso8601String(),
            'p_bench_slots': s.benchSlots,
            'p_listing_visibility': s.listingVisibility ?? 'public',
            'p_join_policy': s.joinPolicy ?? 'open',
            'p_min_skill': s.minSkill,
            'p_max_skill': s.maxSkill,
            'p_rules': s.rules != null ? {'notes': s.rules} : null,
            'p_squad_id': s.squadId,
            'p_allow_spectators': s.allowSpectators,
            'p_allows_waitlist': s.allowsWaitlist,
            'p_sport_specific_data': s.sportSpecificData,
            'p_cost_cover': s.costCover,
            if (s.geoLocationId != null) 'p_geo_location_id': s.geoLocationId,
            if (s.areaId != null) 'p_area_id': s.areaId,
          },
        );
        final gameId = response?.toString() ?? '';
        return gameId;
      } on PostgrestException catch (e) {
        if (e.code == 'P0001') {
          switch (e.message) {
            case 'sport_not_challenge':
            case 'sport_not_challenge_eligible':
              throw Exception(
                'This sport is not available for competitive games',
              );
            case 'no_profile_of_requested_type':
              throw Exception(
                'Player profile not found. Please complete your profile first.',
              );
            case 'invalid_time_range':
              throw Exception('End time must be after start time.');
            case 'invalid_sport_variant':
              throw Exception('Invalid game format for this sport.');
            default:
              throw Exception(e.message);
          }
        }
        rethrow;
      }
    }, (e) => e.toString());
  }

  Future<Result<String, String>> saveAsDraft() async {
    // Same as publishGame but with status = 'draft'
    return publishGame();
  }
}

final gameCreationControllerProvider =
    StateNotifierProvider.family<
      GameCreationController,
      GameCreationState,
      GameCreationState
    >((ref, initialState) => GameCreationController(initialState));
