import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';

/// Collects the user's follow graph and blocks for the PDPL data export.
///
/// Same output as `DataExportService._getConnectionsData`: every follow row
/// (either direction) tagged `connection_type: follow`, every block the user
/// made tagged `connection_type: blocked`, each with the export provenance
/// fields. Returns null and logs when a read fails.
Future<List<Map<String, dynamic>>?> collectConnections(
  SupabaseClient supabase,
  String userId,
) async {
  try {
    // Note: exports the follow graph (who this user follows / is followed
    // by), not circle membership. `circles`/`circle_members` is the other
    // "connections" concept in this schema and isn't interchangeable with
    // follows — revisit if export scope is meant to mean "my circles".
    final follows = await supabase
        .from(SupabaseConfig.profileFollowsTable)
        .select()
        .or('follower_profile_id.eq.$userId,following_profile_id.eq.$userId');

    final blockedUsers = await supabase
        .from(SupabaseConfig.userBlocksTable)
        .select('*, profiles!blocked_user_id(name)')
        .eq('blocker_user_id', userId);

    return [
          ...follows.map((item) => {...item, 'connection_type': 'follow'}),
          ...blockedUsers.map(
            (item) => {...item, 'connection_type': 'blocked'},
          ),
        ]
        .map<Map<String, dynamic>>(
          (item) => {
            ...item,
            'data_source': 'profile_follows, user_blocks tables',
            'purpose': 'Social connection management',
            'legal_basis': 'User consent and contract performance',
          },
        )
        .toList();
  } catch (e) {
    debugPrint('[WARNING] Could not fetch connections data: $e');
    return null;
  }
}
