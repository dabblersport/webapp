/// How often the scheduled cache cleanup runs, and how old an entry may get
/// before the cleanup removes it (KAN-613). The one place to change it.
const Duration kCacheCleanupInterval = Duration(hours: 24);

/// Cache keys the cleanup never ages out (KAN-613).
///
/// - `settings.`: the device copy of a setting. A pending offline edit
///   (KAN-608) is shown from it until the edit syncs.
/// - `feed.`: the Home feed pages. Offline, the most recent page is all the
///   user has, so it stays until a refresh replaces it.
bool isCleanupExempt(String key) =>
    key.startsWith('settings.') || key.startsWith('feed.');

/// Cache keys the size cap never evicts: only the device copy of a setting.
/// Feed pages count toward the cap and are evicted oldest first, except the
/// Home feed ([kHomeFeedCacheKey]), which stays so it is never empty offline.
bool isSizeCapExempt(String key) => key.startsWith('settings.');

/// The cache key of the Home feed (the For you tab).
const String kHomeFeedCacheKey = 'feed.foryou';

/// Whether [key] is a Home feed page.
bool isFeedKey(String key) => key.startsWith('feed.');

/// What one cleanup pass did for one account.
class CacheCleanupResult {
  const CacheCleanupResult({this.removed = const [], this.refresh = const []});

  /// Keys removed: older than the interval, or evicted to meet the size cap.
  final List<String> removed;

  /// Keys older than the interval that are on screen right now. They were not
  /// removed; the caller refreshes them.
  final List<String> refresh;
}

/// The cache entries a screen is showing right now, each with a way to
/// refresh it (KAN-613). A cleanup keeps these and refreshes them rather than
/// removing them under the user.
class ShownCacheEntries {
  ShownCacheEntries._();

  static final ShownCacheEntries instance = ShownCacheEntries._();

  final Map<String, List<void Function()>> _shown = {};

  String _id(String accountId, String key) => '$accountId\u0000$key';

  /// Marks [key] of [accountId] as shown; call the returned function when it
  /// is not (the provider was disposed).
  void Function() register(
    String accountId,
    String key,
    void Function() refresh,
  ) {
    final id = _id(accountId, key);
    (_shown[id] ??= []).add(refresh);
    return () {
      final list = _shown[id];
      if (list == null) return;
      list.remove(refresh);
      if (list.isEmpty) _shown.remove(id);
    };
  }

  Set<String> keysOf(String accountId) {
    final prefix = '$accountId\u0000';
    return {
      for (final id in _shown.keys)
        if (id.startsWith(prefix)) id.substring(prefix.length),
    };
  }

  /// Refreshes every shown copy of [key].
  void refresh(String accountId, String key) {
    final list = _shown[_id(accountId, key)];
    if (list == null) return;
    for (final r in List.of(list)) {
      try {
        r();
      } catch (_) {
        // A provider that went away between the check and the call.
      }
    }
  }
}
