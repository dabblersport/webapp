import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves a profile id to the auth user id that `rpc_meetup_decide_request`
/// and `rpc_meetup_remove_attendee` take (`p_user_id`). `rpc_meetup_attendees`
/// returns only `actor_profile_id`; `profiles.user_id` is readable to the
/// caller under the `profiles_select_public` policy (baseline schema
/// `20260829080500_baseline_schema.sql:33202`), the same read the profile
/// screen already relies on. Overridable for tests.
typedef MeetupUserIdLookup = Future<String?> Function(String profileId);

final meetupUserIdLookupProvider = Provider<MeetupUserIdLookup>((ref) {
  return (String profileId) async {
    final row = await Supabase.instance.client
        .from(SupabaseConfig.usersTable)
        .select('user_id')
        .eq('id', profileId)
        .maybeSingle();
    return row?['user_id'] as String?;
  };
});
