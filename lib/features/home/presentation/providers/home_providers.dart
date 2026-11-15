import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/location/providers/location_providers.dart'
    show areaRepositoryProvider;
import 'package:dabbler/features/social/providers/post_providers.dart';

/// The clock Home's Upcoming countdown reads. Defaults to [DateTime.now];
/// tests override it to pin the date (KAN-784).
final homeNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Re-exports the home feed from post_providers for backward compatibility.
/// Uses page 0 (first page) as the default home view.
final latestFeedPostsProvider = FutureProvider.autoDispose<List<Post>>((
  ref,
) async {
  return ref.watch(homeFeedProvider(0).future);
});

/// KAN-957: the cities the Active "Filter by city" sheet lists — every active
/// Area's city, the same source as the header's city picker, once each and
/// sorted. A failed load is an error, never an empty list.
final activeCitiesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final result = await ref.watch(areaRepositoryProvider).getActiveAreas();
  final List<Area> areas = result.fold(
    (err) => throw Exception(err.message),
    (a) => a,
  );
  final byKey = <String, String>{};
  for (final a in areas) {
    final city = a.city.trim();
    if (city.isNotEmpty) byKey.putIfAbsent(city.toLowerCase(), () => city);
  }
  return byKey.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
});
