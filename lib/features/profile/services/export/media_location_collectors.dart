import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';

/// Collects metadata of media attached to the user's posts for the PDPL
/// data export. Same output as `DataExportService._getMediaMetadata`.
/// Returns null and logs when the read fails.
Future<List<Map<String, dynamic>>?> collectMediaMetadata(
  SupabaseClient supabase,
  String userId,
) async {
  try {
    // Note: covers media attached to this user's posts (post_media joined
    // via posts.author) — there is no general per-user upload library
    // table, so media never attached to a post is out of scope here.
    final response = await supabase
        .from(SupabaseConfig.postMediaTable)
        .select('media_type, url, posts!inner(author)')
        .eq('posts.author', userId);

    return response
        .map<Map<String, dynamic>>(
          (item) => {
            ...item,
            'data_source': 'post_media table (joined via posts.author)',
            'purpose': 'Profile and content management',
            'legal_basis': 'User consent',
            'note':
                'Only media attached to your posts is included - metadata only, actual files not exported for security',
          },
        )
        .toList();
  } catch (e) {
    debugPrint('[WARNING] Could not fetch media metadata: $e');
    return null;
  }
}

/// Collects the user's saved locations for the PDPL data export. Same
/// output as `DataExportService._getLocationData`. Returns null and logs
/// when the read fails.
Future<List<Map<String, dynamic>>?> collectLocationData(
  SupabaseClient supabase,
  String userId,
) async {
  try {
    final response = await supabase
        .from(SupabaseConfig.profileLocationsTable)
        .select('lat, lng, label, area_id, geo_location_id, is_primary')
        .eq('profile_id', userId)
        .order('is_primary', ascending: false);

    return response
        .map<Map<String, dynamic>>(
          (item) => {
            ...item,
            'data_source': 'profile_locations table',
            'purpose': 'Location-based game matching and services',
            'legal_basis': 'User consent',
            'note':
                'Only approximate locations stored - precise coordinates not retained',
          },
        )
        .toList();
  } catch (e) {
    debugPrint('[WARNING] Could not fetch location data: $e');
    return null;
  }
}
