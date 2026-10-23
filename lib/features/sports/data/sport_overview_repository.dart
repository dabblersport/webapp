import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';

/// KAN-622: proposed ordering and window, held as named constants so a product
/// ruling is a one-line change (Games/Meetups soonest first within the next
/// seven days; Venues top-rated first; Spaces lowest price first; Posts
/// newest first).
const int kSportOverviewWindowDays = 7;

/// How many rows each Overview preview shows before "See all".
const int kSportOverviewPreviewCount = 3;

/// The longest a Games / Meetups / Venues / Spaces list fetches.
const int kSportOverviewListLimit = 50;

/// One page of the sport-tagged Posts feed.
const int kSportOverviewPostsPage = 20;

/// Where the Sport Overview page reads from. Every call returns a [Result]:
/// nothing here throws into the UI.
abstract class SportOverviewRepository {
  /// The sport and its formats; a [FailureCode.notFound] failure for an id
  /// that is not a sport.
  Future<Result<SportInfo, Failure>> sport(String sportId);

  /// `rpc_sport_overview` for [cityCode] (null: every city).
  Future<Result<SportOverviewCounts, Failure>> overview(
    String sportId,
    String? cityCode,
  );

  /// The `ref_cities.code` whose name matches [cityName] (the name the map
  /// service returned), or null when no city of the data matches.
  Future<Result<String?, Failure>> cityCode(String cityName);

  Future<Result<List<NearbyGameModel>, Failure>> games(
    String sportId,
    String? cityCode,
  );

  Future<Result<List<MeetupListItem>, Failure>> meetups(
    String sportId,
    String? cityCode,
  );

  Future<Result<List<SportVenue>, Failure>> venues(
    String sportId,
    String? cityCode,
  );

  Future<Result<List<SportSpace>, Failure>> spaces(
    String sportId,
    String? cityCode,
  );

  /// The ids of the sport's public posts, newest first. The Following filter
  /// is never applied here.
  Future<Result<List<String>, Failure>> postIds(
    String sportId, {
    int offset = 0,
    int limit = kSportOverviewPostsPage,
  });

  /// Whether the active persona already has a sport profile for the sport.
  Future<Result<bool, Failure>> hasSportProfile(
    String profileId,
    SportInfo sport,
  );

  /// `rpc_create_sport_profile`: adds the sport as Practicing.
  Future<Result<void, Failure>> createSportProfile(
    String profileId,
    SportInfo sport,
  );
}

class SupabaseSportOverviewRepository implements SportOverviewRepository {
  const SupabaseSportOverviewRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<Result<SportInfo, Failure>> sport(String sportId) =>
      guardWithTimeout(() async {
        final Map<String, dynamic>? row = await _db
            .from(SupabaseConfig.sportsTable)
            .select('id, name_en, name_ar, sport_key')
            .eq('id', sportId)
            .maybeSingle();
        if (row == null) {
          throw const Failure(
            category: FailureCode.notFound,
            message: 'Sport not found',
          );
        }
        final List<dynamic> variants = await _db
            .from(SupabaseConfig.sportVariantsTable)
            .select('name_en, name_ar')
            .eq('sport_id', sportId)
            .order('name_en', ascending: true);
        final List<Map<String, dynamic>> rows = [
          for (final Object? v in variants)
            if (v is Map) Map<String, dynamic>.from(v),
        ];
        return SportInfo(
          id: row['id'] as String,
          nameEn: (row['name_en'] as String?) ?? '',
          nameAr: row['name_ar'] as String?,
          sportKey: row['sport_key'] as String?,
          formatsEn: [for (final r in rows) (r['name_en'] as String?) ?? ''],
          formatsAr: [for (final r in rows) (r['name_ar'] as String?) ?? ''],
        );
      });

  @override
  Future<Result<SportOverviewCounts, Failure>> overview(
    String sportId,
    String? cityCode,
  ) => guardWithTimeout(() async {
    final Object? response = await _db.rpc(
      SupabaseConfig.rpcSportOverviewFn,
      params: <String, dynamic>{
        'p_sport_id': sportId,
        'p_city_code': ?cityCode,
      },
    );
    final Object? first = response is List && response.isNotEmpty
        ? response.first
        : response;
    if (first is! Map) {
      throw const Failure(message: 'Unexpected sport overview response');
    }
    return SportOverviewCounts.fromJson(Map<String, dynamic>.from(first));
  });

  @override
  Future<Result<String?, Failure>> cityCode(String cityName) =>
      guardWithTimeout(() async {
        final List<dynamic> rows = await _db
            .from(SupabaseConfig.refCitiesTable)
            .select('code, name_en, name_ar');
        final String wanted = _fold(cityName);
        for (final Object? r in rows) {
          if (r is! Map) continue;
          if (_fold(r['name_en'] as String?) == wanted ||
              _fold(r['name_ar'] as String?) == wanted) {
            return r['code'] as String?;
          }
        }
        return null;
      });

  static String _fold(String? s) => (s ?? '').trim().toLowerCase();

  /// The ids of the areas of [cityCode]; null when no city scopes the query.
  Future<List<String>?> _areaIds(String? cityCode) async {
    if (cityCode == null) return null;
    final List<dynamic> rows = await _db
        .from(SupabaseConfig.areasTable)
        .select('id')
        .eq('city_code', cityCode);
    return [for (final Object? r in rows) (r as Map)['id'] as String];
  }

  @override
  Future<Result<List<NearbyGameModel>, Failure>> games(
    String sportId,
    String? cityCode,
  ) => guardWithTimeout(() async {
    final List<String>? areas = await _areaIds(cityCode);
    if (areas != null && areas.isEmpty) return const <NearbyGameModel>[];
    final DateTime now = DateTime.now().toUtc();
    var query = _db
        .from(SupabaseConfig.vGameCardTable)
        .select(
          'id, title, sport_name_en, start_at, end_at, is_cancelled, '
          'venue_name, area_name, capacity, roster_count, sport_id, '
          'is_creator, is_joined, min_skill, max_skill, variant_name_en, '
          'variant_name_ar, host_verified, favorite_count, favourited_by_me, '
          'price_aed',
        )
        .eq('sport_id', sportId)
        .eq('is_cancelled', false)
        .eq('listing_visibility', 'public')
        .gte('start_at', now.toIso8601String())
        .lt(
          'start_at',
          now
              .add(const Duration(days: kSportOverviewWindowDays))
              .toIso8601String(),
        );
    if (areas != null) query = query.inFilter('area_id', areas);
    final List<dynamic> rows = await query
        .order('start_at', ascending: true)
        .limit(kSportOverviewListLimit);
    return [
      for (final Object? r in rows)
        _game(Map<String, dynamic>.from(r as Map), DateTime.now()),
    ];
  });

  /// A `v_game_card` row as the listing model. Capacity and price are the
  /// row's own; a missing capacity leaves the spots unknown (no progress bar).
  static NearbyGameModel _game(Map<String, dynamic> row, DateTime now) {
    final DateTime? startAt = DateTime.tryParse(
      row['start_at'] as String? ?? '',
    )?.toLocal();
    final DateTime? endAt = DateTime.tryParse(
      row['end_at'] as String? ?? '',
    )?.toLocal();
    final int capacity = (row['capacity'] as num?)?.toInt() ?? 0;
    final int roster = (row['roster_count'] as num?)?.toInt() ?? 0;
    return NearbyGameModel(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      sportName: row['sport_name_en'] as String?,
      scheduledAt: startAt,
      status: startAt != null && now.isBefore(startAt) ? 'upcoming' : 'live',
      venueName: (row['venue_name'] ?? row['area_name']) as String?,
      distanceMeters: 0,
      playerCount: roster,
      spotsRemaining: capacity > 0 ? capacity - roster : null,
      isPublic: true,
      isCreated: row['is_creator'] as bool? ?? false,
      isJoined: row['is_joined'] as bool? ?? false,
      minSkill: (row['min_skill'] as num?)?.toInt(),
      maxSkill: (row['max_skill'] as num?)?.toInt(),
      endAt: endAt,
      variantNameEn: row['variant_name_en'] as String?,
      variantNameAr: row['variant_name_ar'] as String?,
      hostVerified: row['host_verified'] as bool? ?? false,
      favoriteCount: (row['favorite_count'] as num?)?.toInt() ?? 0,
      favouritedByMe: row['favourited_by_me'] as bool? ?? false,
      priceAed: (row['price_aed'] as num?)?.toDouble(),
    );
  }

  @override
  Future<Result<List<MeetupListItem>, Failure>> meetups(
    String sportId,
    String? cityCode,
  ) => guardWithTimeout(() async {
    final List<String>? areas = await _areaIds(cityCode);
    if (areas != null && areas.isEmpty) return const <MeetupListItem>[];
    final DateTime now = DateTime.now().toUtc();
    var query = _db
        .from(SupabaseConfig.vMeetupListView)
        .select()
        .eq('sport_id', sportId)
        .eq('is_cancelled', false)
        .eq('listing_visibility', 'public')
        .gte('start_at', now.toIso8601String())
        .lt(
          'start_at',
          now
              .add(const Duration(days: kSportOverviewWindowDays))
              .toIso8601String(),
        );
    if (areas != null) query = query.inFilter('area_id', areas);
    final List<dynamic> rows = await query
        .order('start_at', ascending: true)
        .limit(kSportOverviewListLimit);
    return [
      for (final Object? r in rows)
        MeetupListItem.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  });

  @override
  Future<Result<List<SportVenue>, Failure>> venues(
    String sportId,
    String? cityCode,
  ) => guardWithTimeout(() async {
    final Map<String, dynamic>? sport = await _db
        .from(SupabaseConfig.sportsTable)
        .select('sport_key')
        .eq('id', sportId)
        .maybeSingle();
    final String? key = sport?['sport_key'] as String?;
    final List<dynamic> spaceRows = await _db
        .from(SupabaseConfig.venueSpacesTable)
        .select('venue_id')
        .eq('sport_id', sportId)
        .eq('is_active', true);
    final List<String> ids = {
      for (final Object? r in spaceRows) (r as Map)['venue_id'] as String,
    }.toList();
    if (ids.isEmpty && key == null) return const <SportVenue>[];

    final String offered = [
      if (ids.isNotEmpty) 'id.in.(${ids.join(',')})',
      if (key != null) 'sports.cs.{$key}',
    ].join(',');
    var query = _db
        .from(SupabaseConfig.venuesTable)
        .select(
          'id, name_en, name_ar, app_rating, rating_count, area, '
          '${cityCode == null ? 'areas(city_code, name)' : 'areas!inner(city_code, name)'}',
        )
        .eq('is_active', true)
        .or(offered);
    if (cityCode != null) query = query.eq('areas.city_code', cityCode);
    final List<dynamic> rows = await query
        .order('app_rating', ascending: false, nullsFirst: false)
        .limit(kSportOverviewListLimit);
    return [
      for (final Object? r in rows) _venue(Map<String, dynamic>.from(r as Map)),
    ];
  });

  static SportVenue _venue(Map<String, dynamic> row) {
    final Object? area = row['areas'];
    final double? rating = (row['app_rating'] as num?)?.toDouble();
    return SportVenue(
      id: row['id'] as String,
      nameEn: (row['name_en'] as String?) ?? '',
      nameAr: row['name_ar'] as String?,
      areaName:
          (area is Map ? area['name'] as String? : null) ??
          row['area'] as String?,
      // 0 is "not rated yet" in the data, never a rating to draw.
      rating: rating != null && rating > 0 ? rating : null,
      ratingCount: (row['rating_count'] as num?)?.toInt(),
    );
  }

  @override
  Future<Result<List<SportSpace>, Failure>> spaces(
    String sportId,
    String? cityCode,
  ) => guardWithTimeout(() async {
    var query = _db
        .from(SupabaseConfig.venueSpacesTable)
        .select(
          'id, venue_id, name_en, name_ar, price_per_hour, capacity, indoor, '
          '${cityCode == null ? 'venues!inner(name_en, name_ar, is_active, areas(city_code))' : 'venues!inner(name_en, name_ar, is_active, areas!inner(city_code))'}',
        )
        .eq('sport_id', sportId)
        .eq('is_active', true)
        .eq('venues.is_active', true);
    if (cityCode != null) query = query.eq('venues.areas.city_code', cityCode);
    final List<dynamic> rows = await query
        .order('price_per_hour', ascending: true, nullsFirst: false)
        .limit(kSportOverviewListLimit);
    return [
      for (final Object? r in rows) _space(Map<String, dynamic>.from(r as Map)),
    ];
  });

  static SportSpace _space(Map<String, dynamic> row) {
    final Object? venue = row['venues'];
    final Map<String, dynamic> v = venue is Map
        ? Map<String, dynamic>.from(venue)
        : const <String, dynamic>{};
    final double? price = (row['price_per_hour'] as num?)?.toDouble();
    return SportSpace(
      id: row['id'] as String,
      venueId: row['venue_id'] as String,
      nameEn: row['name_en'] as String?,
      nameAr: row['name_ar'] as String?,
      venueNameEn: v['name_en'] as String?,
      venueNameAr: v['name_ar'] as String?,
      // A price of 0 or none is "not listed", never drawn as a figure.
      pricePerHour: price != null && price > 0 ? price : null,
      capacity: (row['capacity'] as num?)?.toInt(),
      indoor: row['indoor'] as bool?,
    );
  }

  @override
  Future<Result<List<String>, Failure>> postIds(
    String sportId, {
    int offset = 0,
    int limit = kSportOverviewPostsPage,
  }) => guardWithTimeout(() async {
    final List<dynamic> rows = await _db
        .from(SupabaseConfig.postsTable)
        .select('id')
        .eq('sport_id', sportId)
        .eq('visibility', 'public')
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final Object? r in rows) (r as Map)['id'] as String];
  });

  @override
  Future<Result<bool, Failure>> hasSportProfile(
    String profileId,
    SportInfo sport,
  ) => guardWithTimeout(() async {
    final List<dynamic> rows = await _db
        .from(SupabaseConfig.sportProfilesTable)
        .select('sport, sport_id')
        .eq('profile_id', profileId);
    final String? key = sport.sportKey?.toLowerCase();
    return rows.any((Object? r) {
      if (r is! Map) return false;
      final String? sid = r['sport_id'] as String?;
      final String? skey = (r['sport'] as String?)?.toLowerCase();
      return sid == sport.id || (key != null && skey == key);
    });
  });

  @override
  Future<Result<void, Failure>> createSportProfile(
    String profileId,
    SportInfo sport,
  ) => guardWithTimeout(() async {
    await _db.rpc(
      SupabaseConfig.rpcCreateSportProfileFn,
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_sport_id': sport.id,
        'p_sport_key': sport.sportKey ?? sport.nameEn.toLowerCase(),
        'p_skill_level': 1,
      },
    );
  });
}
