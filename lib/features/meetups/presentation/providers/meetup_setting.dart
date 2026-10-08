import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The setting of each listed meetup, from `v_meetup_list.setting_is_indoor`:
/// the venue's (true if any active space is indoor) or, for a meetup with no
/// venue, the Indoor / Outdoor its host chose (CEO 2026-10-08). Null only for
/// older meetups with neither. Read apart
/// from the list row so the Freezed list model stays untouched.
final meetupSettingsProvider = FutureProvider.autoDispose<Map<String, bool?>>((
  ref,
) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from(SupabaseConfig.vMeetupListView)
      .select('id,setting_is_indoor');
  return <String, bool?>{
    for (final r in rows as List)
      (r as Map)['id'] as String: r['setting_is_indoor'] as bool?,
  };
});
