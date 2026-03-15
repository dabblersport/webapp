import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';

/// The canonical list of top-level navigation destinations shared across every
/// screen that renders the adaptive side-rail / side-nav.
///
/// **Order matters** — index values are used in [onAdaptiveDestinationSelected]
/// and must stay in sync.
const List<AdaptiveDestination> kAdaptiveDestinations = [
  AdaptiveDestination(
    icon: Iconsax.home_2_copy,
    selectedIcon: Iconsax.home_2,
    label: "What's New",
  ),
  AdaptiveDestination(
    icon: Iconsax.add_circle_copy,
    selectedIcon: Iconsax.add_circle,
    label: 'Create',
    isAction: true,
  ),
  AdaptiveDestination(
    icon: Iconsax.search_status_copy,
    selectedIcon: Iconsax.search_status,
    label: 'Sports',
  ),
  AdaptiveDestination(
    icon: Iconsax.search_normal_1_copy,
    selectedIcon: Iconsax.search_normal_1,
    label: 'Search',
  ),
  AdaptiveDestination(
    icon: Iconsax.people_copy,
    selectedIcon: Iconsax.people,
    label: 'Community',
  ),
  AdaptiveDestination(
    icon: Iconsax.notification_copy,
    selectedIcon: Iconsax.notification,
    label: 'Notifications',
  ),
  AdaptiveDestination(
    icon: Iconsax.profile_circle_copy,
    selectedIcon: Iconsax.profile_circle,
    label: 'Profile',
  ),
];

/// Default handler for tapping one of [kAdaptiveDestinations] from any
/// secondary screen (i.e. not from [MainNavigationScreen] which owns the
/// `IndexedStack`).
///
/// [activeIndex] — if the tapped destination matches this value, the tap is
/// treated as a no-op (we're already on that page).
void onAdaptiveDestinationSelected(
  BuildContext context,
  int destIndex, {
  int? activeIndex,
}) {
  if (destIndex == activeIndex) return;

  switch (destIndex) {
    case 0:
      context.go(RoutePaths.home);
      break;
    case 1:
      context.push(RoutePaths.socialCreatePost);
      break;
    case 2:
      context.go(RoutePaths.sports);
      break;
    case 3:
      context.push(RoutePaths.socialSearch);
      break;
    case 4:
      context.push(RoutePaths.socialFriends);
      break;
    case 5:
      context.push(RoutePaths.notifications);
      break;
    case 6:
      context.go(RoutePaths.profile);
      break;
  }
}
