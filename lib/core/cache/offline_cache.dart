import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/core/cache/cache_policy.dart';

/// One cached server response and when it was fetched (KAN-605).
class CacheEntry {
  const CacheEntry({required this.payload, required this.fetchedAt});

  /// Decoded JSON exactly as the server returned it to the account.
  final Object? payload;
  final DateTime fetchedAt;
}

/// On-device cache of what the server returned to one account (KAN-605).
///
/// Storage: `shared_preferences`, one key per entry plus one index per account.
/// Entries are namespaced by account id, so an account never reads another's.
/// Only server responses are stored: no tokens, no secrets.
///
/// Size cap: [maxBytesPerAccount] (2 MiB of encoded JSON per account). When a
/// write goes over the cap the oldest entries (by `fetchedAt`) are evicted
/// until it fits again; one entry larger than the cap is not stored.
class OfflineCache {
  OfflineCache({SharedPreferences? prefs}) : _prefs = prefs;

  /// The app's one cache, so a sign-out wipe and the feeds' writes share a
  /// write queue.
  static final OfflineCache instance = OfflineCache();

  static const int maxBytesPerAccount = 2 * 1024 * 1024;
  static const String _root = 'offline_cache.v1.';
  static const String _indexName = '__index';

  SharedPreferences? _prefs;

  /// Writes run one after the other so the index never loses an update.
  Future<void> _queue = Future<void>.value();

  DateTime _lastWipe = DateTime.fromMillisecondsSinceEpoch(0);

  /// When each account was last the one kept by an account-switch wipe. A
  /// response for account X that began before the latest switch that kept
  /// another account is dropped, so returning to X (A to B to A) cannot revive
  /// a response that was already in flight before B.
  final Map<String, DateTime> _keptAt = {};

  Future<SharedPreferences> _p() async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _entryKey(String accountId, String key) => '$_root$accountId.$key';
  String _indexKey(String accountId) => '$_root$accountId.$_indexName';

  Future<CacheEntry?> read(String accountId, String key) async {
    try {
      final raw = (await _p()).getString(_entryKey(accountId, key));
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CacheEntry(
        payload: map['p'],
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(map['t'] as int),
      );
    } catch (_) {
      return null; // unreadable entry: same as no cache
    }
  }

  /// Stores [payload] (JSON-encodable) under [key] for [accountId].
  ///
  /// [requestStartedAt] is when the request that produced [payload] began: a
  /// response that was already in flight when a wipe happened is dropped, so a
  /// late refresh cannot bring a signed-out account's data back.
  Future<void> write(
    String accountId,
    String key,
    Object? payload, {
    DateTime? fetchedAt,
    DateTime? requestStartedAt,
  }) {
    final done = _queue.then((_) {
      final started = requestStartedAt;
      if (started != null) {
        if (!started.isAfter(_lastWipe)) return null;
        for (final e in _keptAt.entries) {
          if (e.key != accountId && !started.isAfter(e.value)) return null;
        }
      }
      return _write(accountId, key, payload, fetchedAt);
    });
    _queue = done.catchError((_) {});
    return done.catchError((_) {});
  }

  /// Removes one entry (an edit that invalidates it).
  Future<void> remove(String accountId, String key) {
    final done = _queue.then((_) async {
      final prefs = await _p();
      final index = _readIndex(prefs, accountId);
      index.remove(key);
      await prefs.remove(_entryKey(accountId, key));
      await _saveIndex(prefs, accountId, index);
    });
    _queue = done.catchError((_) {});
    return done.catchError((_) {});
  }

  /// The scheduled cleanup for one account (KAN-613).
  ///
  /// Removes entries fetched before `now - maxAge`, then, if the account is
  /// still over [maxBytesPerAccount], evicts the oldest remaining until it
  /// fits. Never removes an exempt key ([isCleanupExempt]) or one in
  /// [shownKeys]: a stale entry that is shown comes back in
  /// [CacheCleanupResult.refresh] for the caller to refresh. Runs in the write
  /// queue, so it never races a write.
  Future<CacheCleanupResult> cleanup(
    String accountId, {
    required DateTime now,
    Duration maxAge = kCacheCleanupInterval,
    Set<String> shownKeys = const {},
  }) {
    final done = _queue.then(
      (_) => _cleanup(accountId, now, maxAge, shownKeys),
    );
    _queue = done.then<void>((_) {}, onError: (_) {});
    return done;
  }

  Future<CacheCleanupResult> _cleanup(
    String accountId,
    DateTime now,
    Duration maxAge,
    Set<String> shownKeys,
  ) async {
    final prefs = await _p();
    final index = _readIndex(prefs, accountId);
    final cutoff = now.subtract(maxAge).millisecondsSinceEpoch;
    final removed = <String>[];
    final refresh = <String>[];

    bool keeps(String key) => isCleanupExempt(key) || shownKeys.contains(key);

    for (final e in index.entries.toList()) {
      if (e.value.at >= cutoff) continue;
      if (isCleanupExempt(e.key)) continue;
      if (shownKeys.contains(e.key)) {
        refresh.add(e.key);
        continue;
      }
      index.remove(e.key);
      removed.add(e.key);
      await prefs.remove(_entryKey(accountId, e.key));
    }

    var total = index.values.fold<int>(0, (s, e) => s + e.bytes);
    if (total > maxBytesPerAccount) {
      final oldestFirst = index.entries.where((e) => !keeps(e.key)).toList()
        ..sort((a, b) => a.value.at.compareTo(b.value.at));
      for (final victim in oldestFirst) {
        if (total <= maxBytesPerAccount) break;
        total -= victim.value.bytes;
        index.remove(victim.key);
        removed.add(victim.key);
        await prefs.remove(_entryKey(accountId, victim.key));
      }
    }

    if (removed.isNotEmpty) await _saveIndex(prefs, accountId, index);
    return CacheCleanupResult(removed: removed, refresh: refresh);
  }

  Future<void> _write(
    String accountId,
    String key,
    Object? payload,
    DateTime? fetchedAt,
  ) async {
    final prefs = await _p();
    final at = (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final encoded = jsonEncode({'t': at, 'p': payload});
    final size = utf8.encode(encoded).length; // bytes, not UTF-16 units
    final index = _readIndex(prefs, accountId);
    if (size > maxBytesPerAccount) {
      index.remove(key);
      await prefs.remove(_entryKey(accountId, key));
      await _saveIndex(prefs, accountId, index);
      return;
    }
    index[key] = (at: at, bytes: size);
    var total = index.values.fold<int>(0, (s, e) => s + e.bytes);
    if (total > maxBytesPerAccount) {
      final oldestFirst = index.entries.where((e) => e.key != key).toList()
        ..sort((a, b) => a.value.at.compareTo(b.value.at));
      for (final victim in oldestFirst) {
        if (total <= maxBytesPerAccount) break;
        total -= victim.value.bytes;
        index.remove(victim.key);
        await prefs.remove(_entryKey(accountId, victim.key));
      }
    }
    await prefs.setString(_entryKey(accountId, key), encoded);
    await _saveIndex(prefs, accountId, index);
  }

  Map<String, ({int at, int bytes})> _readIndex(
    SharedPreferences prefs,
    String accountId,
  ) {
    try {
      final raw = prefs.getString(_indexKey(accountId));
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          e.key: (
            at: (e.value as List)[0] as int,
            bytes: (e.value as List)[1] as int,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveIndex(
    SharedPreferences prefs,
    String accountId,
    Map<String, ({int at, int bytes})> index,
  ) => prefs.setString(
    _indexKey(accountId),
    jsonEncode({
      for (final e in index.entries) e.key: [e.value.at, e.value.bytes],
    }),
  );

  /// Total encoded size cached for [accountId], from its index.
  Future<int> sizeOf(String accountId) async => _readIndex(
    await _p(),
    accountId,
  ).values.fold<int>(0, (s, e) => s + e.bytes);

  /// Removes every entry of every account except [keepAccountId] (the account
  /// switch wipe). Pass null to remove everything (sign-out).
  Future<void> wipe({String? keepAccountId}) {
    if (keepAccountId == null) {
      _lastWipe = DateTime.now();
    } else {
      _keptAt[keepAccountId] = DateTime.now();
    }
    final done = _queue.then((_) => _wipe(keepAccountId));
    _queue = done.catchError((_) {});
    return done;
  }

  Future<void> _wipe(String? keepAccountId) async {
    final prefs = await _p();
    final keep = keepAccountId == null ? null : '$_root$keepAccountId.';
    for (final k in prefs.getKeys().toList()) {
      if (!k.startsWith(_root)) continue;
      if (keep != null && k.startsWith(keep)) continue;
      await prefs.remove(k);
    }
  }

  /// Sign-out wipe: works offline, touches no network.
  static Future<void> wipeAll() => instance.wipe();
}
