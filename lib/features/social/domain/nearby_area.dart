/// KAN-962: the Nearby feed's area, from the tab's tags (`NEARBY_TAGS`). The
/// widest pick wins: [anywhere] > [country] > [city] (the default).
enum NearbyArea {
  /// The listing city's posts (KAN-588).
  city,

  /// The posts of every city in the listing city's country (`areas`).
  country,

  /// Every public post, newest first, capped.
  anywhere,
}
