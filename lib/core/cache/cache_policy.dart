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

// -----------------------------------------------------------------------------
// Event invalidation contract (KAN-748)
// -----------------------------------------------------------------------------
//
// Which change makes which cached event data stale. Event keys in use today:
//
// | Family            | Key                                   | Scoped by        |
// |-------------------|---------------------------------------|------------------|
// | game list         | `games.list.<lat>.<lng>.<r>.<sport>.<sort>.<city>` | location, city, sport |
// | my pinned games   | `games.mine.<sportId>`                | sport            |
// | my upcoming games | `games.upcoming.<userId>`             | account only     |
// | meetup list       | `meetups.list.<sportId>`              | sport            |
// | nearby meetups    | `meetups.nearby.<lat>.<lng>.<r>`      | location         |
// | meetup detail     | `meetups.card.<meetupId>`             | one meetup       |
//
// No game detail is cached today, so a game change reaches only the lists.
//
// | Change                                   | Invalidates                         |
// |------------------------------------------|-------------------------------------|
// | game created / edited / cancelled        | every game list (list, mine, upcoming) |
// | meetup created                           | meetup lists (list, nearby)         |
// | meetup edited (title, time, location) / cancelled | `meetups.card.<id>` + meetup lists |
// | city changed                             | `games.list.*`, `meetups.nearby.*`  |
// | sport changed                            | `games.list.*`, `games.mine.*`, `meetups.list.*` |
// | account changed                          | every entry of the old account      |
//
// An id is the id of its own kind: a game change names a `games.id`, a meetup
// change a `meetups.id`; neither ever matches the other kind's keys.
//
// How it is applied (`EventCacheInvalidator` in cache_providers.dart), for the
// signed-in account only:
// - Matching entries not on screen are removed from the cache.
// - Matching entries on screen ([ShownCacheEntries]) are refreshed once each:
//   the provider re-runs and `swrFetch` goes network-first; the old copy stays
//   only as the offline fallback. A cancelled event's entries are removed even
//   when shown, so nothing about it lingers.
// - Account changed: every other account's entries are wiped (also dropping
//   their in-flight writes) and the old account's shown copies are refreshed,
//   so they re-run as the new account.
// - Purely local: no Supabase call, no write to any shared column.

/// The kind of event an [EventCacheChange] names.
enum CachedEventKind { game, meetup }

/// What happened, for [isInvalidatedBy].
enum EventChangeType {
  created,
  edited,
  cancelled,
  cityChanged,
  sportChanged,
  accountChanged,
}

/// One change that may leave event data stale (KAN-748). See the contract
/// above for what each invalidates.
class EventCacheChange {
  /// A new event: the lists that may now contain it.
  const EventCacheChange.created(CachedEventKind this.kind, String this.id)
    : type = EventChangeType.created,
      previousAccountId = null;

  /// The event's title, time or location changed: its detail and the lists.
  const EventCacheChange.edited(CachedEventKind this.kind, String this.id)
    : type = EventChangeType.edited,
      previousAccountId = null;

  /// The event was cancelled: its detail and the lists, removed even if shown.
  const EventCacheChange.cancelled(CachedEventKind this.kind, String this.id)
    : type = EventChangeType.cancelled,
      previousAccountId = null;

  /// The selected city changed: the location-scoped lists.
  const EventCacheChange.cityChanged()
    : type = EventChangeType.cityChanged,
      kind = null,
      id = null,
      previousAccountId = null;

  /// The selected sport changed: the sport-scoped lists.
  const EventCacheChange.sportChanged()
    : type = EventChangeType.sportChanged,
      kind = null,
      id = null,
      previousAccountId = null;

  /// The signed-in account changed from [previousAccountId]: everything of
  /// that account. Apply it after the switch.
  const EventCacheChange.accountChanged(this.previousAccountId)
    : type = EventChangeType.accountChanged,
      kind = null,
      id = null;

  final EventChangeType type;
  final CachedEventKind? kind;

  /// `games.id` for a game, `meetups.id` for a meetup.
  final String? id;
  final String? previousAccountId;
}

const List<String> _gameListPrefixes = [
  'games.list.',
  'games.mine.',
  'games.upcoming.',
];
const List<String> _meetupListPrefixes = ['meetups.list.', 'meetups.nearby.'];
const List<String> _cityScopedPrefixes = ['games.list.', 'meetups.nearby.'];
const List<String> _sportScopedPrefixes = [
  'games.list.',
  'games.mine.',
  'meetups.list.',
];

bool _startsWithAny(String key, List<String> prefixes) =>
    prefixes.any(key.startsWith);

/// Whether [change] makes the cache entry [key] stale (the contract above).
bool isInvalidatedBy(EventCacheChange change, String key) {
  switch (change.type) {
    case EventChangeType.accountChanged:
      return true;
    case EventChangeType.cityChanged:
      return _startsWithAny(key, _cityScopedPrefixes);
    case EventChangeType.sportChanged:
      return _startsWithAny(key, _sportScopedPrefixes);
    case EventChangeType.created:
    case EventChangeType.edited:
    case EventChangeType.cancelled:
      if (change.kind == CachedEventKind.game) {
        return _startsWithAny(key, _gameListPrefixes);
      }
      if (_startsWithAny(key, _meetupListPrefixes)) return true;
      return change.type != EventChangeType.created &&
          key == 'meetups.card.${change.id}';
  }
}
