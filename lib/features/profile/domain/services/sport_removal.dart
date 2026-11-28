// KAN-1061: removal is `rpc_remove_my_sport` / `rpc_unfollow_sport`, which
// hide a card or edit interests server-side; this is the client pre-check.

/// Why a sport cannot be removed, or null when it can (KAN-1056).
enum SportRemovalBlock {
  /// It is the profile's only sport.
  lastSport,

  /// It is the profile's primary sport (any persona, KAN-1057). The primary
  /// sport has to change first.
  primarySport,
}

/// Checks a removal of [sportId] before any database call is made.
SportRemovalBlock? sportRemovalBlock({
  required String sportId,
  required int selectedCount,
  required String profileType,
  required String? primarySport,
}) {
  if (selectedCount <= 1) return SportRemovalBlock.lastSport;
  if (sportId == primarySport) {
    return SportRemovalBlock.primarySport;
  }
  return null;
}
