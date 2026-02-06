import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/post.dart';
import 'base_repository.dart';
import 'posts_repository.dart';

@immutable
class PostsRepositoryImpl extends BaseRepository implements PostsRepository {
  const PostsRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;
  String? get _uid => _db.auth.currentUser?.id;

  static const _table = 'posts';

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Post>, Failure>> listRecent({
    int limit = 50,
    DateTime? before,
  }) async {
    return guard<List<Post>>(() async {
      var q = _db.from(_table).select();

      if (before != null) {
        q = q.lt('created_at', before.toUtc().toIso8601String());
      }

      // RLS ensures only can_view_post rows are returned.
      final rows = await q.order('created_at', ascending: false).limit(limit);
      return rows.map((m) => Post.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<List<Post>, Failure>> listByAuthor(
    String authorUserId, {
    int limit = 50,
    DateTime? before,
  }) async {
    return guard<List<Post>>(() async {
      var q = _db.from(_table).select().eq('author_user_id', authorUserId);

      if (before != null) {
        q = q.lt('created_at', before.toUtc().toIso8601String());
      }

      final rows = await q.order('created_at', ascending: false).limit(limit);
      return rows.map((m) => Post.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<Post?, Failure>> getById(String id) async {
    return guard<Post?>(() async {
      final row = await _db.from(_table).select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Post.fromMap(row);
    });
  }

  // ---------------------------------------------------------------------------
  // Writes (insert/update only; delete intentionally omitted)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Post, Failure>> create({
    required String visibility,
    String? body,
    String? mediaUrl,
    String? squadId,
    Map<String, dynamic>? meta,
  }) async {
    return guard<Post>(() async {
      final uid = _uid;
      if (uid == null) throw const AuthFailure(message: 'Not signed in');

      // Get author profile ID from user ID
      final profileRow = await _db
          .from('profiles')
          .select('id')
          .eq('user_id', uid)
          .maybeSingle();

      if (profileRow == null) {
        throw const AuthFailure(message: 'Profile not found');
      }

      final authorProfileId = profileRow['id'] as String;

      final insert = Post(
        id: 'tmp',
        authorProfileId: authorProfileId,
        authorUserId: uid,
        kind: 'moment', // default kind
        visibility: visibility,
        body: body,
        media: mediaUrl != null
            ? [
                {'url': mediaUrl},
              ]
            : [],
        createdAt: DateTime.now().toUtc(),
      ).toInsert();

      // RLS: WITH CHECK enforces author_user_id = auth.uid() and freeze state.
      final row = await _db.from(_table).insert(insert).select().single();

      return Post.fromMap(row);
    });
  }

  @override
  Future<Result<Post, Failure>> update(
    String id, {
    String? visibility,
    String? body,
    String? mediaUrl,
    String? squadId,
    Map<String, dynamic>? meta,
  }) async {
    return guard<Post>(() async {
      final uid = _uid;
      if (uid == null) throw const AuthFailure(message: 'Not signed in');

      // Get author profile ID
      final profileRow = await _db
          .from('profiles')
          .select('id')
          .eq('user_id', uid)
          .maybeSingle();

      if (profileRow == null) {
        throw const AuthFailure(message: 'Profile not found');
      }

      final authorProfileId = profileRow['id'] as String;

      final patch = <String, dynamic>{}
        ..addAll(
          Post(
            id: id,
            authorProfileId: authorProfileId,
            authorUserId: uid,
            kind: 'moment',
            visibility: visibility ?? 'public',
            createdAt: DateTime.now().toUtc(),
          ).toUpdate(
            newVisibility: visibility,
            newBody: body,
            newMedia: mediaUrl != null
                ? [
                    {'url': mediaUrl},
                  ]
                : null,
          ),
        );

      if (patch.isEmpty) {
        // No-op: return current row
        final current = await _db.from(_table).select().eq('id', id).single();
        return Post.fromMap(current);
      }

      // RLS: owner (or admin) can update; freeze policy may block.
      final row = await _db
          .from(_table)
          .update(patch)
          .eq('id', id)
          .select()
          .single();

      return Post.fromMap(row);
    });
  }
}
