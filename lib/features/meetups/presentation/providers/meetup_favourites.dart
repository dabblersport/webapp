import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A meetup's favourites: how many, and whether the viewer is one of them.
typedef MeetupFavourite = ({int count, bool mine});

/// `v_meetup_list.favorite_count` / `favourited_by_me` per listed meetup
/// (CTO ruling v2: one `favorites` table for games, meetups and venues). Read
/// apart from the list row so the Freezed list model stays untouched.
final meetupFavouritesProvider =
    FutureProvider.autoDispose<Map<String, MeetupFavourite>>((ref) async {
      final rows = await ref
          .watch(supabaseClientProvider)
          .from(SupabaseConfig.vMeetupListView)
          .select('id,favorite_count,favourited_by_me');
      return <String, MeetupFavourite>{
        for (final r in rows as List)
          (r as Map)['id'] as String: (
            count: (r['favorite_count'] as num?)?.toInt() ?? 0,
            mine: r['favourited_by_me'] as bool? ?? false,
          ),
      };
    });

/// Toggles the viewer's favourite on meetup [id] through `toggle_favorite`
/// (no user id; the caller is the auth user) and returns the new state, or
/// throws. Overridable for tests.
typedef MeetupFavouriteToggle = Future<MeetupFavourite> Function(String id);

final meetupFavouriteToggleProvider = Provider<MeetupFavouriteToggle>((ref) {
  return (String id) async {
    final rows = await ref
        .read(supabaseClientProvider)
        .rpc(
          SupabaseConfig.toggleFavoriteRpc,
          params: <String, dynamic>{
            'p_target_type': 'meetup',
            'p_target_id': id,
          },
        );
    final first = (rows is List && rows.isNotEmpty) ? rows.first : rows;
    final map = first is Map ? first : const <String, dynamic>{};
    ref.invalidate(meetupFavouritesProvider);
    return (
      count: (map['favorite_count'] as num?)?.toInt() ?? 0,
      mine: map['favourited'] as bool? ?? false,
    );
  };
});
