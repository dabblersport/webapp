import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/data/repositories/public_activity_repository.dart';
import 'package:dabbler/data/repositories/public_activity_repository_impl.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final publicActivityRepositoryProvider = Provider<PublicActivityRepository>((ref) {
  return PublicActivityRepositoryImpl(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class PublicActivitiesState {
  const PublicActivitiesState({
    this.activities = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.loaded = false,
    this.error,
  });

  final List<PublicActivity> activities;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool loaded;
  final String? error;

  static const Object _sentinel = Object();

  PublicActivitiesState copyWith({
    List<PublicActivity>? activities,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? loaded,
    Object? error = _sentinel,
  }) =>
      PublicActivitiesState(
        activities: activities ?? this.activities,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        loaded: loaded ?? this.loaded,
        error: error == _sentinel ? this.error : error as String?,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PublicActivitiesNotifier extends StateNotifier<PublicActivitiesState> {
  PublicActivitiesNotifier(
    this._repo, {
    this.profileId,
    bool autoLoad = false,
  }) : super(const PublicActivitiesState()) {
    if (autoLoad) ensureLoaded();
  }

  final PublicActivityRepository _repo;

  /// Non-null = profile activity tab. Null = following feed.
  final String? profileId;

  static const int _pageSize = 20;

  Future<void> ensureLoaded() async {
    if (state.loaded || state.isLoading) return;
    await load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    final Result<List<PublicActivity>, Failure> result = profileId != null
        ? await _repo.fetchUserActivities(
            profileId: profileId!,
            limit: _pageSize,
            offset: 0,
          )
        : await _repo.fetchFollowingActivities(
            limit: _pageSize,
            offset: 0,
          );

    if (!mounted) return;
    result.fold(
      (err) => state = state.copyWith(isLoading: false, error: err.message),
      (items) => state = state.copyWith(
        isLoading: false,
        activities: items,
        hasMore: items.length == _pageSize,
        loaded: true,
        error: null,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || !mounted) return;
    state = state.copyWith(isLoadingMore: true);

    final Result<List<PublicActivity>, Failure> result = profileId != null
        ? await _repo.fetchUserActivities(
            profileId: profileId!,
            limit: _pageSize,
            offset: state.activities.length,
          )
        : await _repo.fetchFollowingActivities(
            limit: _pageSize,
            offset: state.activities.length,
          );

    if (!mounted) return;
    result.fold(
      (err) => state = state.copyWith(isLoadingMore: false, error: err.message),
      (items) => state = state.copyWith(
        isLoadingMore: false,
        activities: [...state.activities, ...items],
        hasMore: items.length == _pageSize,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Social activities from users the current user follows (Following tab).
/// NOT autoDispose — caches across tab switches.
final followingActivitiesProvider =
    StateNotifierProvider<PublicActivitiesNotifier, PublicActivitiesState>((ref) {
  final repo = ref.watch(publicActivityRepositoryProvider);
  return PublicActivitiesNotifier(repo, autoLoad: false);
});

/// Public activities for a specific profile (Activity tab).
/// autoDispose — cleaned up when the profile screen closes.
final userActivitiesProvider = StateNotifierProvider.family
    .autoDispose<PublicActivitiesNotifier, PublicActivitiesState, String>(
  (ref, profileId) {
    final repo = ref.watch(publicActivityRepositoryProvider);
    return PublicActivitiesNotifier(repo, profileId: profileId, autoLoad: true);
  },
);
