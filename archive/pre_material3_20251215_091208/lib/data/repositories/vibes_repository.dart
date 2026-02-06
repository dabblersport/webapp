import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/vibe.dart';

abstract class VibesRepository {
  /// Read the current vibe (latest row) for a post if visible to the viewer.
  Future<Result<Vibe?, Failure>> getForPost(String postId);

  /// Return counts of each vibe token present for a post.
  /// Implemented client-side by grouping returned rows.
  Future<Result<Map<String, int>, Failure>> countsForPost(String postId);

  /// Set/replace the author's vibe for a post (RLS allows only author/admin).
  Future<Result<void, Failure>> setVibe({
    required String postId,
    required String vibe,
  });

  /// Clear vibe for a post (author/admin only).
  Future<Result<void, Failure>> clearVibe(String postId);
}
