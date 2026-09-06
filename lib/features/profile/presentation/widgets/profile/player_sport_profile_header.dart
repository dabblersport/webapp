import 'package:flutter/material.dart';

import 'package:dabbler/data/models/sport_profiles/sport_profile.dart'
    as advanced_profile;
import 'package:dabbler/data/models/sport_profiles/sport_profile_badge.dart'
    as advanced_badge;
import 'package:dabbler/data/models/sport_profiles/sport_profile_tier.dart'
    as advanced_tier;

// NOTE: The card UI this widget used to render is disabled — build() is a
// stub. The rendering logic (gradient, tier/verified chips, XP bar,
// form/reliability tiles, badge row) was intentionally commented out and has
// since been removed as dead code (KAN-112). Re-add it from git history if
// this header needs to be reinstated.
class PlayerSportProfileHeader extends StatelessWidget {
  const PlayerSportProfileHeader({
    super.key,
    required this.profile,
    this.tier,
    this.badges = const <advanced_badge.SportProfileBadge>[],
  });

  final advanced_profile.SportProfile profile;
  final advanced_tier.SportProfileTier? tier;
  final List<advanced_badge.SportProfileBadge> badges;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
