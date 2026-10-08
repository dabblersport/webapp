import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The setting of each listed meetup, from `v_meetup_list.venue_is_indoor`
/// (the venue's active spaces: true if any is indoor). Absent from the map or
/// null means the meetup has no venue, so its setting is unknown. Read apart
/// from the list row so the Freezed list model stays untouched.
final meetupSettingsProvider = FutureProvider.autoDispose<Map<String, bool?>>((
  ref,
) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from(SupabaseConfig.vMeetupListView)
      .select('id,venue_is_indoor');
  return <String, bool?>{
    for (final r in rows as List)
      (r as Map)['id'] as String: r['venue_is_indoor'] as bool?,
  };
});
