import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/area_repository.dart';
import 'package:dabbler/data/repositories/area_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

// =============================================================================
// REPOSITORY
// =============================================================================

final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return AreaRepositoryImpl(svc);
});

// =============================================================================
// AREA LOOKUPS
// =============================================================================

/// All active areas — used by the area picker in the post composer.
final activeAreasProvider = FutureProvider.autoDispose<List<Area>>((ref) async {
  final repo = ref.watch(areaRepositoryProvider);
  final result = await repo.getActiveAreas();
  return result.fold((err) => <Area>[], (areas) => areas);
});

/// In-memory cache for area names. Avoids repeated fetches for the same
/// `area_id` when rendering PostLocationChip across the feed.
final _areaNameCache = <String, String>{};

/// Resolve an area name by ID. Returns cached value if available, otherwise
/// fetches from the DB and caches the result.
final areaNameProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  areaId,
) async {
  // Check in-memory cache first.
  if (_areaNameCache.containsKey(areaId)) {
    return _areaNameCache[areaId]!;
  }

  final repo = ref.watch(areaRepositoryProvider);
  final result = await repo.getArea(areaId);
  return result.fold((_) => 'Unknown area', (area) {
    _areaNameCache[areaId] = area.name;
    return area.name;
  });
});

/// Find the nearest area to given coordinates.
final nearestAreaProvider = FutureProvider.autoDispose
    .family<Area?, ({double lat, double lng})>((ref, coords) async {
      final repo = ref.watch(areaRepositoryProvider);
      final result = await repo.getNearestArea(
        lat: coords.lat,
        lng: coords.lng,
      );
      return result.fold((_) => null, (area) => area);
    });

// =============================================================================
// LOCATION-AWARE FEED
// =============================================================================

/// Posts filtered by the user's nearest area. Falls back to the standard home
/// feed if location permission is denied or no area is found.
final areaFeedProvider = FutureProvider.autoDispose.family<List<Post>, int>((
  ref,
  page,
) async {
  final locationService = LocationService();
  final position = locationService.currentPosition;

  // Fall back to home feed if no location available.
  if (position == null) {
    final homeFeed = await ref.watch(homeFeedProvider(page).future);
    return homeFeed;
  }

  // Find nearest area.
  final nearestArea = await ref.watch(
    nearestAreaProvider((
      lat: position.latitude,
      lng: position.longitude,
    )).future,
  );

  if (nearestArea == null) {
    final homeFeed = await ref.watch(homeFeedProvider(page).future);
    return homeFeed;
  }

  final repo = ref.watch(postRepositoryProvider);
  final result = await repo.getAreaFeed(
    areaId: nearestArea.id,
    limit: 20,
    offset: page * 20,
  );
  return result.fold((_) => <Post>[], (posts) => posts);
});
