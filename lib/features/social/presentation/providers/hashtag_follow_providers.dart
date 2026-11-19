import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/social/data/hashtag_follow_repository.dart';

final hashtagFollowRepositoryProvider = Provider<HashtagFollowRepository>(
  (ref) => SupabaseHashtagFollowRepository(ref.watch(supabaseClientProvider)),
);

class HashtagFollowState {
  const HashtagFollowState({this.following, this.busy = false, this.error});

  /// Null until the stored state has loaded.
  final bool? following;
  final bool busy;

  /// The last toggle failed and was reverted.
  final Failure? error;

  HashtagFollowState copyWith({bool? following, bool? busy, Failure? error}) =>
      HashtagFollowState(
        following: following ?? this.following,
        busy: busy ?? this.busy,
        error: error,
      );
}

/// The follow state of one hashtag (KAN-971). A toggle flips at once and is
/// reverted, with [HashtagFollowState.error] set, when the write fails.
class HashtagFollowController extends StateNotifier<HashtagFollowState> {
  HashtagFollowController(this._repo, this.slug)
    : super(const HashtagFollowState()) {
    _load();
  }

  final HashtagFollowRepository _repo;
  final String slug;

  Future<void> _load() async {
    final Result<bool, Failure> r = await _repo.isFollowing(slug);
    if (!mounted) return;
    r.fold(
      (_) => state = state.copyWith(following: false),
      (bool v) => state = state.copyWith(following: v),
    );
  }

  Future<void> toggle() async {
    if (state.busy) return;
    final bool before = state.following ?? false;
    state = HashtagFollowState(following: !before, busy: true);
    final Result<bool, Failure> r = await _repo.setFollowing(slug, !before);
    if (!mounted) return;
    r.fold(
      (Failure e) => state = HashtagFollowState(following: before, error: e),
      (bool stored) => state = HashtagFollowState(following: stored),
    );
  }

  void clearError() {
    if (state.error != null) state = state.copyWith();
  }
}

final hashtagFollowControllerProvider = StateNotifierProvider.autoDispose
    .family<HashtagFollowController, HashtagFollowState, String>(
      (ref, String slug) => HashtagFollowController(
        ref.watch(hashtagFollowRepositoryProvider),
        normaliseHashtag(slug),
      ),
    );
