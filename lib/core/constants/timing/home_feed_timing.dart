/// Home feed timing (KAN-966). Domain timing, not motion.
library;

abstract final class HomeFeedTiming {
  const HomeFeedTiming._();

  /// How long the For you impression batch waits after the last card came on
  /// screen before it is sent (`rpc_mark_feed_impressions`).
  static const Duration impressionDebounce = Duration(seconds: 2);
}
