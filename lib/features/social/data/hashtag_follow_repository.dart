import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// Follow / Unfollow of a hashtag (KAN-971): the signed-in user's row in
/// `user_hashtag_preferences`, keyed by the auth user id.
abstract class HashtagFollowRepository {
  /// Whether the user follows the hashtag [slug]. False when the tag does not
  /// exist yet.
  Future<Result<bool, Failure>> isFollowing(String slug);

  /// Sets the follow state and returns what was stored.
  Future<Result<bool, Failure>> setFollowing(String slug, bool following);
}

String normaliseHashtag(String slug) =>
    slug.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase();

class SupabaseHashtagFollowRepository implements HashtagFollowRepository {
  const SupabaseHashtagFollowRepository(this._db);

  final SupabaseClient _db;

  String get _uid {
    final String? id = _db.auth.currentUser?.id;
    if (id == null) throw const AuthFailure(message: 'Not signed in');
    return id;
  }

  Future<String?> _hashtagId(String slug) async {
    final String tag = normaliseHashtag(slug);
    if (tag.isEmpty) return null;
    final List<dynamic> rows = await _db
        .from(SupabaseConfig.hashtagsTable)
        .select('id')
        .eq('tag', tag)
        .limit(1);
    if (rows.isEmpty) return null;
    return (rows.first as Map)['id'] as String?;
  }

  @override
  Future<Result<bool, Failure>> isFollowing(String slug) =>
      guardWithTimeout(() async {
        final String uid = _uid;
        final String? id = await _hashtagId(slug);
        if (id == null) return false;
        final Map<String, dynamic>? row = await _db
            .from(SupabaseConfig.userHashtagPreferencesTable)
            .select('is_following')
            .eq('user_id', uid)
            .eq('hashtag_id', id)
            .maybeSingle();
        return row?['is_following'] == true;
      });

  @override
  Future<Result<bool, Failure>> setFollowing(String slug, bool following) =>
      guardWithTimeout(() async {
        final String uid = _uid;
        final String? id = await _hashtagId(slug);
        if (id == null) {
          throw const NotFoundFailure(message: 'Hashtag not found');
        }
        final Map<String, dynamic> row = await _db
            .from(SupabaseConfig.userHashtagPreferencesTable)
            .upsert(<String, dynamic>{
              'user_id': uid,
              'hashtag_id': id,
              'is_following': following,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'user_id,hashtag_id')
            .select('is_following')
            .single();
        return row['is_following'] == true;
      });
}
