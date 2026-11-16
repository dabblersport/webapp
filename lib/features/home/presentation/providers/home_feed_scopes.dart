import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/widgets/home_tab_tags.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/domain/nearby_area.dart';

export 'package:dabbler/features/social/domain/nearby_area.dart';

/// KAN-962: what the Home tab tags ask of each feed's query. Derived from
/// [homeTabPicksProvider] and the active persona's `profiles.interests`.

/// The active persona's followed sports (`profiles.interests`), in profile
/// order, without duplicates or blanks.
final viewerInterestsProvider = Provider<List<String>>((ref) {
  final ids = ref.watch(
    currentUserProfileProvider.select((p) => p?.interests ?? const <String>[]),
  );
  final seen = <String>{};
  return <String>[
    for (final id in ids)
      if (id.trim().isNotEmpty && seen.add(id.trim())) id.trim(),
  ];
});

bool _picked(Ref ref, FeedTab tab, HomeTabTag tag) => ref.watch(
  homeTabPicksProvider.select((m) => m[tab]?.contains(tag) ?? false),
);

/// For you: null for every sport ("All sports"); with "My sports" picked, the
/// viewer's followed sports (`get_home_feed.p_sport_ids`). Empty means the
/// viewer follows none, and the feed shows its empty state without a call.
final forYouSportIdsProvider = Provider<List<String>?>((ref) {
  if (!_picked(ref, FeedTab.forYou, HomeTabTag.mySports)) return null;
  return ref.watch(viewerInterestsProvider);
});

/// The Nearby scope, widest pick wins: Anywhere > country > city (default).
final nearbyAreaProvider = Provider<NearbyArea>((ref) {
  if (_picked(ref, FeedTab.nearby, HomeTabTag.anywhere)) {
    return NearbyArea.anywhere;
  }
  if (_picked(ref, FeedTab.nearby, HomeTabTag.country)) {
    return NearbyArea.country;
  }
  return NearbyArea.city;
});

/// News: the followed sports by default ("Following", the first tag); null for
/// every item once "All news" is picked. Empty means the viewer follows none.
final newsSportIdsProvider = Provider<List<String>?>((ref) {
  if (_picked(ref, FeedTab.news, HomeTabTag.newsAll)) return null;
  return ref.watch(viewerInterestsProvider);
});
