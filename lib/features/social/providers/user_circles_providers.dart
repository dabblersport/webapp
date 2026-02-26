import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/user_circle.dart';
import 'package:dabbler/data/repositories/user_circles_repository.dart';
import 'package:dabbler/data/repositories/user_circles_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repository provider
// ─────────────────────────────────────────────────────────────────────────────

final userCirclesRepositoryProvider = Provider<UserCirclesRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return UserCirclesRepositoryImpl(svc);
});

// ─────────────────────────────────────────────────────────────────────────────
// UserCirclesNotifier — CRUD for named circles
// ─────────────────────────────────────────────────────────────────────────────

class UserCirclesNotifier extends StateNotifier<AsyncValue<List<UserCircle>>> {
  UserCirclesNotifier(this._ref, this._repo) : super(const AsyncLoading()) {
    loadCircles();
  }

  final Ref _ref;
  final UserCirclesRepository _repo;

  Future<void> loadCircles() async {
    state = const AsyncLoading();

    final myProfileId = await _ref.read(myProfileIdProvider.future);
    if (myProfileId == null || myProfileId.isEmpty) {
      state = AsyncError('No active profile', StackTrace.current);
      return;
    }

    final result = await _repo.listCircles(ownerProfileId: myProfileId);
    state = result.fold(
      (failure) => AsyncError(failure.message, StackTrace.current),
      (circles) => AsyncData(circles),
    );
  }

  Future<Result<UserCircle, Failure>> createCircle(String name) async {
    final myProfileId = await _ref.read(myProfileIdProvider.future);
    if (myProfileId == null || myProfileId.isEmpty) {
      return const Err(AuthFailure(message: 'No active profile'));
    }

    final result = await _repo.createCircle(
      ownerProfileId: myProfileId,
      name: name,
    );
    result.fold(
      (_) => null,
      (_) => loadCircles(), // Refresh list on success.
    );
    return result;
  }

  Future<Result<UserCircle, Failure>> updateCircle(
    String circleId,
    String name,
  ) async {
    final myProfileId = await _ref.read(myProfileIdProvider.future);
    if (myProfileId == null || myProfileId.isEmpty) {
      return const Err(AuthFailure(message: 'No active profile'));
    }

    final result = await _repo.updateCircle(
      circleId,
      ownerProfileId: myProfileId,
      name: name,
    );
    result.fold((_) => null, (_) => loadCircles());
    return result;
  }

  Future<Result<void, Failure>> deleteCircle(String circleId) async {
    final myProfileId = await _ref.read(myProfileIdProvider.future);
    if (myProfileId == null || myProfileId.isEmpty) {
      return const Err(AuthFailure(message: 'No active profile'));
    }

    final result = await _repo.deleteCircle(
      circleId,
      ownerProfileId: myProfileId,
    );
    result.fold((_) => null, (_) => loadCircles());
    return result;
  }
}

final userCirclesProvider =
    StateNotifierProvider<UserCirclesNotifier, AsyncValue<List<UserCircle>>>((
      ref,
    ) {
      final repo = ref.watch(userCirclesRepositoryProvider);
      return UserCirclesNotifier(ref, repo);
    });

// ─────────────────────────────────────────────────────────────────────────────
// CircleMembersNotifier — per-circle member management
// ─────────────────────────────────────────────────────────────────────────────

class CircleMembersNotifier
    extends StateNotifier<AsyncValue<List<CircleMember>>> {
  CircleMembersNotifier(this._repo, this._circleId)
    : super(const AsyncLoading()) {
    loadMembers();
  }

  final UserCirclesRepository _repo;
  final String _circleId;

  Future<void> loadMembers() async {
    state = const AsyncLoading();
    final result = await _repo.getCircleMembers(_circleId);
    state = result.fold(
      (f) => AsyncError(f.message, StackTrace.current),
      (members) => AsyncData(members),
    );
  }

  Future<void> addMember(String profileId, {String? userId}) async {
    await _repo.addMember(_circleId, profileId, memberUserId: userId);
    await loadMembers();
  }

  Future<void> removeMember(String profileId) async {
    await _repo.removeMember(_circleId, profileId);
    await loadMembers();
  }
}

/// Per-circle members notifier, keyed by circleId.
final circleMembersProvider =
    StateNotifierProvider.family<
      CircleMembersNotifier,
      AsyncValue<List<CircleMember>>,
      String
    >((ref, circleId) {
      final repo = ref.watch(userCirclesRepositoryProvider);
      return CircleMembersNotifier(repo, circleId);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Followers — for populating "add to circle" list
// ─────────────────────────────────────────────────────────────────────────────

final circleFollowersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repo = ref.watch(userCirclesRepositoryProvider);
      final myProfileId = await ref.watch(myProfileIdProvider.future);
      if (myProfileId == null || myProfileId.isEmpty) {
        throw Exception('No active profile');
      }

      final result = await repo.getFollowers(ownerProfileId: myProfileId);
      return result.fold((f) => throw Exception(f.message), (rows) => rows);
    });
