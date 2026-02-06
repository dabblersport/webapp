import 'package:meta/meta.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/profile.dart';
import '../models/venue.dart';
import '../models/post.dart';
import 'base_repository.dart';
import 'search_repository.dart';

@immutable
class SearchRepositoryImpl extends BaseRepository implements SearchRepository {
  const SearchRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;

  // --- helpers ---------------------------------------------------------------

  /// Builds a simple OR filter like:
  /// or(username.ilike.%foo%,display_name.ilike.%foo%)
  String _orIlike(List<String> fields, String query) {
    final q = query.trim();
    final needle = '%${q.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final parts = fields.map((f) => '$f.ilike.$needle').join(',');
    return 'or($parts)';
  }

  // --- profiles --------------------------------------------------------------

  @override
  Future<Result<List<Profile>, Failure>> searchProfiles({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    return guard<List<Profile>>(() async {
      if (query.trim().isEmpty) return <Profile>[];

      final rows = await _db
          .from('profiles')
          // choose the columns your Profile.fromMap expects
          .select()
          .or(_orIlike(const ['username', 'display_name'], query))
          .order('display_name', ascending: true)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return rows.map((m) => Profile.fromJson(asMap(m))).toList();
    });
  }

  // --- venues ---------------------------------------------------------------

  @override
  Future<Result<List<Venue>, Failure>> searchVenues({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    return guard<List<Venue>>(() async {
      if (query.trim().isEmpty) return <Venue>[];

      final rows = await _db
          .from('venues')
          .select()
          .or(_orIlike(const ['name'], query))
          .order('name', ascending: true)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return rows.map((m) => Venue.fromJson(asMap(m))).toList();
    });
  }

  // --- posts ----------------------------------------------------------------

  @override
  Future<Result<List<Post>, Failure>> searchPosts({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    return guard<List<Post>>(() async {
      if (query.trim().isEmpty) return <Post>[];

      // If your schema uses 'text' instead of 'caption', swap the field name.
      final rows = await _db
          .from('posts')
          .select()
          .or(_orIlike(const ['caption'], query))
          // RLS should ensure can_view_post; if you have a dedicated view for
          // visible posts, point to it instead for safety/perf.
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return rows.map((m) => Post.fromMap(asMap(m))).toList();
    });
  }
}
