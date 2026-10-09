import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/favourites/data/favourite_item.dart';
import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the viewer's favourites: their own `favorites` rows (RLS), newest
/// first, then each type's listing view for the rows' text. Reading only.
class FavouritesRepository {
  const FavouritesRepository(this._client);

  final SupabaseClient _client;

  static String _column(FavouriteKind k) => '${k.name}_id';

  Future<List<FavouriteItem>> load(FavouriteKind kind) async {
    final column = _column(kind);
    final rows = await _client
        .from(SupabaseConfig.favoritesTable)
        .select('$column,created_at')
        .not(column, 'is', null)
        .order('created_at', ascending: false);
    final ids = <String>[
      for (final r in rows as List) (r as Map)[column] as String,
    ];
    if (ids.isEmpty) return const <FavouriteItem>[];
    final items = switch (kind) {
      FavouriteKind.venue => await _venues(ids),
      FavouriteKind.game => await _games(ids),
      FavouriteKind.meetup => await _meetups(ids),
    };
    // Keep the order the viewer favourited them in.
    final byId = {for (final i in items) i.id: i};
    return <FavouriteItem>[
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<FavouriteItem>> _venues(List<String> ids) async {
    final rows = await _client
        .from(SupabaseConfig.vVenuesWithSportsTable)
        .select('id,name_en,name_ar,area,city,rating,latitude,longitude')
        .inFilter('id', ids);
    final seen = <String>{};
    return <FavouriteItem>[
      for (final r in rows as List)
        if (seen.add((r as Map)['id'] as String))
          FavouriteItem(
            id: r['id'] as String,
            kind: FavouriteKind.venue,
            title: r['name_en'] as String? ?? '',
            titleAr: r['name_ar'] as String?,
            area: (r['area'] as String?)?.trim().isNotEmpty == true
                ? r['area'] as String
                : r['city'] as String?,
            rating: (r['rating'] as num?)?.toDouble(),
            latitude: (r['latitude'] as num?)?.toDouble(),
            longitude: (r['longitude'] as num?)?.toDouble(),
          ),
    ];
  }

  Future<List<FavouriteItem>> _games(List<String> ids) async {
    final rows = await _client
        .from(SupabaseConfig.vGameCardTable)
        .select(
          'id,title,venue_name,start_at,end_at,roster_count,capacity,is_cancelled',
        )
        .inFilter('id', ids);
    return <FavouriteItem>[
      for (final r in rows as List)
        FavouriteItem(
          id: (r as Map)['id'] as String,
          kind: FavouriteKind.game,
          title: r['title'] as String? ?? '',
          place: r['venue_name'] as String?,
          startAt: _time(r['start_at']),
          endAt: _time(r['end_at']),
          playersIn: (r['roster_count'] as num?)?.toInt(),
          capacity: (r['capacity'] as num?)?.toInt(),
          cancelled: r['is_cancelled'] as bool? ?? false,
        ),
    ];
  }

  Future<List<FavouriteItem>> _meetups(List<String> ids) async {
    final rows = await _client
        .from(SupabaseConfig.vMeetupListView)
        .select(
          'id,title,venue_name,location_name,area_name,start_at,end_at,going_count,is_cancelled',
        )
        .inFilter('id', ids);
    return <FavouriteItem>[
      for (final r in rows as List)
        FavouriteItem(
          id: (r as Map)['id'] as String,
          kind: FavouriteKind.meetup,
          title: r['title'] as String? ?? '',
          place:
              (r['venue_name'] ?? r['location_name'] ?? r['area_name'])
                  as String?,
          startAt: _time(r['start_at']),
          endAt: _time(r['end_at']),
          going: (r['going_count'] as num?)?.toInt(),
          cancelled: r['is_cancelled'] as bool? ?? false,
        ),
    ];
  }

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
